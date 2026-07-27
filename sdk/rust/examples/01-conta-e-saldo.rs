//! 01 — Conta e saldo
//!
//! O básico: montar o cliente, confirmar que o gateway responde e ler os dados
//! da conta. Nada aqui gasta crédito.
//!
//!     cargo run --example 01-conta-e-saldo

use apibrasil::ApiBrasil;

#[tokio::main]
async fn main() -> apibrasil::Result<()> {
    // from_env lê APIBRASIL_BEARER_TOKEN, APIBRASIL_DEVICE_TOKEN,
    // APIBRASIL_SECRET_KEY e APIBRASIL_BASE_URL do ambiente.
    let api = ApiBrasil::from_env();

    // /status é público — separa "minha credencial está errada" de
    // "o gateway caiu". Métodos GET não recebem body.
    let status = api.catalog().status().await?;
    println!("Gateway: {}", status["message"]);

    if std::env::var("APIBRASIL_BEARER_TOKEN").is_err() {
        eprintln!("\nDefina APIBRASIL_BEARER_TOKEN no ambiente para seguir.");
        return Ok(());
    }

    match api.account().balance().await {
        Ok(saldo) => println!("Saldo: {saldo}"),
        // Um só tipo de erro, com a categoria em `kind` e predicados de atalho.
        Err(erro) if erro.is_authentication() => {
            eprintln!("Bearer inválido ou expirado — refaça o login no painel.");
            return Ok(());
        }
        Err(erro) => return Err(erro),
    }

    let plano = api.account().plan().await?;
    println!("Plano: {plano}");

    // Devices ativos na conta — cada um é uma instância de um serviço.
    let lista = api.devices().list(None).await?;
    let devices = lista["devices"].as_array().cloned().unwrap_or_default();

    println!("\n{} device(s):", devices.len());
    for device in &devices {
        println!(
            "  {} · {} · {}",
            device["device_name"], device["api"]["name"], device["status"]
        );
    }

    // Login por email/senha, se você preferir não guardar o JWT:
    //
    //     let (api, sessao) = apibrasil::login(
    //         json!({ "email": email, "password": senha }),
    //         Default::default(),
    //     ).await?;
    //
    // Contas com 2FA: api.auth().login() + send_2fa() + verify_2fa(),
    // checando apibrasil::requires_2fa(&sessao).

    Ok(())
}
