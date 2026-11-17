const formulario = document.getElementById("formConsulta");
const resultado = document.getElementById("resultado");

const botao = formulario.querySelector('button[type="submit"]');

formulario.addEventListener("submit", async (evento) => {
    evento.preventDefault();

    const placa = document.getElementById("placa").value;
    const telefone = document.getElementById("telefone").value;

    console.log("Placa:", placa);
    console.log("Telefone:", telefone);

    botao.disabled = true;
botao.textContent = "Consultando e enviando...";

try {
    resultado.textContent = "Aguarde, estamos consultando a FIPE...";

    const resposta = await fetch("/api/consultar", {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
        },
        body: JSON.stringify({
            placa: placa,
            telefone: telefone
        })
    });

    const dados = await resposta.json();

    if (!resposta.ok) {
        throw new Error(dados.erro || "Falha na consulta.");
    }

    resultado.innerHTML = "";

const titulo = document.createElement("h2");
titulo.textContent = "Resultado da consulta";

const modelo = document.createElement("p");
modelo.textContent = `Veículo: ${dados.veiculo.marca} ${dados.veiculo.modelo}`;

const ano = document.createElement("p");
ano.textContent = `Ano: ${dados.veiculo.ano}`;

const valor = document.createElement("p");
valor.textContent = `Valor FIPE: ${dados.veiculo.valor}`;

valor.classList.add("valor-fipe");

const referencia = document.createElement("p");
referencia.textContent = `Referência: ${dados.veiculo.referencia}`;

const mensagem = document.createElement("p");
mensagem.textContent = "Solicitação de envio ao WhatsApp aceita!";

resultado.append(titulo, modelo, ano, valor, referencia, mensagem);

} catch (erro) {
    resultado.textContent = "Erro: " + erro.message;

} finally {
    botao.disabled = false;
    botao.textContent = "Consultar FIPE";
}

});