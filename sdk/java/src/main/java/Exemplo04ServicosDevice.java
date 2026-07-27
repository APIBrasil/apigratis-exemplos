/**
 * 04 — Serviços device-based (fora do WhatsApp)
 *
 * Todos seguem o mesmo formato: POST /{servico}/{action} com Bearer + DeviceToken.
 * O device precisa ser da API correspondente — um DeviceToken de WhatsApp dá 403
 * em /vehicles.
 *
 *   mvn -q exec:java -Dexec.mainClass=Exemplo04ServicosDevice
 */

import com.apibrasil.sdk.ApiBrasil;
import com.apibrasil.sdk.core.Json;
import com.apibrasil.sdk.core.RequestOptions;
import com.apibrasil.sdk.core.errors.ApiBrasilException;
import com.apibrasil.sdk.core.errors.NotFoundException;

import java.time.LocalDate;
import java.util.Map;
import java.util.function.Supplier;

public class Exemplo04ServicosDevice {

    public static void main(String[] args) {
        if (System.getenv("APIBRASIL_BEARER_TOKEN") == null) {
            System.err.println("Defina APIBRASIL_BEARER_TOKEN no ambiente.");
            System.exit(1);
        }

        try (ApiBrasil api = new ApiBrasil()) {

            // CEP — endereço completo com geolocalização.
            tentar("CEP", () -> api.cep.cep(Json.of("cep", "01001000"), deviceDe("CEP")));

            // Ainda em /cep: cidades por DDD, bairros, cidades, estados, distância.
            tentar("Cidades por DDD", () -> api.cep.request("cidadesPorDDD", Json.of("ddd", "11"), deviceDe("CEP")));

            // Correios — rastreio de encomenda.
            tentar("Rastreio", () -> api.correios.request("rastreio",
                    Json.of("code", "AA123456789BR"), deviceDe("CORREIOS")));

            // Veículos por placa. Diferente de consulta.veiculos (créditos):
            // aqui é device.
            tentar("Placa · dados", () -> api.vehicles.dados(Json.of("placa", "ABC1234"), deviceDe("VEICULOS")));
            tentar("Placa · FIPE", () -> api.vehicles.request("fipe",
                    Json.of("placa", "ABC1234"), deviceDe("VEICULOS")));

            // Tabela FIPE navegável: referência → marcas → modelos → ano → valor.
            tentar("FIPE · marcas", () -> api.fipe.request("ConsultarMarcas",
                    Json.of("codigoTabelaReferencia", 300, "codigoTipoVeiculo", 1), deviceDe("VEICULOS")));

            // Clima por cidade ou por coordenadas.
            tentar("Clima", () -> api.weather.request("city", Json.of("city", "São Paulo"), deviceDe("CLIMA")));

            // Feriados do ano (nacionais, estaduais, facultativos — o type decide).
            tentar("Feriados", () -> api.holidays.request("feriados",
                    Json.of("year", LocalDate.now().getYear()), deviceDe("CLIMA")));

            // GeoIP.
            tentar("GeoIP", () -> api.databaseIp.request("ip", Json.of("ip", "8.8.8.8"), deviceDe("CEP")));

            // SMS — device-based. Só envia de verdade com NUMERO definido.
            String numero = System.getenv("NUMERO");
            if (numero != null) {
                tentar("SMS", () -> api.sms.send(
                        Json.of("number", numero, "message", "Seu código: 123456"), deviceDe("SMS")));

                // Alternativa sem device, debitando créditos da conta:
                // api.sms.sendWithCredits(Json.of("number", numero, "message", "Olá!"));
            }

            // Serviço sem método dedicado? A saída genérica cobre o gateway inteiro.
            // api.request("POST", "/translate/text", Json.of("text", "Olá", "to", "en"));
        }
    }

    /** Devolve o token específico do serviço, caindo para o token padrão. */
    private static RequestOptions deviceDe(String servico) {
        String token = System.getenv("APIBRASIL_DEVICE_TOKEN_" + servico);
        if (token == null || token.isBlank()) {
            token = System.getenv("APIBRASIL_DEVICE_TOKEN");
        }
        return RequestOptions.builder().deviceToken(token).build();
    }

    /** Roda um bloco e reporta a falha sem derrubar os outros exemplos. */
    private static void tentar(String rotulo, Supplier<Map<String, Object>> chamada) {
        try {
            Map<String, Object> resposta = chamada.get();
            Object corpo = resposta.getOrDefault("response", resposta);
            String texto = String.valueOf(corpo);
            System.out.printf("%n%s:%n%s%n", rotulo, texto.substring(0, Math.min(600, texto.length())));
        } catch (NotFoundException e) {
            System.out.printf("%n%s: sem dados (HTTP %s)%n", rotulo, e.status());
        } catch (ApiBrasilException e) {
            System.out.printf("%n%s: %s (HTTP %s)%n", rotulo, e.getMessage(), e.status());
        }
    }
}
