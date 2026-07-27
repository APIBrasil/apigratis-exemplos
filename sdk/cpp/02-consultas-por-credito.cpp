// 02 — Consultas por crédito
//
// Rotas /consulta/{servico}/credits. Só precisam do bearer: debitam o saldo da
// conta e ignoram o DeviceToken.
//
// Roda em HOMOLOGAÇÃO por padrão (dados fictícios, sem cobrança).
// Para valer, rode com COBRAR=1.
//
//     ./build/02-consultas-por-credito
//     COBRAR=1 ./build/02-consultas-por-credito

#include <cstdlib>
#include <iostream>
#include <string>

#include <apibrasil/apibrasil.hpp>

namespace {

// Toda consulta devolve o mesmo envelope:
// { error, message, balance, tax, valor_consulta, data }.
void resumir(const std::string& rotulo, const apibrasil::Json& resposta) {
    std::cout << rotulo << ":\n";
    std::cout << "  custou: " << resposta.value("valor_consulta", apibrasil::Json()).dump()
              << " | saldo restante: " << resposta.value("balance", apibrasil::Json()).dump() << "\n";

    std::string dados = resposta.value("data", apibrasil::Json()).dump();
    std::cout << "  data: " << dados.substr(0, std::min<std::size_t>(300, dados.size())) << "\n";
}

}  // namespace

int main() {
    using namespace apibrasil;

    ApiBrasil api;

    if (api.http().bearerToken().empty()) {
        std::cerr << "Defina APIBRASIL_BEARER_TOKEN no ambiente.\n";
        return 1;
    }

    // `homolog` é o sandbox da plataforma — não existe URL separada de teste.
    const char* cobrar = std::getenv("COBRAR");
    const bool homolog = !(cobrar && std::string(cobrar) == "1");
    std::cout << (homolog ? "· modo homologação (sem cobrança)\n\n"
                          : "· CONSULTAS REAIS — vai debitar saldo\n\n");

    try {
        // CNPJ — cadastro básico.
        resumir("CNPJ", api.consulta.cnpj({{"cnpj", "00000000000000"}, {"homolog", homolog}}));

        // O campo `tipo` é o que escolhe o PRODUTO dentro do serviço. Mesmo
        // endpoint, preço e retorno diferentes. São 210+ tipos no catálogo.
        resumir("CNPJ · lista-socios", api.consulta.cnpj({
            {"cnpj", "00000000000000"},
            {"tipo", "lista-socios"},
            {"homolog", homolog},
        }));

        // CPF.
        resumir("CPF", api.consulta.cpf({{"cpf", "00000000000"}, {"homolog", homolog}}));

        // Veicular por placa.
        resumir("Veículos", api.consulta.veiculos({{"placa", "ABC1234"}, {"homolog", homolog}}));

        // Qualquer serviço do catálogo, inclusive os sem método dedicado.
        resumir("Serasa Score PF", api.consulta.generic("cpf", {
            {"cpf", "00000000000"},
            {"tipo", "serasa-score-pf"},
            {"homolog", homolog},
        }));

        // Descobrindo o que existe: catálogo vivo do gateway.
        Json catalogo = api.catalog.apis("consulta");
        const Json& apis = catalogo.contains("apis") ? catalogo["apis"] : Json::array();

        std::cout << "\n" << apis.size() << " API(s) com \"consulta\" no nome. Primeiras:\n";
        std::size_t mostradas = 0;
        for (const auto& servico : apis) {
            if (mostradas++ >= 5) break;
            std::cout << "  " << servico.value("name", "-")
                      << " · R$ " << servico.value("price", Json()).dump() << "\n";
        }

    } catch (const InsufficientBalanceError& e) {
        // 402 — a mensagem do gateway já traz o valor exato da consulta.
        std::cerr << "Sem saldo: " << e.what() << "\n";
        return 1;
    } catch (const ValidationError& e) {
        // 422 — o template do body está em GET /api/v2/endpoint/body.
        std::cerr << "Body inválido: " << e.what() << "\n";
        return 1;
    }

    return 0;
}
