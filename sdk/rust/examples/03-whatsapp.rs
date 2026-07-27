//! 03 — WhatsApp
//!
//! Serviço device-based: exige Authorization: Bearer + header DeviceToken.
//! O DeviceToken identifica UMA sessão de WhatsApp; o bearer identifica a conta.
//!
//! Fluxo completo: device → sessão → QR Code → pareamento → envio.
//!
//!     cargo run --example 03-whatsapp
//!     CRIAR_DEVICE=1 cargo run --example 03-whatsapp
//!     NUMERO=5511999999999 cargo run --example 03-whatsapp

use apibrasil::{ApiBrasil, RequestOptions};
use serde_json::json;

#[tokio::main]
async fn main() -> apibrasil::Result<()> {
    if std::env::var("APIBRASIL_BEARER_TOKEN").is_err() {
        eprintln!("Defina APIBRASIL_BEARER_TOKEN no ambiente.");
        return Ok(());
    }

    let api = ApiBrasil::from_env();
    let mut tem_device = std::env::var("APIBRASIL_DEVICE_TOKEN").is_ok();

    // -----------------------------------------------------------------------
    // 1. O device
    // -----------------------------------------------------------------------
    // A SecretKey (painel → API WhatsApp → SecretKey) é a única credencial que
    // cria devices. Depois de criado, o device_token substitui ela no dia a dia.
    if std::env::var("CRIAR_DEVICE").as_deref() == Ok("1") {
        let Ok(secret_key) = std::env::var("APIBRASIL_SECRET_KEY") else {
            eprintln!("CRIAR_DEVICE=1 exige APIBRASIL_SECRET_KEY.");
            return Ok(());
        };

        // with_options devolve um cliente que usa essas opções em todas as
        // chamadas, sem alterar o original.
        let criado = api
            .with_options(RequestOptions::new().secret_key(secret_key))
            .devices()
            .store(json!({ "device_name": "exemplo-rust", "type": "server" }))
            .await?;

        let token = criado["device"]["device_token"].as_str().unwrap_or_default();
        println!("Device criado. Guarde este token no seu ambiente:");
        println!("APIBRASIL_DEVICE_TOKEN={token}\n");

        api.set_device_token(token);
        tem_device = true;
    }

    if !tem_device {
        eprintln!("Defina APIBRASIL_DEVICE_TOKEN, ou rode com CRIAR_DEVICE=1.");
        return Ok(());
    }

    // -----------------------------------------------------------------------
    // 2. A sessão
    // -----------------------------------------------------------------------
    // Os webhooks são opcionais, mas é aqui que se registram — não existe outra
    // chamada para isso. Sem eles você só descobre mensagens recebidas por polling.
    let mut webhooks = serde_json::Map::new();
    for (chave, env_var) in [
        ("webhook_wh_message", "WEBHOOK_MENSAGENS"), // mensagem recebida
        ("webhook_wh_status", "WEBHOOK_STATUS"),     // status da sessão mudou
        ("webhook_wh_connect", "WEBHOOK_CONEXAO"),   // conectou/desconectou
        ("webhook_wh_qrcode", "WEBHOOK_QRCODE"),     // novo QR Code gerado
    ] {
        if let Ok(valor) = std::env::var(env_var) {
            webhooks.insert(chave.to_string(), json!(valor));
        }
    }

    match api.whatsapp().start(serde_json::Value::Object(webhooks)).await {
        Ok(sessao) => println!("Sessão: {:?}", sessao.message()),
        // 403 aqui é quase sempre DeviceToken de outra API, ou IP fora da whitelist.
        Err(erro) if erro.is_permission() => {
            eprintln!("Sem permissão para esse device: {erro}");
            return Ok(());
        }
        Err(erro) => return Err(erro),
    }

    // -----------------------------------------------------------------------
    // 3. O QR Code
    // -----------------------------------------------------------------------
    // Vem como data URI base64. Numa aplicação real você joga isso num <img src>;
    // aqui só mostramos o começo — decodifique com um crate de base64 se quiser
    // gravar o PNG.
    let qr = api.whatsapp().qrcode(None).await?;
    match qr.response().and_then(|r| r["qrcode"].as_str()) {
        Some(data_uri) if data_uri.starts_with("data:image") => {
            println!("QR Code (data URI, {} bytes): {}…", data_uri.len(), &data_uri[..48]);
        }
        _ => println!("QR Code: {:?} (sessão provavelmente já conectada)", qr.message()),
    }

    // -----------------------------------------------------------------------
    // 4. Envios
    // -----------------------------------------------------------------------
    let Ok(numero) = std::env::var("NUMERO") else {
        println!("\nDefina NUMERO=5511999999999 para enviar de verdade.");
        return Ok(());
    };

    // Texto. time_typing simula "digitando..." antes de entregar.
    let texto = api
        .whatsapp()
        .send_text(json!({
            "number": numero,
            "text": "Olá! Mensagem enviada pela SDK Rust da APIBrasil 👋",
            "time_typing": 1500,
        }))
        .await?;
    println!("Texto: {:?}", texto.message());

    // Arquivo por URL pública. Para base64, use send_file64.
    api.whatsapp()
        .send_file(json!({
            "number": numero,
            "path": "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf",
            "caption": "Segue o documento",
        }))
        .await?;

    // Áudio (o gateway converte para mp3; máx. 6 min) e localização.
    api.whatsapp()
        .send_audio(json!({ "number": numero, "path": "https://filesamples.com/samples/audio/mp3/sample3.mp3" }))
        .await?;
    api.whatsapp()
        .send_location(json!({ "number": numero, "lat": -23.5613, "lng": -46.6565 }))
        .await?;

    // Qualquer action da documentação, mesmo sem método dedicado na SDK.
    api.whatsapp()
        .request("sendLink", json!({ "number": numero, "url": "https://apibrasil.com.br", "text": "Conheça" }))
        .await?;

    // Fila: mesma action, processada de forma assíncrona pelo gateway. É o
    // caminho certo para disparos em volume — devolve na hora e não segura a
    // sua requisição.
    let enfileirado = api
        .whatsapp()
        .queue("sendText", json!({ "number": numero, "text": "Esta foi pela fila 🚀" }))
        .await?;
    println!("Fila: {:?}", enfileirado.message());

    // -----------------------------------------------------------------------
    // 5. Vários devices no mesmo processo
    // -----------------------------------------------------------------------
    // with_device devolve um cliente novo, sem alterar o original.
    if let Ok(suporte_token) = std::env::var("APIBRASIL_DEVICE_TOKEN_SUPORTE") {
        let suporte = api.with_device(suporte_token);
        suporte
            .whatsapp()
            .send_text(json!({ "number": numero, "text": "Falando pela sessão do suporte" }))
            .await?;
    }

    Ok(())
}
