//! 04 — Serviços device-based (fora do WhatsApp)
//!
//! Todos seguem o mesmo formato: POST /{servico}/{action} com Bearer + DeviceToken.
//! O device precisa ser da API correspondente — um DeviceToken de WhatsApp dá 403
//! em /vehicles.
//!
//!     cargo run --example 04-servicos-device

use apibrasil::{ApiBrasil, DeviceResponse, RequestOptions, Result};
use serde_json::json;

/// Devolve as opções com o token específico do serviço, caindo para o padrão.
fn device_de(servico: &str) -> RequestOptions {
    let token = std::env::var(format!("APIBRASIL_DEVICE_TOKEN_{servico}"))
        .or_else(|_| std::env::var("APIBRASIL_DEVICE_TOKEN"))
        .unwrap_or_default();

    RequestOptions::new().device_token(token)
}

/// Reporta a resposta (ou a falha) sem derrubar os outros exemplos.
fn mostrar(rotulo: &str, resultado: Result<DeviceResponse>) {
    match resultado {
        Ok(res) => {
            let corpo = res.response().map(|r| r.to_string()).unwrap_or_else(|| res.json().to_string());
            println!("\n{rotulo}:\n{}", &corpo[..corpo.len().min(600)]);
        }
        Err(erro) if erro.is_not_found() => println!("\n{rotulo}: sem dados"),
        Err(erro) => println!("\n{rotulo}: {erro}"),
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    if std::env::var("APIBRASIL_BEARER_TOKEN").is_err() {
        eprintln!("Defina APIBRASIL_BEARER_TOKEN no ambiente.");
        return Ok(());
    }

    let api = ApiBrasil::from_env();

    // CEP — endereço completo com geolocalização.
    mostrar(
        "CEP",
        api.cep()
            .with_options(device_de("CEP"))
            .cep(json!({ "cep": "01001000" }))
            .await,
    );

    // Ainda em /cep: cidades por DDD, bairros, cidades, estados, distância.
    mostrar(
        "Cidades por DDD",
        api.cep()
            .with_options(device_de("CEP"))
            .request("cidadesPorDDD", json!({ "ddd": "11" }))
            .await,
    );

    // Correios — rastreio de encomenda.
    mostrar(
        "Rastreio",
        api.correios()
            .with_options(device_de("CORREIOS"))
            .rastreio(json!({ "code": "AA123456789BR" }))
            .await,
    );

    // Veículos por placa. Diferente de consulta().veiculos (créditos): aqui é device.
    mostrar(
        "Placa · dados",
        api.vehicles()
            .with_options(device_de("VEICULOS"))
            .dados(json!({ "placa": "ABC1234" }))
            .await,
    );
    mostrar(
        "Placa · FIPE",
        api.vehicles()
            .with_options(device_de("VEICULOS"))
            .fipe(json!({ "placa": "ABC1234" }))
            .await,
    );

    // Tabela FIPE navegável: referência → marcas → modelos → ano → valor.
    mostrar(
        "FIPE · marcas",
        api.fipe()
            .with_options(device_de("VEICULOS"))
            .consultar_marcas(json!({ "codigoTabelaReferencia": 300, "codigoTipoVeiculo": 1 }))
            .await,
    );

    // Clima por cidade ou por coordenadas.
    mostrar(
        "Clima",
        api.weather()
            .with_options(device_de("CLIMA"))
            .city(json!({ "city": "São Paulo" }))
            .await,
    );

    // Feriados do ano. `request` cobre qualquer action do serviço.
    mostrar(
        "Feriados",
        api.holidays()
            .with_options(device_de("CLIMA"))
            .request("feriados", json!({ "year": 2026 }))
            .await,
    );

    // GeoIP.
    mostrar(
        "GeoIP",
        api.database_ip()
            .with_options(device_de("CEP"))
            .ip(json!({ "ip": "8.8.8.8" }))
            .await,
    );

    // SMS — device-based. Só envia de verdade com NUMERO definido.
    if let Ok(numero) = std::env::var("NUMERO") {
        mostrar(
            "SMS",
            api.sms()
                .with_options(device_de("SMS"))
                .send(json!({ "number": numero, "message": "Seu código: 123456" }))
                .await,
        );

        // Alternativa sem device, debitando créditos da conta:
        // api.sms().send_with_credits(json!({ "number": numero, "message": "Olá!" })).await?;
    }

    // Serviço sem método dedicado? A saída genérica cobre o gateway inteiro.
    // api.request(Method::Post, "/translate/text", json!({ "text": "Olá", "to": "en" })).await?;

    Ok(())
}
