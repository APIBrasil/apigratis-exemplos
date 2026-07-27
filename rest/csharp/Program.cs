// Exemplos do gateway APIBrasil em C# — sem SDK, só HttpClient.
//
//   export APIBRASIL_BEARER_TOKEN=...
//   dotnet run

using System.Text.Json;
using ApiBrasil.Exemplos;

var bearer = Environment.GetEnvironmentVariable("APIBRASIL_BEARER_TOKEN");
var deviceToken = Environment.GetEnvironmentVariable("APIBRASIL_DEVICE_TOKEN");
var numero = Environment.GetEnvironmentVariable("NUMERO");

if (string.IsNullOrEmpty(bearer))
{
    Console.Error.WriteLine("Defina APIBRASIL_BEARER_TOKEN no ambiente.");
    return 1;
}

// Um HttpClient para o processo inteiro. Em ASP.NET, use IHttpClientFactory.
using var http = new HttpClient();
var api = new ApiBrasilClient(http, bearer, deviceToken);

// ---------------------------------------------------------------------------
// Saldo e plano
// ---------------------------------------------------------------------------
try
{
    Console.WriteLine($"Saldo: {await api.GetAsync("balance")}");
    Console.WriteLine($"Plano: {await api.GetAsync("plan")}");
}
catch (ApiBrasilException e) when (e.NaoAutenticado)
{
    Console.Error.WriteLine("Bearer inválido ou expirado — refaça o login no painel.");
    return 1;
}

// ---------------------------------------------------------------------------
// Consulta por crédito
// ---------------------------------------------------------------------------
// Só precisa do Authorization. `homolog: true` roda em sandbox, sem debitar.
try
{
    var empresa = await api.PostAsync("consulta/cnpj/credits", new
    {
        cnpj = "00000000000000",
        homolog = true
    });

    // O envelope é sempre o mesmo:
    // { error, message, balance, tax, valor_consulta, data }
    Console.WriteLine($"\nCNPJ (homologação):");
    Console.WriteLine($"  custou: {Campo(empresa, "valor_consulta")}");
    Console.WriteLine($"  saldo restante: {Campo(empresa, "balance")}");
    Console.WriteLine($"  data: {Truncar(Campo(empresa, "data"), 300)}");

    // O campo `tipo` escolhe o PRODUTO dentro do serviço — mesmo endpoint,
    // preço e retorno diferentes. São 210+ tipos no catálogo.
    var socios = await api.PostAsync("consulta/cnpj/credits", new
    {
        cnpj = "00000000000000",
        tipo = "lista-socios",
        homolog = true
    });
    Console.WriteLine($"\nSócios: {Truncar(Campo(socios, "data"), 300)}");
}
catch (ApiBrasilException e) when (e.SemSaldo)
{
    // A mensagem do gateway traz o valor exato da consulta.
    Console.Error.WriteLine($"Sem saldo: {e.Message}");
}
catch (ApiBrasilException e) when (e.RotaMorta)
{
    // 410 — a mensagem aponta a rota nova.
    Console.Error.WriteLine($"Rota descontinuada: {e.Message}");
}

// ---------------------------------------------------------------------------
// Serviços device-based
// ---------------------------------------------------------------------------
if (!string.IsNullOrEmpty(deviceToken))
{
    try
    {
        var cep = await api.PostAsync("cep/cep", new { cep = "01001000" });
        Console.WriteLine($"\nCEP: {Truncar(Campo(cep, "response"), 300)}");
    }
    catch (ApiBrasilException e) when (e.SemPermissao)
    {
        // 403 tem três causas: DeviceToken de outra API, IP fora da whitelist,
        // ou API que exige cadastro PJ. A mensagem diz qual.
        Console.Error.WriteLine($"Sem permissão: {e.Message}");
    }

    // WhatsApp
    if (!string.IsNullOrEmpty(numero))
    {
        await api.PostAsync("whatsapp/start", new { });

        var enviado = await api.PostAsync("whatsapp/sendText", new
        {
            number = numero,
            text = "Olá! Enviado em C# 👋",
            time_typing = 1500
        });
        Console.WriteLine($"\nWhatsApp: {Campo(enviado, "message")}");

        // Fila: o gateway processa de forma assíncrona. Caminho certo para
        // disparos em volume — responde na hora.
        await api.PostAsync("whatsapp/sendText/queue", new
        {
            number = numero,
            text = "Esta foi pela fila 🚀"
        });
    }
}

// ---------------------------------------------------------------------------
// Retry que não duplica cobrança
// ---------------------------------------------------------------------------
try
{
    var saldo = await ComRetrySeguro(() => api.GetAsync("balance"));
    Console.WriteLine($"\nSaldo (com retry): {saldo}");
}
catch (ApiBrasilException e)
{
    Console.Error.WriteLine($"Desisti: {e.Message}");
}

return 0;

/// <summary>
/// Repete só em 429 e 5xx, respeitando o Retry-After. Timeout e erro de negócio
/// nunca são repetidos: um envio que deu timeout pode ter sido entregue, e uma
/// consulta repetida cobra duas vezes.
/// </summary>
static async Task<JsonElement> ComRetrySeguro(Func<Task<JsonElement>> chamada, int tentativas = 3)
{
    for (var i = 1; ; i++)
    {
        try
        {
            return await chamada();
        }
        catch (ApiBrasilException e) when ((e.LimiteAtingido || e.ErroServidor) && i < tentativas)
        {
            var espera = e.RetryAfter ?? TimeSpan.FromMilliseconds(250 * Math.Pow(2, i));
            Console.Error.WriteLine($"  retry em {espera.TotalMilliseconds:F0}ms ({i}/{tentativas})");
            await Task.Delay(espera);
        }
        // TaskCanceledException (timeout do HttpClient) e os demais
        // ApiBrasilException sobem direto — repetir não é seguro nem útil.
    }
}

static string Campo(JsonElement json, string nome) =>
    json.ValueKind == JsonValueKind.Object && json.TryGetProperty(nome, out var valor)
        ? valor.ToString()
        : "—";

static string Truncar(string texto, int limite) =>
    texto.Length <= limite ? texto : texto[..limite] + "…";
