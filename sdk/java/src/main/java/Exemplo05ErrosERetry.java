/**
 * 05 — Erros, retry e observabilidade
 *
 * A parte que separa um script de uma integração de produção.
 *
 *   mvn -q exec:java -Dexec.mainClass=Exemplo05ErrosERetry
 */

import com.apibrasil.sdk.ApiBrasil;
import com.apibrasil.sdk.core.Hooks;
import com.apibrasil.sdk.core.Json;
import com.apibrasil.sdk.core.RetryConfig;
import com.apibrasil.sdk.core.errors.ApiBrasilException;
import com.apibrasil.sdk.core.errors.AuthenticationException;
import com.apibrasil.sdk.core.errors.InsufficientBalanceException;
import com.apibrasil.sdk.core.errors.NetworkException;
import com.apibrasil.sdk.core.errors.NotFoundException;
import com.apibrasil.sdk.core.errors.PermissionException;
import com.apibrasil.sdk.core.errors.RateLimitException;
import com.apibrasil.sdk.core.errors.ServerException;
import com.apibrasil.sdk.core.errors.TimeoutException;
import com.apibrasil.sdk.core.errors.ValidationException;

import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.function.Supplier;

public class Exemplo05ErrosERetry {

    public static void main(String[] args) {
        if (System.getenv("APIBRASIL_BEARER_TOKEN") == null) {
            System.err.println("Defina APIBRASIL_BEARER_TOKEN no ambiente.");
            System.exit(1);
        }

        // -------------------------------------------------------------------
        // Retry
        // -------------------------------------------------------------------
        // O padrão são 2 tentativas extras, backoff exponencial, SÓ em 429 e
        // falha de conexão — e respeitando o Retry-After da resposta.
        //
        // Timeout e erro de negócio nunca são repetidos: um sendText que deu
        // timeout pode ter sido entregue, e uma consulta repetida cobra duas vezes.
        ApiBrasil api = ApiBrasil.builder()
                .timeout(Duration.ofSeconds(30))
                .retry(RetryConfig.builder()
                        .retries(3)
                        .minDelay(Duration.ofMillis(500))
                        .retryOnStatuses(List.of(429, 503))
                        .build())
                // Hooks: é aqui que você pluga log estruturado, métricas ou tracing.
                .hooks(Hooks.builder()
                        .onRequest(i -> System.out.printf("→ %s %s (tentativa %d)%n",
                                i.method(), i.url(), i.attempt()))
                        .onResponse(i -> System.out.printf("← %d em %dms%n",
                                i.status(), i.duration().toMillis()))
                        .onRetry(i -> System.out.printf("↻ retry em %dms: %s%n",
                                i.delay().toMillis(), i.reason()))
                        .build())
                .build();

        // Para desligar: .retry(RetryConfig.DISABLED).

        try (api) {
            // ---------------------------------------------------------------
            // Erros
            // ---------------------------------------------------------------
            // Cada status HTTP do gateway vira uma exceção. Todas estendem
            // ApiBrasilException (RuntimeException) e expõem status(),
            // errorCode(), getMessage() e response().
            try {
                api.consulta.cpf(Json.of("cpf", "00000000000"));

            } catch (ValidationException e) {
                // 400/422 — o body está errado. O template certo vem de
                // GET /api/v2/endpoint/body, e a doc está em doc.apibrasil.io.
                System.err.println("Payload inválido: " + e.getMessage() + " — " + e.response());

            } catch (AuthenticationException e) {
                // 401 — bearer ausente/expirado. Refaça o login; não faça retry cego.
                System.err.println("Refaça o login.");

            } catch (InsufficientBalanceException e) {
                // 402 — a mensagem já traz o valor exato da consulta que faltou.
                System.err.println("Recarregue: " + e.getMessage());

            } catch (PermissionException e) {
                // 403 — DeviceToken de outra API, IP fora da whitelist, ou API
                // que exige cadastro PJ. Três causas, um só status: leia a mensagem.
                System.err.println("Sem permissão: " + e.getMessage());

            } catch (NotFoundException e) {
                // 404 = não achou o dado. 410 = rota desativada, e a mensagem
                // aponta a nova.
                System.err.println((e.status() != null && e.status() == 410
                        ? "Rota descontinuada: " : "Sem dados: ") + e.getMessage());

            } catch (RateLimitException e) {
                // 429 — a SDK já tentou de novo antes de chegar aqui.
                System.err.println("Limite atingido. Aguarde " + e.retryAfter());

            } catch (ServerException e) {
                // 5xx — gateway ou provedor upstream. Repetir com backoff faz sentido.
                System.err.printf("Falha do servidor: %s %s%n", e.status(), e.getMessage());

            } catch (TimeoutException e) {
                // Estourou o tempo. ATENÇÃO: a operação pode ter completado no
                // servidor. Em envios e consultas, confirme antes de repetir.
                System.err.println("Timeout — verifique o estado antes de tentar de novo.");

            } catch (NetworkException e) {
                // Não chegou a haver resposta: DNS, TLS, conexão recusada.
                System.err.println("Falha de rede: " + e.getMessage());

            } catch (ApiBrasilException e) {
                System.err.printf("Erro da SDK (HTTP %s, código %s): %s%n",
                        e.status(), e.errorCode(), e.getMessage());
            }

            // ---------------------------------------------------------------
            // Idempotência na prática
            // ---------------------------------------------------------------
            try {
                System.out.println("\nSaldo: " + comRetrySeguro(api.account::balance, 3));
            } catch (ApiBrasilException e) {
                System.err.println("Desisti: " + e.getMessage());
            }
        }
    }

    /**
     * Repete só o que é seguro repetir: falha de servidor e de rede.
     * Timeout fica de fora — pode indicar trabalho já concluído no servidor.
     */
    private static Map<String, Object> comRetrySeguro(Supplier<Map<String, Object>> chamada, int tentativas) {
        for (int i = 1; ; i++) {
            try {
                return chamada.get();
            } catch (TimeoutException e) {
                // TimeoutException estende NetworkException — capture antes.
                throw e;
            } catch (ServerException | NetworkException e) {
                if (i >= tentativas) {
                    throw e;
                }
                try {
                    Thread.sleep((long) Math.pow(2, i) * 250);
                } catch (InterruptedException interrupted) {
                    Thread.currentThread().interrupt();
                    throw e;
                }
            }
        }
    }
}
