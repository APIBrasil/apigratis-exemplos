using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace ApiBrasil.Exemplos;

/// <summary>
/// Erro do gateway APIBrasil, com o status e o corpo original preservados.
/// A mensagem do gateway é a parte útil — é ela que diz qual campo faltou,
/// quanto custava a consulta ou qual rota substituiu a que morreu.
/// </summary>
public class ApiBrasilException : Exception
{
    public HttpStatusCode Status { get; }
    public string? Corpo { get; }

    public ApiBrasilException(HttpStatusCode status, string? corpo, string mensagem)
        : base(mensagem)
    {
        Status = status;
        Corpo = corpo;
    }

    /// <summary>Sem saldo/créditos (402) — recarregue.</summary>
    public bool SemSaldo => Status == HttpStatusCode.PaymentRequired;

    /// <summary>Bearer ausente ou expirado (401) — refaça o login.</summary>
    public bool NaoAutenticado => Status == HttpStatusCode.Unauthorized;

    /// <summary>DeviceToken errado, IP fora da whitelist, ou API que exige PJ (403).</summary>
    public bool SemPermissao => Status == HttpStatusCode.Forbidden;

    /// <summary>Rota desativada (410) — a mensagem aponta a substituta.</summary>
    public bool RotaMorta => Status == HttpStatusCode.Gone;

    /// <summary>Limite por minuto atingido (429).</summary>
    public bool LimiteAtingido => Status == HttpStatusCode.TooManyRequests;

    /// <summary>Falha do gateway ou do provedor (5xx) — vale repetir com backoff.</summary>
    public bool ErroServidor => (int)Status >= 500;

    /// <summary>Espera sugerida pelo servidor no header Retry-After.</summary>
    public TimeSpan? RetryAfter { get; init; }
}

/// <summary>
/// Cliente mínimo do gateway APIBrasil.
///
/// Duas famílias de serviço:
///   device-based  → Authorization + DeviceToken   (/whatsapp, /sms, /cep, /vehicles…)
///   por crédito   → Authorization                 (/consulta/{servico}/credits)
/// </summary>
public sealed class ApiBrasilClient
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    private readonly HttpClient _http;
    private readonly string? _deviceTokenPadrao;

    /// <param name="http">
    /// Injete um HttpClient de vida longa (IHttpClientFactory em ASP.NET).
    /// Criar um por chamada esgota sockets.
    /// </param>
    public ApiBrasilClient(HttpClient http, string bearerToken, string? deviceToken = null,
        string baseUrl = "https://gateway.apibrasil.io/api/v2/")
    {
        _http = http;
        _deviceTokenPadrao = deviceToken;

        // A barra no fim é obrigatória: sem ela, o Uri relativo substitui o
        // último segmento em vez de somar.
        _http.BaseAddress = new Uri(baseUrl.EndsWith('/') ? baseUrl : baseUrl + "/");
        _http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", bearerToken);
        _http.Timeout = TimeSpan.FromSeconds(30);
    }

    /// <summary>
    /// POST em qualquer rota do gateway. O caminho é relativo — sem barra no
    /// começo, senão a BaseAddress é descartada.
    /// </summary>
    public async Task<JsonElement> PostAsync(string caminho, object? corpo = null,
        string? deviceToken = null, CancellationToken ct = default)
    {
        using var requisicao = new HttpRequestMessage(HttpMethod.Post, caminho.TrimStart('/'))
        {
            Content = JsonContent.Create(corpo ?? new { }, options: Json)
        };

        // DeviceToken só nas rotas device-based. Nas de crédito é ignorado.
        var device = deviceToken ?? _deviceTokenPadrao;
        if (!string.IsNullOrEmpty(device))
        {
            requisicao.Headers.Add("DeviceToken", device);
        }

        return await EnviarAsync(requisicao, ct);
    }

    /// <summary>GET em qualquer rota do gateway.</summary>
    public async Task<JsonElement> GetAsync(string caminho, CancellationToken ct = default)
    {
        using var requisicao = new HttpRequestMessage(HttpMethod.Get, caminho.TrimStart('/'));
        return await EnviarAsync(requisicao, ct);
    }

    /// <summary>
    /// Cria um device. ESTE é o único lugar onde a SecretKey tem função —
    /// em rotas de envio ela não serve para nada.
    /// </summary>
    public async Task<JsonElement> CriarDeviceAsync(string nome, string secretKey,
        CancellationToken ct = default)
    {
        using var requisicao = new HttpRequestMessage(HttpMethod.Post, "devices/store")
        {
            Content = JsonContent.Create(new { device_name = nome, type = "server" }, options: Json)
        };
        requisicao.Headers.Add("SecretKey", secretKey);

        return await EnviarAsync(requisicao, ct);
    }

    private async Task<JsonElement> EnviarAsync(HttpRequestMessage requisicao, CancellationToken ct)
    {
        using var resposta = await _http.SendAsync(requisicao, ct);
        var corpo = await resposta.Content.ReadAsStringAsync(ct);

        if (!resposta.IsSuccessStatusCode)
        {
            throw new ApiBrasilException(resposta.StatusCode, corpo, ExtrairMensagem(corpo, resposta))
            {
                RetryAfter = resposta.Headers.RetryAfter?.Delta
            };
        }

        return string.IsNullOrWhiteSpace(corpo)
            ? default
            : JsonSerializer.Deserialize<JsonElement>(corpo, Json);
    }

    /// <summary>Puxa o campo "message" do erro; cai para o status se não houver.</summary>
    private static string ExtrairMensagem(string corpo, HttpResponseMessage resposta)
    {
        try
        {
            var json = JsonSerializer.Deserialize<JsonElement>(corpo, Json);
            if (json.ValueKind == JsonValueKind.Object &&
                json.TryGetProperty("message", out var mensagem) &&
                mensagem.ValueKind == JsonValueKind.String)
            {
                return mensagem.GetString()!;
            }
        }
        catch (JsonException)
        {
            // Corpo não-JSON (ex: HTML de erro do proxy). Usa o status.
        }

        return $"HTTP {(int)resposta.StatusCode} {resposta.ReasonPhrase}";
    }
}
