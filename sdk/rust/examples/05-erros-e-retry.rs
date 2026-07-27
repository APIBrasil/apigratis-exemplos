//! 05 — Erros, retry e observabilidade
//!
//! A parte que separa um script de uma integração de produção.
//!
//!     cargo run --example 05-erros-e-retry

use std::time::Duration;

use apibrasil::{ApiBrasil, Config, ErrorKind, FnHooks, Json, RetryConfig};
use serde_json::json;

#[tokio::main]
async fn main() -> apibrasil::Result<()> {
    if std::env::var("APIBRASIL_BEARER_TOKEN").is_err() {
        eprintln!("Defina APIBRASIL_BEARER_TOKEN no ambiente.");
        return Ok(());
    }

    // -----------------------------------------------------------------------
    // Retry
    // -----------------------------------------------------------------------
    // O padrão são 2 tentativas extras, backoff exponencial com jitter, SÓ em
    // 429 e falha de conexão — e respeitando o Retry-After da resposta.
    //
    // Timeout e erro de negócio nunca são repetidos: um send_text que deu
    // timeout pode ter sido entregue, e uma consulta repetida cobra duas vezes.
    // Config::new() vem vazia — as credenciais continuam sendo lidas do ambiente.
    let api = ApiBrasil::new(
        Config::new()
            .timeout(Duration::from_secs(30))
            .retry(RetryConfig {
                retries: 3,
                min_delay: Duration::from_millis(500),
                retry_on_statuses: vec![429, 503],
                ..Default::default()
            })
            // Hooks: é aqui que você pluga log estruturado, métricas ou tracing.
            .hooks(
                FnHooks::new()
                    .on_request(|info| println!("→ {} {} (tentativa {})", info.method, info.url, info.attempt))
                    .on_response(|info| println!("← {} em {:?}", info.status, info.duration))
                    .on_retry(|info| eprintln!("↻ retry em {:?}: {}", info.delay, info.reason)),
            ),
    );

    // Para desligar: .retry(RetryConfig::none()).

    // -----------------------------------------------------------------------
    // Erros
    // -----------------------------------------------------------------------
    // Um só tipo `Error`, com a categoria em `kind` e os detalhes em `status`,
    // `code`, `response` e `retry_after`.
    if let Err(erro) = api.consulta().cpf(json!({ "cpf": "00000000000" })).await {
        match erro.kind {
            // 400/422 — o body está errado. O template certo vem de
            // GET /api/v2/endpoint/body, e a doc está em doc.apibrasil.io.
            ErrorKind::Validation => eprintln!("Payload inválido: {erro} — {:?}", erro.response),

            // 401 — bearer ausente/expirado. Refaça o login; não faça retry cego.
            ErrorKind::Authentication => eprintln!("Refaça o login."),

            // 402 — a mensagem já traz o valor exato da consulta que faltou.
            ErrorKind::InsufficientBalance => eprintln!("Recarregue: {erro}"),

            // 403 — DeviceToken de outra API, IP fora da whitelist, ou API que
            // exige cadastro PJ. Três causas, um só status: leia a mensagem.
            ErrorKind::Permission => eprintln!("Sem permissão: {erro}"),

            // 404 = não achou o dado. 410 = rota desativada, e a mensagem
            // aponta a nova.
            ErrorKind::NotFound if erro.status == Some(410) => {
                eprintln!("Rota descontinuada: {erro}")
            }
            ErrorKind::NotFound => eprintln!("Sem dados: {erro}"),

            // 429 — a SDK já tentou de novo antes de chegar aqui.
            ErrorKind::RateLimit => eprintln!("Limite atingido. Aguarde {:?}.", erro.retry_after),

            // 5xx — gateway ou provedor upstream. Repetir com backoff faz sentido.
            ErrorKind::Server => eprintln!("Falha do servidor: {:?} {erro}", erro.status),

            // Estourou o tempo. ATENÇÃO: a operação pode ter completado no
            // servidor. Em envios e consultas, confirme antes de repetir.
            ErrorKind::Timeout => eprintln!("Timeout — verifique o estado antes de tentar de novo."),

            // Não chegou a haver resposta: DNS, TLS, conexão recusada.
            ErrorKind::Network => eprintln!("Falha de rede: {erro}"),

            _ => eprintln!("Erro da SDK ({:?}, código {:?}): {erro}", erro.status, erro.code),
        }
    }

    // -----------------------------------------------------------------------
    // Idempotência na prática
    // -----------------------------------------------------------------------
    // O serviço precisa viver fora da closure: `api.account()` devolve um valor,
    // e o future criado por `.balance()` empresta dele.
    let account = api.account();

    match com_retry_seguro(3, || account.balance()).await {
        Ok(saldo) => println!("\nSaldo: {saldo}"),
        Err(erro) => eprintln!("Desisti: {erro}"),
    }

    Ok(())
}

/// Repete só o que é seguro repetir: falha de servidor e de rede.
/// Timeout fica de fora — pode indicar trabalho já concluído no servidor.
async fn com_retry_seguro<F, Fut>(tentativas: u32, mut chamada: F) -> apibrasil::Result<Json>
where
    F: FnMut() -> Fut,
    Fut: std::future::Future<Output = apibrasil::Result<Json>>,
{
    for tentativa in 1..=tentativas {
        match chamada().await {
            Ok(resposta) => return Ok(resposta),
            Err(erro) if erro.is_timeout() => return Err(erro),
            Err(erro) if !erro.is_server() && !erro.is_network() => return Err(erro),
            Err(erro) if tentativa == tentativas => return Err(erro),
            Err(_) => {
                tokio::time::sleep(Duration::from_millis(250 * 2u64.pow(tentativa))).await;
            }
        }
    }

    unreachable!("o laço sempre retorna na última tentativa")
}
