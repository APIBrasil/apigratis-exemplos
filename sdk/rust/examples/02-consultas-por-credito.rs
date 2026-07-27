//! 02 — Consultas por crédito
//!
//! Rotas /consulta/{servico}/credits. Só precisam do bearer: debitam o saldo da
//! conta e ignoram o DeviceToken.
//!
//! Roda em HOMOLOGAÇÃO por padrão (dados fictícios, sem cobrança).
//! Para valer, rode com COBRAR=1.
//!
//!     cargo run --example 02-consultas-por-credito
//!     COBRAR=1 cargo run --example 02-consultas-por-credito

use apibrasil::{ApiBrasil, Consulta, CreditResponse};
use serde::Deserialize;
use serde_json::json;

/// Toda consulta devolve o mesmo envelope:
/// `{ error, message, balance, tax, valor_consulta, data }`.
fn resumir(rotulo: &str, res: &CreditResponse) {
    println!("{rotulo}:");
    println!(
        "  custou: {:?} | saldo restante: {:?}",
        res.valor_consulta(),
        res.balance()
    );

    let dados = res.data().map(|d| d.to_string()).unwrap_or_default();
    println!("  data: {}", &dados[..dados.len().min(300)]);
}

#[derive(Deserialize)]
struct Empresa {
    #[serde(default)]
    razao_social: String,
    #[serde(default)]
    situacao: String,
}

#[tokio::main]
async fn main() -> apibrasil::Result<()> {
    if std::env::var("APIBRASIL_BEARER_TOKEN").is_err() {
        eprintln!("Defina APIBRASIL_BEARER_TOKEN no ambiente.");
        return Ok(());
    }

    let api = ApiBrasil::from_env();

    // `homolog` é o sandbox da plataforma — não existe URL separada de teste.
    let homolog = std::env::var("COBRAR").as_deref() != Ok("1");
    println!(
        "{}\n",
        if homolog {
            "· modo homologação (sem cobrança)"
        } else {
            "· CONSULTAS REAIS — vai debitar saldo"
        }
    );

    // CNPJ — cadastro básico.
    let empresa = match api
        .consulta()
        .cnpj(json!({ "cnpj": "00000000000000", "homolog": homolog }))
        .await
    {
        Ok(res) => res,
        // 402 — a mensagem do gateway já traz o valor exato da consulta.
        Err(erro) if erro.is_insufficient_balance() => {
            eprintln!("Sem saldo: {erro}");
            return Ok(());
        }
        // 422 — o template do body está em GET /api/v2/endpoint/body.
        Err(erro) if erro.is_validation() => {
            eprintln!("Body inválido: {erro} — {:?}", erro.response);
            return Ok(());
        }
        Err(erro) => return Err(erro),
    };
    resumir("CNPJ", &empresa);

    // decode() tipa direto o campo `data`.
    if let Ok(dados) = empresa.decode::<Empresa>() {
        if !dados.razao_social.is_empty() {
            println!("  → {} ({})", dados.razao_social, dados.situacao);
        }
    }

    // O builder Consulta monta o body com o `tipo` certo — é ele que escolhe o
    // PRODUTO dentro do serviço. Mesmo endpoint, preço e retorno diferentes.
    let socios = api
        .consulta()
        .cnpj(
            Consulta::new("lista-socios")
                .homolog(homolog)
                .field("cnpj", "00000000000000"),
        )
        .await?;
    resumir("CNPJ · lista-socios", &socios);

    // CPF.
    let pessoa = api
        .consulta()
        .cpf(json!({ "cpf": "00000000000", "homolog": homolog }))
        .await?;
    resumir("CPF", &pessoa);

    // Veicular por placa.
    let veiculo = api
        .consulta()
        .veiculos(json!({ "placa": "ABC1234", "homolog": homolog }))
        .await?;
    resumir("Veículos", &veiculo);

    // Qualquer serviço do catálogo, inclusive os sem método dedicado.
    let score = api
        .consulta()
        .generic(
            "cpf",
            json!({ "cpf": "00000000000", "tipo": "serasa-score-pf", "homolog": homolog }),
        )
        .await?;
    resumir("Serasa Score PF", &score);

    // Descobrindo o que existe: catálogo vivo do gateway.
    let catalogo = api.catalog().apis(Some("consulta")).await?;
    let apis = catalogo["apis"].as_array().cloned().unwrap_or_default();

    println!("\n{} API(s) com \"consulta\" no nome. Primeiras:", apis.len());
    for servico in apis.iter().take(5) {
        println!("  {} · R$ {}", servico["name"], servico["price"]);
    }

    Ok(())
}
