// 01 — Conta e saldo
//
// O básico: montar o cliente, confirmar que o gateway responde e ler os dados
// da conta. Nada aqui gasta crédito.
//
//     ./build/01-conta-e-saldo

#include <cstdlib>
#include <iostream>

#include <apibrasil/apibrasil.hpp>

int main() {
    using namespace apibrasil;

    // Construtor sem argumentos lê APIBRASIL_BEARER_TOKEN, APIBRASIL_DEVICE_TOKEN,
    // APIBRASIL_SECRET_KEY e APIBRASIL_BASE_URL do ambiente.
    ApiBrasil api;

    try {
        // /status é público — separa "minha credencial está errada" de
        // "o gateway caiu".
        Json status = api.catalog.status();
        std::cout << "Gateway: " << status.value("message", "?") << "\n";

        if (api.http().bearerToken().empty()) {
            std::cerr << "\nDefina APIBRASIL_BEARER_TOKEN no ambiente para seguir.\n";
            return 1;
        }

        std::cout << "Saldo: " << api.account.balance().dump() << "\n";
        std::cout << "Plano: " << api.account.plan().dump() << "\n";

        // Devices ativos na conta — cada um é uma instância de um serviço.
        Json lista = api.devices.list();
        const Json& devices = lista.contains("devices") ? lista["devices"] : Json::array();

        std::cout << "\n" << devices.size() << " device(s):\n";
        for (const auto& device : devices) {
            std::cout << "  " << device.value("device_name", "-")
                      << " · " << device.value("api", Json::object()).value("name", "-")
                      << " · " << device.value("status", "-") << "\n";
        }

    } catch (const AuthenticationError&) {
        std::cerr << "Bearer inválido ou expirado — refaça o login no painel.\n";
        return 1;
    } catch (const ApiBrasilError& e) {
        std::cerr << "Falhou (HTTP " << e.status().value_or(0) << "): " << e.what() << "\n";
        return 1;
    }

    // Login por email/senha, se você preferir não guardar o JWT:
    //
    //     auto resultado = ApiBrasil::login({{"email", email}, {"password", senha}});
    //     auto& autenticado = *resultado.client;   // o token já está no cliente
    //
    // Contas com 2FA lançam ApiBrasilError com code() == "requires_2fa";
    // conclua com autenticado.auth.send2fa() / verify2fa().

    return 0;
}
