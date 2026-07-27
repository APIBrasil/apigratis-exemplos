// 03 — WhatsApp
//
// Serviço device-based: exige Authorization: Bearer + header DeviceToken.
// O DeviceToken identifica UMA sessão de WhatsApp; o bearer identifica a conta.
//
// Fluxo completo: device → sessão → QR Code → pareamento → envio.
//
//     ./build/03-whatsapp
//     CRIAR_DEVICE=1 ./build/03-whatsapp
//     NUMERO=5511999999999 ./build/03-whatsapp

#include <cstdlib>
#include <iostream>
#include <string>

#include <apibrasil/apibrasil.hpp>

namespace {

// getenv que devolve string vazia em vez de nullptr.
std::string env(const char* nome) {
    const char* valor = std::getenv(nome);
    return valor ? valor : "";
}

}  // namespace

int main() {
    using namespace apibrasil;

    ApiBrasil api;

    if (api.http().bearerToken().empty()) {
        std::cerr << "Defina APIBRASIL_BEARER_TOKEN no ambiente.\n";
        return 1;
    }

    bool temDevice = !api.http().deviceToken().empty();

    try {
        // -------------------------------------------------------------------
        // 1. O device
        // -------------------------------------------------------------------
        // A SecretKey (painel → API WhatsApp → SecretKey) é a única credencial
        // que cria devices. Depois de criado, o device_token substitui ela no
        // dia a dia.
        if (env("CRIAR_DEVICE") == "1") {
            const std::string secretKey = env("APIBRASIL_SECRET_KEY");
            if (secretKey.empty()) {
                std::cerr << "CRIAR_DEVICE=1 exige APIBRASIL_SECRET_KEY.\n";
                return 1;
            }

            RequestOptions o;
            o.secretKey = secretKey;

            Json criado = api.devices.store({{"device_name", "exemplo-cpp"}, {"type", "server"}}, o);
            const std::string token =
                criado.value("device", Json::object()).value("device_token", std::string{});

            std::cout << "Device criado. Guarde este token no seu ambiente:\n";
            std::cout << "APIBRASIL_DEVICE_TOKEN=" << token << "\n\n";

            api.setDeviceToken(token);
            temDevice = true;
        }

        if (!temDevice) {
            std::cerr << "Defina APIBRASIL_DEVICE_TOKEN, ou rode com CRIAR_DEVICE=1.\n";
            return 1;
        }

        // -------------------------------------------------------------------
        // 2. A sessão
        // -------------------------------------------------------------------
        // Os webhooks são opcionais, mas é aqui que se registram — não existe
        // outra chamada para isso. Sem eles você só descobre mensagens
        // recebidas por polling.
        Json webhooks = Json::object();
        for (const auto& [chave, envVar] : {
                 std::pair{"webhook_wh_message", "WEBHOOK_MENSAGENS"},  // mensagem recebida
                 std::pair{"webhook_wh_status", "WEBHOOK_STATUS"},      // status da sessão mudou
                 std::pair{"webhook_wh_connect", "WEBHOOK_CONEXAO"},    // conectou/desconectou
                 std::pair{"webhook_wh_qrcode", "WEBHOOK_QRCODE"},      // novo QR Code
             }) {
            const std::string valor = env(envVar);
            if (!valor.empty()) webhooks[chave] = valor;
        }

        try {
            Json sessao = api.whatsapp.start(webhooks);
            std::cout << "Sessão: " << sessao.value("message", "?") << "\n";
        } catch (const PermissionError& e) {
            // 403 aqui é quase sempre DeviceToken de outra API, ou IP fora da
            // whitelist.
            std::cerr << "Sem permissão para esse device: " << e.what() << "\n";
            return 1;
        }

        // -------------------------------------------------------------------
        // 3. O QR Code
        // -------------------------------------------------------------------
        // Vem como data URI base64. Numa aplicação real você joga isso num
        // <img src>; aqui só mostramos o começo.
        Json qr = api.whatsapp.qrcode();
        const std::string dataUri =
            qr.value("response", Json::object()).value("qrcode", std::string{});

        if (dataUri.rfind("data:image", 0) == 0) {
            std::cout << "QR Code (data URI, " << dataUri.size() << " bytes): "
                      << dataUri.substr(0, 48) << "…\n";
        } else {
            std::cout << "QR Code: " << qr.value("message", "sessão provavelmente já conectada")
                      << "\n";
        }

        // -------------------------------------------------------------------
        // 4. Envios
        // -------------------------------------------------------------------
        const std::string numero = env("NUMERO");
        if (numero.empty()) {
            std::cout << "\nDefina NUMERO=5511999999999 para enviar de verdade.\n";
            return 0;
        }

        // Texto. time_typing simula "digitando..." antes de entregar.
        Json texto = api.whatsapp.sendText({
            {"number", numero},
            {"text", "Olá! Mensagem enviada pela SDK C++ da APIBrasil 👋"},
            {"time_typing", 1500},
        });
        std::cout << "Texto: " << texto.value("message", "?") << "\n";

        // Arquivo por URL pública. Para base64, use sendFile64.
        api.whatsapp.sendFile({
            {"number", numero},
            {"path", "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf"},
            {"caption", "Segue o documento"},
        });

        // Áudio (o gateway converte para mp3; máx. 6 min) e localização.
        api.whatsapp.sendAudio({
            {"number", numero},
            {"path", "https://filesamples.com/samples/audio/mp3/sample3.mp3"},
        });
        api.whatsapp.request("sendLocation", {{"number", numero}, {"lat", -23.5613}, {"lng", -46.6565}});

        // Qualquer action da documentação, mesmo sem método dedicado na SDK.
        api.whatsapp.request("sendLink", {
            {"number", numero},
            {"url", "https://apibrasil.com.br"},
            {"text", "Conheça"},
        });

        // Fila: mesma action, processada de forma assíncrona pelo gateway. É o
        // caminho certo para disparos em volume — devolve na hora e não segura
        // a sua requisição.
        Json enfileirado = api.whatsapp.queue("sendText", {
            {"number", numero},
            {"text", "Esta foi pela fila 🚀"},
        });
        std::cout << "Fila: " << enfileirado.value("message", "?") << "\n";

        // -------------------------------------------------------------------
        // 5. Vários devices no mesmo processo
        // -------------------------------------------------------------------
        // withDevice devolve um shared_ptr para um cliente novo — o original
        // não é copiável, por isso não é retorno por valor.
        const std::string suporteToken = env("APIBRASIL_DEVICE_TOKEN_SUPORTE");
        if (!suporteToken.empty()) {
            auto suporte = api.withDevice(suporteToken);
            suporte->whatsapp.sendText({{"number", numero}, {"text", "Falando pela sessão do suporte"}});
        }

    } catch (const ApiBrasilError& e) {
        std::cerr << "Erro da API (HTTP " << e.status().value_or(0) << "): " << e.what() << "\n";
        return 1;
    }

    return 0;
}
