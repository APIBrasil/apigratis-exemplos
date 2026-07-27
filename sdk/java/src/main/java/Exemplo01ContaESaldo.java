/**
 * 01 — Conta e saldo
 *
 * O básico: montar o cliente, confirmar que o gateway responde e ler os dados
 * da conta. Nada aqui gasta crédito.
 *
 *   mvn -q exec:java -Dexec.mainClass=Exemplo01ContaESaldo
 */

import com.apibrasil.sdk.ApiBrasil;
import com.apibrasil.sdk.core.Json;
import com.apibrasil.sdk.core.errors.ApiBrasilException;
import com.apibrasil.sdk.core.errors.AuthenticationException;

import java.util.List;
import java.util.Map;

public class Exemplo01ContaESaldo {

    public static void main(String[] args) {
        // Sem informar nada, o builder lê APIBRASIL_BEARER_TOKEN, APIBRASIL_DEVICE_TOKEN,
        // APIBRASIL_SECRET_KEY e APIBRASIL_BASE_URL do ambiente.
        // O cliente é AutoCloseable: try-with-resources libera o transporte no fim.
        try (ApiBrasil api = new ApiBrasil()) {

            // /status é público — separa "minha credencial está errada" de
            // "o gateway caiu".
            Map<String, Object> status = api.catalog.status();
            System.out.println("Gateway: " + Json.string(status, "message"));

            if (System.getenv("APIBRASIL_BEARER_TOKEN") == null) {
                System.err.println("Defina APIBRASIL_BEARER_TOKEN no ambiente para seguir.");
                System.exit(1);
            }

            System.out.println("Saldo: " + api.account.balance());
            System.out.println("Plano: " + api.account.plan());

            // Devices ativos na conta — cada um é uma instância de um serviço.
            List<Object> devices = Json.list(api.devices.list(), "devices");
            System.out.printf("%n%d device(s):%n", devices.size());

            for (Object item : devices) {
                Map<String, Object> device = Json.asMap(item);
                Map<String, Object> servico = Json.object(device, "api");
                System.out.printf("  %s · %s · %s%n",
                        Json.string(device, "device_name"),
                        Json.string(servico, "name"),
                        Json.string(device, "status"));
            }

        } catch (AuthenticationException e) {
            System.err.println("Bearer inválido ou expirado — refaça o login no painel.");
            System.exit(1);
        } catch (ApiBrasilException e) {
            System.err.printf("Falhou (HTTP %s): %s%n", e.status(), e.getMessage());
            System.exit(1);
        }

        // Login por email/senha, se você preferir não guardar o JWT:
        //
        //   ApiBrasil api = new ApiBrasil();
        //   Map<String, Object> sessao = api.auth.login(Json.of("email", email, "password", senha));
        //   if (Json.bool(sessao, "requires_2fa")) {
        //       String challenge = Json.string(sessao, "challenge");
        //       api.auth.send2fa(Json.of("challenge", challenge, "method", "email"));
        //       api.auth.verify2fa(Json.of("challenge", challenge, "code", "000000"));
        //   }
        //
        // Ou, em uma tacada só (lança exceção se a conta exigir 2FA):
        //   ApiBrasil.LoginResult r = ApiBrasil.login(Json.of("email", email, "password", senha));
    }
}
