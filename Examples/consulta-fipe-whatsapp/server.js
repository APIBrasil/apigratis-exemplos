// Importar o Express
const express = require("express");

const { rateLimit } = require("express-rate-limit");

// Criar a aplicação
const app = express();

// Definir a porta do servidor
const PORT = Number(process.env.PORT) || 3001;

// Permitir receber dados em JSON
app.use(express.json({
    verify: (req, res, buffer) => {
        if (req.path === "/webhook/whatsapp") {
            req.rawBody = Buffer.from(buffer);
        }
    }
}));

// Disponibilizar os arquivos do frontend
app.use(express.static("public"));

// Limitar o número de consultas por IP
const limiteConsultas = rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 5,
    standardHeaders: "draft-8",
    legacyHeaders: false,
    message: {
        erro: "Limite de consultas atingido. Tente novamente em 15 minutos."
    }
});

// Criar a rota para consultar a placa
app.post("/api/consultar", limiteConsultas, async (req, res) => {

    // Receber os dados enviados pelo formulário
    const { placa, telefone } = req.body;

    // Padronizar a placa
const placaFormatada = String(placa || "")
    .toUpperCase()
    .replace(/[\s-]/g, "");

// Validar os formatos antigo e Mercosul
const placaValida = /^[A-Z]{3}[0-9]{4}$|^[A-Z]{3}[0-9][A-Z][0-9]{2}$/.test(placaFormatada);


if (!placaValida) {
    return res.status(400).json({
        erro: "Informe uma placa válida, como OXA3609 ou ABC1D23."
    });
}

    // Validar o telefone antes de consumir créditos
const numeroWhatsApp = String(telefone || "").replace(/\D/g, "");

if (!/^55\d{10,11}$/.test(numeroWhatsApp)) {
    return res.status(400).json({
        erro: "Informe um telefone válido com 55, DDD e número."
    });
}
 
    console.log("Placa recebida:", placa);
    console.log("Telefone recebido:", telefone);

    // Obter o token armazenado no arquivo .env
    const token = process.env.APIBRASIL_TOKEN;

    // Endereço da APIBrasil
    const url = "https://gateway.apibrasil.io/api/v2/consulta/veiculos/credits";

    // Verificar se o token está configurado
    if (!token) {
        return res.status(500).json({
            erro: "Token da APIBrasil não configurado."
        });
    }

    // Verificar se os campos foram preenchidos
    if (!placa || !telefone) {
        return res.status(400).json({
            erro: "Informe a placa e o telefone."
        });
    }

    try {

        // Enviar a consulta para a APIBrasil
        const respostaAPI = await fetch(url, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${token}`
            },
            body: JSON.stringify({
                tipo: "fipe-chassi",
                placa: placaFormatada,
                homolog: false
            })
        });

        // Converter a resposta para JSON
        const dadosAPI = await respostaAPI.json();

        console.log("Status da APIBrasil:", respostaAPI.status);

        // Verificar se a API retornou um erro HTTP
        if (!respostaAPI.ok) {
            return res.status(respostaAPI.status).json({
                erro: "A APIBrasil não conseguiu realizar a consulta."
            });
        }

        // Enviar a resposta para o frontend
        // Obter a lista de veículos retornados
const veiculos = dadosAPI.data?.resultados;

// Verificar se a lista existe e possui resultados
if (!Array.isArray(veiculos) || veiculos.length === 0) {
    return res.status(404).json({
        erro: "Nenhum veículo encontrado para esta placa."
    });
}

// Encontrar o veículo principal
const veiculoPrincipal = veiculos.find(
    (veiculo) => veiculo.principal === true
);

// Verificar se existe um resultado principal
if (!veiculoPrincipal) {
    return res.status(422).json({
        erro: "Não foi possível identificar o veículo principal."
    });
}

// Formatar o valor FIPE em reais
const valorFormatado = veiculoPrincipal.valor.toLocaleString("pt-BR", {
    style: "currency",
    currency: "BRL"
});

// Obter o DeviceToken do arquivo .env
const deviceToken = process.env.WHATSAPP_DEVICE_TOKEN;

// Verificar se o DeviceToken foi configurado
if (!deviceToken) {
    return res.status(500).json({
        erro: "DeviceToken do WhatsApp não configurado."
    });
}


// Montar a mensagem
const mensagemWhatsApp = `🚗 Consulta FIPE

Placa: ${placaFormatada}
Veículo: ${veiculoPrincipal.marca} ${veiculoPrincipal.modelo}
Ano: ${veiculoPrincipal.anoModelo}
Valor FIPE: ${valorFormatado}
Referência: ${veiculoPrincipal.mesReferencia}`;

// Endpoint de envio de mensagens
const urlWhatsApp = "https://gateway.apibrasil.io/api/v2/whatsapp/sendText";

// Enviar a mensagem
const respostaWhatsApp = await fetch(urlWhatsApp, {
    method: "POST",
    headers: {
        "Content-Type": "application/json",
        "DeviceToken": deviceToken,
        "Authorization": `Bearer ${token}`
    },
    body: JSON.stringify({
        number: numeroWhatsApp,
        text: mensagemWhatsApp,
        time_typing: 1200,
        options: {
            createChat: true,
            delay: 1200
        },
        homolog: false
    })
});

// Interpretar a resposta
const dadosWhatsApp = await respostaWhatsApp.json();

console.log("Status do WhatsApp:", respostaWhatsApp.status);
console.log("Erro informado pela APIBrasil:", {
    error: dadosWhatsApp.error,
    message: dadosWhatsApp.message,
    status_code: dadosWhatsApp.status_code
});

// Verificar se houve erro HTTP
if (!respostaWhatsApp.ok || dadosWhatsApp.error === true) {
    console.error("Falha no envio:", respostaWhatsApp.status);

    return res.status(502).json({
        erro: "A consulta FIPE foi realizada, mas o WhatsApp não aceitou o envio."
    });
}

console.log("Solicitação de envio aceita pela APIBrasil.");

// Enviar apenas os dados necessários ao frontend
res.json({
    mensagem: `Valor FIPE: ${valorFormatado}. Solicitação de envio ao WhatsApp aceita!`,
    veiculo: {
        marca: veiculoPrincipal.marca,
        modelo: veiculoPrincipal.modelo,
        ano: veiculoPrincipal.anoModelo,
        valor: valorFormatado,
        referencia: veiculoPrincipal.mesReferencia
    }
});

    } catch (erro) {

        // Tratar erros de comunicação
        console.error("Erro na consulta:", erro.message);

        res.status(500).json({
            erro: "Erro ao consultar a APIBrasil."
        });
    }

});

app.post("/webhook/whatsapp/:secret", (req, res) => {

        if (
        !process.env.WEBHOOK_SECRET ||
        req.params.secret !== process.env.WEBHOOK_SECRET
    ) {
        return res.sendStatus(404);
    }

    
    const eventos = Array.isArray(req.body)
    ? req.body
    : [req.body.data ?? req.body];

    if (!Array.isArray(eventos)) {
        return res.status(400).json({
            erro: "Formato de webhook inválido."
        });
    }
for (const evento of eventos) {

    if (evento.wook === "RECEIVE_MESSAGE") {
        console.log("Nova mensagem recebida!");
        console.log("Tipo:", evento.type);
    }

    if (evento.wook === "MESSAGE_STATUS") {
        console.log("Status da mensagem:", evento.status);
        console.log("ID da mensagem:", evento.id);
    }

}

    res.sendStatus(200);
});

// Iniciar o servidor
app.listen(PORT, () => {
    console.log(`Servidor rodando na porta ${PORT}`);
});