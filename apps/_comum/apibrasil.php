<?php

/**
 * Proxy compartilhado dos apps de exemplo.
 *
 * Todo app tem o mesmo esqueleto de backend: valida a entrada, restringe as
 * rotas por allowlist, adiciona as credenciais e repassa o status do gateway.
 * Este arquivo é esse esqueleto — o backend.php de cada app só declara as suas
 * ações.
 *
 * Uso mínimo:
 *
 *   require_once __DIR__ . '/../_comum/apibrasil.php';
 *
 *   use ApiBrasil\Comum\Entrada;
 *   use ApiBrasil\Comum\Proxy;
 *
 *   Proxy::despachar([
 *       'consulta' => [
 *           'caminho' => '/consulta/cnpj/credits',
 *           'corpo' => fn (Entrada $e) => ['cnpj' => $e->digitos('cnpj', 14, 'CNPJ')],
 *       ],
 *   ]);
 */

declare(strict_types=1);

namespace ApiBrasil\Comum;

use JsonException;

/** Interrompe o fluxo com uma resposta de erro para o cliente. */
final class ErroDeEntrada extends \RuntimeException
{
    public function __construct(string $mensagem, public readonly int $status = 422)
    {
        parent::__construct($mensagem);
    }
}

/**
 * Corpo da requisição do navegador, com validadores.
 *
 * Validar aqui não é burocracia: sem isso o app é um proxy aberto para o seu
 * saldo — qualquer visitante manda qualquer payload e você paga a conta.
 */
final class Entrada
{
    /** @param array<string,mixed> $dados */
    public function __construct(private readonly array $dados)
    {
    }

    /** Valor cru, sem validação. Use os métodos tipados quando possível. */
    public function cru(string $campo, mixed $padrao = null): mixed
    {
        return $this->dados[$campo] ?? $padrao;
    }

    public function tem(string $campo): bool
    {
        return isset($this->dados[$campo]) && $this->dados[$campo] !== '';
    }

    /**
     * Só dígitos, com tamanho exato ou faixa.
     *
     * @param int|array{0:int,1:int} $tamanho tamanho exato, ou [mínimo, máximo]
     */
    public function digitos(string $campo, int|array $tamanho, string $rotulo): string
    {
        $valor = preg_replace('/\D/', '', (string) $this->cru($campo, ''));

        [$min, $max] = is_array($tamanho) ? $tamanho : [$tamanho, $tamanho];
        $comprimento = strlen($valor);

        if ($comprimento < $min || $comprimento > $max) {
            throw new ErroDeEntrada(
                $min === $max
                    ? "{$rotulo} deve ter {$min} dígitos."
                    : "{$rotulo} deve ter entre {$min} e {$max} dígitos."
            );
        }

        return $valor;
    }

    /**
     * Texto livre com limite de tamanho.
     *
     * Convenção das mensagens: os rótulos vêm SEM artigo ("mensagem", não
     * "a mensagem") e as frases são construídas de forma neutra em gênero
     * ("O campo X…", "Valor inválido para X"). Assim o mesmo validador serve
     * para Operadora, UF e Referência sem concordância errada.
     */
    public function texto(string $campo, int $maximo, string $rotulo, bool $obrigatorio = true): string
    {
        $valor = trim((string) $this->cru($campo, ''));

        if ($valor === '') {
            if ($obrigatorio) {
                throw new ErroDeEntrada("O campo {$rotulo} é obrigatório.");
            }
            return '';
        }

        if (mb_strlen($valor) > $maximo) {
            throw new ErroDeEntrada("O campo {$rotulo} excede {$maximo} caracteres.");
        }

        return $valor;
    }

    /** Identificador seguro: letras, números, hífen e underscore. */
    public function slug(string $campo, int $maximo, string $rotulo): string
    {
        $valor = preg_replace('/[^A-Za-z0-9_-]/', '', (string) $this->cru($campo, ''));

        if ($valor === '' || strlen($valor) > $maximo) {
            // "Valor inválido para X" em vez de "X inválido": não depende do
            // gênero do rótulo (Operadora, UF, Referência...).
            throw new ErroDeEntrada("Valor inválido para {$rotulo} (letras, números, - e _; até {$maximo}).");
        }

        return $valor;
    }

    /** Um valor de uma lista fechada. Devolve o valor mapeado quando a lista é associativa. */
    public function opcao(string $campo, array $permitidos, string $rotulo): mixed
    {
        $valor = (string) $this->cru($campo, '');

        // Lista associativa: a chave vem do cliente, o valor vai para o gateway.
        if (!array_is_list($permitidos)) {
            if (!array_key_exists($valor, $permitidos)) {
                throw new ErroDeEntrada("Valor inválido para {$rotulo}.");
            }
            return $permitidos[$valor];
        }

        // Comparação estrita: declare a lista com o mesmo tipo que chega do
        // JSON (strings, na prática).
        if (!in_array($valor, $permitidos, true)) {
            throw new ErroDeEntrada("Valor inválido para {$rotulo}.");
        }

        return $valor;
    }

    /** Inteiro dentro de uma faixa. */
    public function inteiro(string $campo, int $minimo, int $maximo, string $rotulo): int
    {
        $cru = $this->cru($campo);

        if (!is_numeric($cru)) {
            throw new ErroDeEntrada("{$rotulo} deve ser um número.");
        }

        $valor = (int) $cru;

        if ($valor < $minimo || $valor > $maximo) {
            throw new ErroDeEntrada("{$rotulo} deve estar entre {$minimo} e {$maximo}.");
        }

        return $valor;
    }

    /** Número decimal (latitude, longitude, valor). */
    public function decimal(string $campo, float $minimo, float $maximo, string $rotulo): float
    {
        $cru = str_replace(',', '.', (string) $this->cru($campo, ''));

        if (!is_numeric($cru)) {
            throw new ErroDeEntrada("{$rotulo} deve ser um número.");
        }

        $valor = (float) $cru;

        if ($valor < $minimo || $valor > $maximo) {
            throw new ErroDeEntrada("{$rotulo} fora da faixa esperada.");
        }

        return $valor;
    }

    /** Placa brasileira: antiga (ABC1234) ou Mercosul (ABC1D23). */
    public function placa(string $campo = 'placa'): string
    {
        $valor = strtoupper(preg_replace('/[^A-Za-z0-9]/', '', (string) $this->cru($campo, '')));

        if (!preg_match('/^[A-Z]{3}[0-9][0-9A-Z][0-9]{2}$/', $valor)) {
            throw new ErroDeEntrada('Placa inválida. Use ABC1234 ou ABC1D23.');
        }

        return $valor;
    }

    /** Telefone com DDI + DDD + número (12 ou 13 dígitos). */
    public function telefone(string $campo = 'numero'): string
    {
        return $this->digitos($campo, [12, 13], 'Número');
    }

    /** URL http(s) — para webhooks e mídia por link. */
    public function url(string $campo, string $rotulo, bool $obrigatorio = true): string
    {
        $valor = trim((string) $this->cru($campo, ''));

        if ($valor === '') {
            if ($obrigatorio) {
                throw new ErroDeEntrada("O campo {$rotulo} é obrigatório.");
            }
            return '';
        }

        // Só http(s): sem isso passariam `javascript:`, `data:` e `file:`.
        if (!filter_var($valor, FILTER_VALIDATE_URL) || !preg_match('#^https?://#i', $valor)) {
            throw new ErroDeEntrada("O campo {$rotulo} precisa ser um endereço http(s) válido.");
        }

        return $valor;
    }
}

/**
 * Despacha uma requisição do navegador para o gateway, com allowlist.
 */
final class Proxy
{
    public const BASE_URL = 'https://gateway.apibrasil.io/api/v2';

    /**
     * Modo homologação: dados fictícios, sem debitar saldo. Ligado por padrão
     * nos exemplos; APIBRASIL_HOMOLOG=0 desliga.
     *
     * Não existe URL de sandbox na plataforma — a homologação é por chamada.
     */
    public static function homolog(): bool
    {
        return getenv('APIBRASIL_HOMOLOG') !== '0';
    }

    /** Aplica `homolog` ao corpo, quando o modo estiver ligado. */
    public static function comHomolog(array $corpo): array
    {
        if (self::homolog()) {
            $corpo['homolog'] = true;
        }

        return $corpo;
    }

    /**
     * Ponto de entrada dos backends.
     *
     * Cada ação aceita:
     *   'caminho'   (string)   rota no gateway, com barra inicial       — obrigatório
     *   'metodo'    (string)   GET|POST|DELETE                          — padrão POST
     *   'device'    (bool)     exige o header DeviceToken               — padrão false
     *   'deviceEnv' (string)   sufixo de APIBRASIL_DEVICE_TOKEN_<X>     — opcional
     *   'secret'    (bool)     exige o header SecretKey                 — padrão false
     *   'corpo'     (callable) fn (Entrada): array                      — opcional
     *   'query'     (callable) fn (Entrada): array                      — opcional
     *
     * @param array<string,array<string,mixed>> $acoes
     */
    public static function despachar(array $acoes): never
    {
        header('Content-Type: application/json; charset=utf-8');
        header('Cache-Control: no-store');
        // O app é servido do mesmo host, então não há CORS a liberar. Manter
        // fechado impede que outra origem use o seu proxy — e o seu saldo.

        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
            header('Allow: POST');
            self::responder(405, ['error' => true, 'message' => 'Use POST.']);
        }

        $bearer = getenv('APIBRASIL_BEARER_TOKEN') ?: '';

        if ($bearer === '') {
            // Erro de configuração vira log no servidor, não pista para o cliente.
            error_log('APIBRASIL_BEARER_TOKEN não definido no ambiente.');
            self::responder(500, ['error' => true, 'message' => 'Serviço indisponível.']);
        }

        try {
            $entrada = new Entrada(self::lerCorpo());

            $nome = (string) $entrada->cru('acao', '');
            if (!isset($acoes[$nome])) {
                // Allowlist: rota fora daqui simplesmente não existe para o cliente.
                throw new ErroDeEntrada('Ação não permitida.');
            }

            $acao = $acoes[$nome];
            $metodo = strtoupper((string) ($acao['metodo'] ?? 'POST'));

            // A VALIDAÇÃO VEM PRIMEIRO, antes de resolver credenciais.
            //
            // O corpo é montado no SERVIDOR a partir de campos validados —
            // repassar o body cru do cliente anularia toda a validação.
            //
            // A ordem importa: se a checagem de device viesse antes, um servidor
            // sem device configurado responderia "exige um device" para um
            // payload inválido, escondendo o erro real de quem está integrando.
            $corpo = isset($acao['corpo']) ? ($acao['corpo'])($entrada) : [];
            $query = isset($acao['query']) ? ($acao['query'])($entrada) : [];

            $headers = [
                'Accept: application/json',
                'Authorization: Bearer ' . $bearer,
            ];

            if (!empty($acao['device'])) {
                $headers[] = 'DeviceToken: ' . self::resolverDeviceToken($entrada, $acao);
            }

            // SecretKey só tem função em /devices/store. Em rota de envio ela
            // não faz nada além de espalhar a credencial.
            if (!empty($acao['secret'])) {
                $secret = getenv('APIBRASIL_SECRET_KEY') ?: '';
                if ($secret === '') {
                    error_log('APIBRASIL_SECRET_KEY não definida no ambiente.');
                    self::responder(500, ['error' => true, 'message' => 'SecretKey não configurada.']);
                }
                $headers[] = 'SecretKey: ' . $secret;
            }

            $url = self::BASE_URL . $acao['caminho'];
            if ($query !== []) {
                $url .= '?' . http_build_query($query);
            }

            [$status, $resposta] = self::enviar($metodo, $url, $headers, $corpo);
        } catch (ErroDeEntrada $e) {
            self::responder($e->status, ['error' => true, 'message' => $e->getMessage()]);
        }

        // Repassar o status preserva a semântica do gateway para o front:
        // 402 saldo, 403 device/IP/PJ, 404 sem dados, 410 rota morta, 422 payload.
        http_response_code($status);
        header('Content-Type: application/json; charset=utf-8');
        echo $resposta;
        exit;
    }

    /** @return array<string,mixed> */
    private static function lerCorpo(): array
    {
        $cru = file_get_contents('php://input') ?: '{}';

        try {
            $dados = json_decode($cru, true, 32, JSON_THROW_ON_ERROR);
        } catch (JsonException) {
            throw new ErroDeEntrada('Corpo da requisição não é JSON válido.', 400);
        }

        return is_array($dados) ? $dados : [];
    }

    /**
     * Resolve o DeviceToken, na ordem:
     *   1. o que o app mandou (gestão de vários devices)
     *   2. APIBRASIL_DEVICE_TOKEN_<SUFIXO> do ambiente
     *   3. APIBRASIL_DEVICE_TOKEN do ambiente
     *
     * @param array<string,mixed> $acao
     */
    private static function resolverDeviceToken(Entrada $entrada, array $acao): string
    {
        if ($entrada->tem('deviceToken')) {
            // Numa aplicação real, confirme que o device pertence ao usuário
            // logado — aqui qualquer visitante poderia passar qualquer token
            // da sua conta.
            return $entrada->slug('deviceToken', 128, 'DeviceToken');
        }

        $sufixo = $acao['deviceEnv'] ?? null;

        $token = $sufixo ? (getenv("APIBRASIL_DEVICE_TOKEN_{$sufixo}") ?: '') : '';
        $token = $token ?: (getenv('APIBRASIL_DEVICE_TOKEN') ?: '');

        if ($token === '') {
            $dica = $sufixo ? "APIBRASIL_DEVICE_TOKEN_{$sufixo} ou APIBRASIL_DEVICE_TOKEN" : 'APIBRASIL_DEVICE_TOKEN';
            error_log("DeviceToken ausente: defina {$dica}.");
            self::responder(500, [
                'error' => true,
                'message' => 'Este recurso exige um device configurado no servidor.',
            ]);
        }

        return $token;
    }

    /**
     * @param list<string> $headers
     * @param array<string,mixed> $corpo
     * @return array{0:int,1:string}
     */
    private static function enviar(string $metodo, string $url, array $headers, array $corpo): array
    {
        $curl = curl_init($url);

        $opcoes = [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CUSTOMREQUEST => $metodo,
            CURLOPT_CONNECTTIMEOUT => 15,
            CURLOPT_TIMEOUT => 60,
            // Verificação de TLS fica LIGADA (o padrão). Desligar expõe a
            // conexão — e o Bearer Token — a interceptação.
        ];

        if ($metodo !== 'GET') {
            $headers[] = 'Content-Type: application/json';
            $opcoes[CURLOPT_POSTFIELDS] = json_encode($corpo, JSON_UNESCAPED_UNICODE);
        }

        $opcoes[CURLOPT_HTTPHEADER] = $headers;
        curl_setopt_array($curl, $opcoes);

        $resposta = curl_exec($curl);
        $status = (int) curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
        $erroCurl = curl_error($curl);

        // Sem curl_close(): desde o PHP 8.0 o handle é um objeto e a função é
        // um no-op deprecado. Sair de escopo já libera.

        if ($resposta === false) {
            error_log("Falha ao chamar o gateway ({$url}): {$erroCurl}");
            self::responder(502, ['error' => true, 'message' => 'Falha ao consultar o serviço.']);
        }

        return [$status, $resposta];
    }

    /** @param array<string,mixed> $corpo */
    private static function responder(int $status, array $corpo): never
    {
        http_response_code($status);
        echo json_encode($corpo, JSON_UNESCAPED_UNICODE);
        exit;
    }
}
