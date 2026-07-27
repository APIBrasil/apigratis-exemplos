/*
 * Exemplos do gateway APIBrasil em C, com libcurl.
 *
 * Duas famílias de serviço:
 *   device-based  -> Authorization + DeviceToken   (/whatsapp, /sms, /cep...)
 *   por crédito   -> Authorization                 (/consulta/{servico}/credits)
 *
 * Compilar:  cc apibrasil.c -o apibrasil -lcurl
 * Rodar:     APIBRASIL_BEARER_TOKEN=... ./apibrasil
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <curl/curl.h>

#define BASE_URL "https://gateway.apibrasil.io/api/v2"

/* Buffer que cresce sob demanda para receber o corpo da resposta. */
typedef struct {
    char *dados;
    size_t tamanho;
} Resposta;

/*
 * Callback de escrita do libcurl. Sem isso, o corpo vai para stdout e o
 * programa não tem acesso a ele — era o furo do exemplo antigo.
 */
static size_t acumular(void *conteudo, size_t tam, size_t nmemb, void *usuario) {
    size_t total = tam * nmemb;
    Resposta *r = (Resposta *)usuario;

    char *maior = realloc(r->dados, r->tamanho + total + 1);
    if (!maior) {
        return 0; /* aborta a transferência */
    }

    r->dados = maior;
    memcpy(&r->dados[r->tamanho], conteudo, total);
    r->tamanho += total;
    r->dados[r->tamanho] = '\0';

    return total;
}

/* Traduz o status HTTP — os do gateway têm semântica. */
static const char *explicar(long status) {
    if (status >= 200 && status < 300) return "ok";

    switch (status) {
        case 400:
        case 422: return "payload invalido - confira os campos";
        case 401: return "bearer ausente ou expirado - refaca o login";
        case 402: return "sem saldo/creditos - recarregue";
        case 403: return "sem permissao - DeviceToken, IP whitelist ou API que exige PJ";
        case 404: return "sem dados";
        case 410: return "rota desativada - a mensagem aponta a nova";
        case 429: return "limite por minuto atingido";
        default:  return status >= 500 ? "falha do gateway ou do provedor" : "erro";
    }
}

/*
 * Faz uma requisição ao gateway.
 *
 *   metodo       "GET" ou "POST"
 *   caminho      começa com "/" (ex: "/whatsapp/sendText")
 *   corpo        JSON, ou NULL
 *   bearer       JWT da conta (obrigatório)
 *   device_token só nas rotas device-based; NULL nas de crédito
 *   secret_key   só em /devices/store; NULL no resto
 *
 * Devolve o status HTTP, ou -1 se a requisição não chegou a acontecer.
 * O chamador é dono de *saida e deve liberá-lo.
 */
static long chamar(const char *metodo, const char *caminho, const char *corpo,
                   const char *bearer, const char *device_token,
                   const char *secret_key, char **saida) {
    CURL *curl = curl_easy_init();
    if (!curl) return -1;

    Resposta resposta = {0};
    char url[512];
    char cabecalho_auth[2048];
    long status = -1;

    snprintf(url, sizeof(url), "%s%s", BASE_URL, caminho);
    snprintf(cabecalho_auth, sizeof(cabecalho_auth), "Authorization: Bearer %s", bearer);

    struct curl_slist *headers = NULL;
    headers = curl_slist_append(headers, "Content-Type: application/json");
    headers = curl_slist_append(headers, "Accept: application/json");
    headers = curl_slist_append(headers, cabecalho_auth);

    /*
     * Só mande o que a rota usa. PublicToken não existe no gateway, e SecretKey
     * só tem função em /devices/store — mandar em rota de envio não faz nada
     * além de espalhar a credencial.
     */
    char cabecalho_device[512];
    if (device_token && *device_token) {
        snprintf(cabecalho_device, sizeof(cabecalho_device), "DeviceToken: %s", device_token);
        headers = curl_slist_append(headers, cabecalho_device);
    }

    char cabecalho_secret[512];
    if (secret_key && *secret_key) {
        snprintf(cabecalho_secret, sizeof(cabecalho_secret), "SecretKey: %s", secret_key);
        headers = curl_slist_append(headers, cabecalho_secret);
    }

    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, acumular);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &resposta);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl, CURLOPT_USERAGENT, "apibrasil-exemplos-c/1.0");

    /* O padrão é 0 = esperar para sempre. Nunca deixe assim em produção. */
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 15L);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 30L);

    /*
     * Verificação de TLS fica LIGADA (é o padrão). Desligar expõe a conexão —
     * e o seu Bearer Token — a interceptação.
     */

    if (strcmp(metodo, "POST") == 0) {
        curl_easy_setopt(curl, CURLOPT_POST, 1L);
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, corpo ? corpo : "{}");
    }

    CURLcode resultado = curl_easy_perform(curl);

    if (resultado == CURLE_OK) {
        /*
         * CURLE_OK só quer dizer que a conversa aconteceu — um HTTP 402 também
         * volta OK. O status precisa ser lido à parte.
         */
        curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &status);
    } else {
        fprintf(stderr, "  falha de rede: %s\n", curl_easy_strerror(resultado));
    }

    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);

    *saida = resposta.dados; /* pode ser NULL se não veio corpo */
    return status;
}

/* Imprime a resposta truncada, com o status explicado. */
static void mostrar(const char *rotulo, long status, const char *corpo) {
    printf("\n%s -> HTTP %ld (%s)\n", rotulo, status, explicar(status));
    if (corpo) {
        printf("  %.500s%s\n", corpo, strlen(corpo) > 500 ? "..." : "");
    }
}

int main(void) {
    const char *bearer = getenv("APIBRASIL_BEARER_TOKEN");
    const char *device_token = getenv("APIBRASIL_DEVICE_TOKEN");
    const char *numero = getenv("NUMERO");

    if (!bearer || !*bearer) {
        fprintf(stderr, "Defina APIBRASIL_BEARER_TOKEN no ambiente.\n");
        return 1;
    }

    /* Uma vez no início do programa, como manda a documentação do libcurl. */
    curl_global_init(CURL_GLOBAL_DEFAULT);

    char *corpo = NULL;
    long status;

    /* ---------------------------------------------------------------------
     * Saldo
     * --------------------------------------------------------------------- */
    status = chamar("GET", "/balance", NULL, bearer, NULL, NULL, &corpo);
    mostrar("GET /balance", status, corpo);
    free(corpo);

    if (status == 401) {
        fprintf(stderr, "\nBearer invalido ou expirado - refaca o login no painel.\n");
        curl_global_cleanup();
        return 1;
    }

    /* ---------------------------------------------------------------------
     * Consulta por crédito
     * ---------------------------------------------------------------------
     * Só o Authorization: NULL no device_token. "homolog": true roda em
     * sandbox, sem debitar saldo.
     */
    status = chamar("POST", "/consulta/cnpj/credits",
                    "{\"cnpj\":\"00000000000000\",\"homolog\":true}",
                    bearer, NULL, NULL, &corpo);
    mostrar("POST /consulta/cnpj/credits", status, corpo);
    free(corpo);

    /*
     * O campo "tipo" escolhe o PRODUTO dentro do serviço: mesmo endpoint,
     * preço e retorno diferentes. São 210+ tipos no catálogo.
     */
    status = chamar("POST", "/consulta/cnpj/credits",
                    "{\"cnpj\":\"00000000000000\",\"tipo\":\"lista-socios\",\"homolog\":true}",
                    bearer, NULL, NULL, &corpo);
    mostrar("POST /consulta/cnpj/credits (lista-socios)", status, corpo);
    free(corpo);

    /* ---------------------------------------------------------------------
     * Serviços device-based
     * --------------------------------------------------------------------- */
    if (device_token && *device_token) {
        status = chamar("POST", "/cep/cep", "{\"cep\":\"01001000\"}",
                        bearer, device_token, NULL, &corpo);
        mostrar("POST /cep/cep", status, corpo);
        free(corpo);

        if (numero && *numero) {
            /* A sessão precisa estar iniciada e pareada. */
            status = chamar("POST", "/whatsapp/start", "{}", bearer, device_token, NULL, &corpo);
            free(corpo);

            char envio[1024];
            snprintf(envio, sizeof(envio),
                     "{\"number\":\"%s\",\"text\":\"Ola! Enviado em C\",\"time_typing\":1500}",
                     numero);

            status = chamar("POST", "/whatsapp/sendText", envio, bearer, device_token, NULL, &corpo);
            mostrar("POST /whatsapp/sendText", status, corpo);
            free(corpo);

            /*
             * Fila: sufixo /queue em qualquer action. O gateway processa de
             * forma assíncrona — caminho certo para disparos em volume.
             */
            status = chamar("POST", "/whatsapp/sendText/queue", envio,
                            bearer, device_token, NULL, &corpo);
            mostrar("POST /whatsapp/sendText/queue", status, corpo);
            free(corpo);
        }
    }

    /* ---------------------------------------------------------------------
     * Criando um device
     * ---------------------------------------------------------------------
     * ESTE é o único lugar onde a SecretKey tem função.
     */
    const char *secret_key = getenv("APIBRASIL_SECRET_KEY");
    if (secret_key && *secret_key && getenv("CRIAR_DEVICE")) {
        status = chamar("POST", "/devices/store",
                        "{\"device_name\":\"exemplo-c\",\"type\":\"server\"}",
                        bearer, NULL, secret_key, &corpo);
        mostrar("POST /devices/store", status, corpo);
        free(corpo);
    }

    curl_global_cleanup();
    return 0;
}
