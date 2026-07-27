/**
 * 03 — WhatsApp
 *
 * Serviço device-based: exige Authorization: Bearer + header DeviceToken.
 * O DeviceToken identifica UMA sessão de WhatsApp; o bearer identifica a conta.
 *
 * Fluxo completo: device → sessão → QR Code → pareamento → envio.
 *
 *   mvn -q exec:java -Dexec.mainClass=Exemplo03WhatsApp
 *   CRIAR_DEVICE=1 mvn -q exec:java -Dexec.mainClass=Exemplo03WhatsApp
 *   NUMERO=5511999999999 mvn -q exec:java -Dexec.mainClass=Exemplo03WhatsApp
 */

import com.apibrasil.sdk.ApiBrasil;
import com.apibrasil.sdk.core.Json;
import com.apibrasil.sdk.core.RequestOptions;
import com.apibrasil.sdk.core.errors.PermissionException;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;

public class Exemplo03WhatsApp {

    public static void main(String[] args) throws IOException {
        if (System.getenv("APIBRASIL_BEARER_TOKEN") == null) {
            System.err.println("Defina APIBRASIL_BEARER_TOKEN no ambiente.");
            System.exit(1);
        }

        try (ApiBrasil api = new ApiBrasil()) {
            boolean temDevice = System.getenv("APIBRASIL_DEVICE_TOKEN") != null;

            // ---------------------------------------------------------------
            // 1. O device
            // ---------------------------------------------------------------
            // A SecretKey (painel → API WhatsApp → SecretKey) é a única
            // credencial que cria devices. Depois de criado, o device_token
            // substitui ela no dia a dia.
            if ("1".equals(System.getenv("CRIAR_DEVICE"))) {
                String secretKey = System.getenv("APIBRASIL_SECRET_KEY");
                if (secretKey == null) {
                    System.err.println("CRIAR_DEVICE=1 exige APIBRASIL_SECRET_KEY.");
                    System.exit(1);
                }

                Map<String, Object> criado = api.devices.store(
                        Json.of("device_name", "exemplo-java", "type", "server"),
                        RequestOptions.builder().secretKey(secretKey).build());

                String token = Json.string(Json.object(criado, "device"), "device_token");
                System.out.println("Device criado. Guarde este token no seu ambiente:");
                System.out.printf("APIBRASIL_DEVICE_TOKEN=%s%n%n", token);

                api.setDeviceToken(token);
                temDevice = true;
            }

            if (!temDevice) {
                System.err.println("Defina APIBRASIL_DEVICE_TOKEN, ou rode com CRIAR_DEVICE=1.");
                System.exit(1);
            }

            // ---------------------------------------------------------------
            // 2. A sessão
            // ---------------------------------------------------------------
            // Os webhooks são opcionais, mas é aqui que se registram — não
            // existe outra chamada para isso. Sem eles você só descobre
            // mensagens recebidas por polling.
            Map<String, Object> webhooks = new HashMap<>();
            putSeDefinido(webhooks, "webhook_wh_message", "WEBHOOK_MENSAGENS"); // mensagem recebida
            putSeDefinido(webhooks, "webhook_wh_status", "WEBHOOK_STATUS");     // status da sessão mudou
            putSeDefinido(webhooks, "webhook_wh_connect", "WEBHOOK_CONEXAO");   // conectou/desconectou
            putSeDefinido(webhooks, "webhook_wh_qrcode", "WEBHOOK_QRCODE");     // novo QR Code gerado

            try {
                Map<String, Object> sessao = api.whatsapp.start(webhooks);
                System.out.println("Sessão: " + Json.string(sessao, "message"));
            } catch (PermissionException e) {
                // 403 aqui é quase sempre DeviceToken de outra API, ou IP fora
                // da whitelist.
                System.err.println("Sem permissão para esse device: " + e.getMessage());
                System.exit(1);
            }

            // ---------------------------------------------------------------
            // 3. O QR Code
            // ---------------------------------------------------------------
            // Vem como data URI base64. Numa aplicação real você joga isso num
            // <img src>; aqui gravamos em disco para escanear.
            Map<String, Object> qr = api.whatsapp.qrcode();
            String dataUri = Json.string(Json.object(qr, "response"), "qrcode");

            if (dataUri != null && dataUri.startsWith("data:image")) {
                byte[] imagem = Base64.getDecoder().decode(dataUri.substring(dataUri.indexOf(',') + 1));
                Files.write(Path.of("qrcode.png"), imagem);
                System.out.println("QR Code salvo em qrcode.png — escaneie no WhatsApp → aparelhos conectados.");
            } else {
                System.out.println("QR Code: " + Json.string(qr, "message")
                        + " (sessão provavelmente já conectada)");
            }

            // ---------------------------------------------------------------
            // 4. Envios
            // ---------------------------------------------------------------
            String numero = System.getenv("NUMERO");
            if (numero == null) {
                System.out.println("\nDefina NUMERO=5511999999999 para enviar de verdade.");
                return;
            }

            // Texto. time_typing simula "digitando..." antes de entregar.
            Map<String, Object> texto = api.whatsapp.sendText(Json.of(
                    "number", numero,
                    "text", "Olá! Mensagem enviada pela SDK Java da APIBrasil 👋",
                    "time_typing", 1500));
            System.out.println("Texto: " + Json.string(texto, "message"));

            // Arquivo por URL pública. Para base64, use sendFile64.
            api.whatsapp.sendFile(Json.of(
                    "number", numero,
                    "path", "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf",
                    "caption", "Segue o documento"));

            // Áudio (o gateway converte para mp3; máx. 6 min) e localização.
            api.whatsapp.sendAudio(Json.of(
                    "number", numero,
                    "path", "https://filesamples.com/samples/audio/mp3/sample3.mp3"));
            api.whatsapp.request("sendLocation", Json.of("number", numero, "lat", -23.5613, "lng", -46.6565));

            // Qualquer action da documentação, mesmo sem método dedicado.
            api.whatsapp.request("sendLink", Json.of(
                    "number", numero,
                    "url", "https://apibrasil.com.br",
                    "text", "Conheça"));

            // Fila: mesma action, processada de forma assíncrona pelo gateway.
            // É o caminho certo para disparos em volume — devolve na hora e não
            // segura a sua requisição.
            Map<String, Object> enfileirado = api.whatsapp.queue("sendText", Json.of(
                    "number", numero,
                    "text", "Esta foi pela fila 🚀"));
            System.out.println("Fila: " + Json.string(enfileirado, "message"));

            // ---------------------------------------------------------------
            // 5. Vários devices no mesmo processo
            // ---------------------------------------------------------------
            // Em vez de trocar o device do cliente, passe o token na chamada.
            String suporteToken = System.getenv("APIBRASIL_DEVICE_TOKEN_SUPORTE");
            if (suporteToken != null) {
                api.whatsapp.sendText(
                        Json.of("number", numero, "text", "Falando pela sessão do suporte"),
                        RequestOptions.builder().deviceToken(suporteToken).build());
            }
        }
    }

    private static void putSeDefinido(Map<String, Object> destino, String chave, String envVar) {
        String valor = System.getenv(envVar);
        if (valor != null && !valor.isBlank()) {
            destino.put(chave, valor);
        }
    }
}
