/**
 * 02 — Consultas por crédito
 *
 * Rotas /consulta/{servico}/credits. Só precisam do bearer: debitam o saldo da
 * conta e ignoram o DeviceToken.
 *
 * Roda em HOMOLOGAÇÃO por padrão (dados fictícios, sem cobrança).
 * Para valer, rode com COBRAR=1.
 *
 *   mvn -q exec:java -Dexec.mainClass=Exemplo02ConsultasPorCredito
 */

import com.apibrasil.sdk.ApiBrasil;
import com.apibrasil.sdk.core.Json;
import com.apibrasil.sdk.core.errors.InsufficientBalanceException;
import com.apibrasil.sdk.core.errors.ValidationException;

import java.util.List;
import java.util.Map;

public class Exemplo02ConsultasPorCredito {

    public static void main(String[] args) {
        if (System.getenv("APIBRASIL_BEARER_TOKEN") == null) {
            System.err.println("Defina APIBRASIL_BEARER_TOKEN no ambiente.");
            System.exit(1);
        }

        // `homolog` é o sandbox da plataforma — não existe URL separada de teste.
        boolean homolog = !"1".equals(System.getenv("COBRAR"));
        System.out.println(homolog
                ? "· modo homologação (sem cobrança)\n"
                : "· CONSULTAS REAIS — vai debitar saldo\n");

        try (ApiBrasil api = new ApiBrasil()) {

            // CNPJ — cadastro básico.
            resumir("CNPJ", api.consulta.cnpj(Json.of(
                    "cnpj", "00000000000000",
                    "homolog", homolog)));

            // O campo `tipo` é o que escolhe o PRODUTO dentro do serviço. Mesmo
            // endpoint, preço e retorno diferentes. São 210+ tipos no catálogo —
            // com constantes geradas em Catalog.consultaTipo(...).
            resumir("CNPJ · lista-socios", api.consulta.cnpj(Json.of(
                    "cnpj", "00000000000000",
                    "tipo", "lista-socios",
                    "homolog", homolog)));

            // CPF.
            resumir("CPF", api.consulta.cpf(Json.of("cpf", "00000000000", "homolog", homolog)));

            // Veicular por placa.
            resumir("Veículos", api.consulta.veiculos(Json.of("placa", "ABC1234", "homolog", homolog)));

            // Qualquer serviço do catálogo, inclusive os sem método dedicado.
            resumir("Serasa Score PF", api.consulta.generic("cpf", Json.of(
                    "cpf", "00000000000",
                    "tipo", "serasa-score-pf",
                    "homolog", homolog)));

            // Descobrindo o que existe: catálogo vivo do gateway.
            List<Object> apis = Json.list(api.catalog.apis("consulta"), "apis");
            System.out.printf("%n%d API(s) com \"consulta\" no nome. Primeiras:%n", apis.size());
            for (Object item : apis.subList(0, Math.min(5, apis.size()))) {
                Map<String, Object> servico = Json.asMap(item);
                System.out.printf("  %s · R$ %s%n",
                        Json.string(servico, "name"),
                        servico.get("price"));
            }

        } catch (InsufficientBalanceException e) {
            // 402 — a mensagem do gateway já traz o valor exato da consulta.
            System.err.println("Sem saldo: " + e.getMessage());
            System.exit(1);
        } catch (ValidationException e) {
            // 422 — o template do body está em GET /api/v2/endpoint/body.
            System.err.println("Body inválido: " + e.getMessage() + " — " + e.response());
            System.exit(1);
        }
    }

    /**
     * Toda consulta devolve o mesmo envelope:
     * { error, message, balance, tax, valor_consulta, data }.
     */
    private static void resumir(String rotulo, Map<String, Object> resposta) {
        System.out.println(rotulo + ":");
        System.out.printf("  custou: %s | saldo restante: %s%n",
                resposta.get("valor_consulta"), resposta.get("balance"));

        String dados = String.valueOf(resposta.get("data"));
        System.out.println("  data: " + dados.substring(0, Math.min(300, dados.length())));
    }
}
