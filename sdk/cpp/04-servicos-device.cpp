// 04 — Serviços device-based (fora do WhatsApp)
//
// Todos seguem o mesmo formato: POST /{servico}/{action} com Bearer + DeviceToken.
// O device precisa ser da API correspondente — um DeviceToken de WhatsApp dá 403
// em /vehicles.
//
//     ./build/04-servicos-device

#include <cstdlib>
#include <functional>
#include <iostream>
#include <string>

#include <apibrasil/apibrasil.hpp>

namespace {

std::string env(const std::string& nome) {
    const char* valor = std::getenv(nome.c_str());
    return valor ? valor : "";
}

// Opções com o token específico do serviço, caindo para o token padrão.
apibrasil::RequestOptions deviceDe(const std::string& servico) {
    std::string token = env("APIBRASIL_DEVICE_TOKEN_" + servico);
    if (token.empty()) token = env("APIBRASIL_DEVICE_TOKEN");

    apibrasil::RequestOptions o;
    if (!token.empty()) o.deviceToken = token;
    return o;
}

// Roda um bloco e reporta a falha sem derrubar os outros exemplos.
void tentar(const std::string& rotulo, const std::function<apibrasil::Json()>& chamada) {
    using namespace apibrasil;
    try {
        Json resposta = chamada();
        const Json& corpo = resposta.contains("response") ? resposta["response"] : resposta;
        std::string texto = corpo.dump(2);
        std::cout << "\n" << rotulo << ":\n"
                  << texto.substr(0, std::min<std::size_t>(600, texto.size())) << "\n";
    } catch (const NotFoundError& e) {
        std::cout << "\n" << rotulo << ": sem dados (HTTP " << e.status().value_or(0) << ")\n";
    } catch (const ApiBrasilError& e) {
        std::cout << "\n" << rotulo << ": " << e.what() << " (HTTP " << e.status().value_or(0) << ")\n";
    }
}

}  // namespace

int main() {
    using namespace apibrasil;

    ApiBrasil api;

    if (api.http().bearerToken().empty()) {
        std::cerr << "Defina APIBRASIL_BEARER_TOKEN no ambiente.\n";
        return 1;
    }

    // CEP — endereço completo com geolocalização.
    tentar("CEP", [&] { return api.cep.cep({{"cep", "01001000"}}, deviceDe("CEP")); });

    // Ainda em /cep: cidades por DDD, bairros, cidades, estados, distância.
    tentar("Cidades por DDD",
           [&] { return api.cep.request("cidadesPorDDD", {{"ddd", "11"}}, deviceDe("CEP")); });

    // Correios — rastreio de encomenda.
    tentar("Rastreio",
           [&] { return api.correios.rastreio({{"code", "AA123456789BR"}}, deviceDe("CORREIOS")); });

    // Veículos por placa. Diferente de consulta.veiculos (créditos): aqui é device.
    tentar("Placa · dados",
           [&] { return api.vehicles.dados({{"placa", "ABC1234"}}, deviceDe("VEICULOS")); });
    tentar("Placa · FIPE",
           [&] { return api.vehicles.fipe({{"placa", "ABC1234"}}, deviceDe("VEICULOS")); });

    // Tabela FIPE navegável: referência → marcas → modelos → ano → valor.
    tentar("FIPE · marcas", [&] {
        return api.fipe.request("ConsultarMarcas",
                                {{"codigoTabelaReferencia", 300}, {"codigoTipoVeiculo", 1}},
                                deviceDe("VEICULOS"));
    });

    // Clima por cidade ou por coordenadas.
    tentar("Clima",
           [&] { return api.weather.request("city", {{"city", "São Paulo"}}, deviceDe("CLIMA")); });

    // Feriados do ano (nacionais, estaduais, facultativos — o type decide).
    tentar("Feriados",
           [&] { return api.holidays.request("feriados", {{"year", 2026}}, deviceDe("CLIMA")); });

    // GeoIP.
    tentar("GeoIP", [&] { return api.databaseIp.ip({{"ip", "8.8.8.8"}}, deviceDe("CEP")); });

    // SMS — device-based. Só envia de verdade com NUMERO definido.
    const std::string numero = env("NUMERO");
    if (!numero.empty()) {
        tentar("SMS", [&] {
            return api.sms.send({{"number", numero}, {"message", "Seu código: 123456"}},
                                deviceDe("SMS"));
        });

        // Alternativa sem device, debitando créditos da conta:
        // api.sms.sendWithCredits({{"number", numero}, {"message", "Olá!"}});
    }

    // Serviço sem método dedicado? A saída genérica cobre o gateway inteiro.
    // api.request("POST", "/translate/text", Json{{"text", "Olá"}, {"to", "en"}});

    return 0;
}
