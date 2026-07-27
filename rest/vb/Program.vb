' Exemplos do gateway APIBrasil em VB.NET — sem SDK, só HttpClient.
'
'   export APIBRASIL_BEARER_TOKEN=...
'   dotnet run

Imports System.Net.Http
Imports System.Net.Http.Headers
Imports System.Text
Imports System.Text.Json

Module Program

    ' Uma instância para o processo. Criar um HttpClient por chamada esgota
    ' sockets (o socket fica em TIME_WAIT depois do Dispose).
    Private ReadOnly Http As New HttpClient With {
        .BaseAddress = New Uri("https://gateway.apibrasil.io/api/v2/"),
        .Timeout = TimeSpan.FromSeconds(30)
    }

    Function Main() As Integer
        Return MainAsync().GetAwaiter().GetResult()
    End Function

    Async Function MainAsync() As Task(Of Integer)
        Dim bearer = Environment.GetEnvironmentVariable("APIBRASIL_BEARER_TOKEN")
        Dim deviceToken = Environment.GetEnvironmentVariable("APIBRASIL_DEVICE_TOKEN")
        Dim numero = Environment.GetEnvironmentVariable("NUMERO")

        If String.IsNullOrEmpty(bearer) Then
            Console.Error.WriteLine("Defina APIBRASIL_BEARER_TOKEN no ambiente.")
            Return 1
        End If

        ' O token vai puro; o esquema "Bearer" é o primeiro argumento.
        Http.DefaultRequestHeaders.Authorization =
            New AuthenticationHeaderValue("Bearer", bearer)

        ' -------------------------------------------------------------------
        ' Saldo
        ' -------------------------------------------------------------------
        Dim saldo = Await Chamar(HttpMethod.Get, "balance", Nothing, Nothing)
        Console.WriteLine("Saldo: " & saldo)

        ' -------------------------------------------------------------------
        ' Consulta por crédito
        ' -------------------------------------------------------------------
        ' Só precisa do Authorization — o DeviceToken é ignorado aqui.
        ' homolog: true roda em sandbox, sem debitar saldo.
        Dim empresa = Await Chamar(HttpMethod.Post, "consulta/cnpj/credits",
            "{""cnpj"":""00000000000000"",""homolog"":true}", Nothing)
        Console.WriteLine(Environment.NewLine & "CNPJ (homologação): " & Truncar(empresa, 400))

        ' O campo `tipo` escolhe o PRODUTO dentro do serviço: mesmo endpoint,
        ' preço e retorno diferentes.
        Dim socios = Await Chamar(HttpMethod.Post, "consulta/cnpj/credits",
            "{""cnpj"":""00000000000000"",""tipo"":""lista-socios"",""homolog"":true}", Nothing)
        Console.WriteLine(Environment.NewLine & "Sócios: " & Truncar(socios, 400))

        ' -------------------------------------------------------------------
        ' Serviços device-based
        ' -------------------------------------------------------------------
        If Not String.IsNullOrEmpty(deviceToken) Then
            Dim cep = Await Chamar(HttpMethod.Post, "cep/cep", "{""cep"":""01001000""}", deviceToken)
            Console.WriteLine(Environment.NewLine & "CEP: " & Truncar(cep, 300))

            If Not String.IsNullOrEmpty(numero) Then
                ' WhatsApp — a sessão precisa estar iniciada e pareada.
                Await Chamar(HttpMethod.Post, "whatsapp/start", "{}", deviceToken)

                Dim enviado = Await Chamar(HttpMethod.Post, "whatsapp/sendText",
                    "{""number"":""" & numero & """,""text"":""Olá! Enviado em VB.NET 👋""," &
                    """time_typing"":1500}", deviceToken)
                Console.WriteLine(Environment.NewLine & "WhatsApp: " & Truncar(enviado, 300))

                ' Evolution API — rota com um nível a mais:
                ' /evolution/{controller}/{action}
                Dim evolution = Await Chamar(HttpMethod.Post, "evolution/message/sendText",
                    "{""number"":""" & numero & """," &
                    """options"":{""delay"":1200,""presence"":""composing""}," &
                    """textMessage"":{""text"":""Via Evolution API""}}", deviceToken)
                Console.WriteLine(Environment.NewLine & "Evolution: " & Truncar(evolution, 300))
            End If
        End If

        Return 0
    End Function

    ''' <summary>
    ''' Chama o gateway e devolve o corpo. Em erro, imprime o status e a mensagem
    ''' do gateway — que é a parte útil (diz o campo que faltou, o valor da
    ''' consulta, ou a rota que substituiu a que morreu).
    ''' </summary>
    ''' <param name="caminho">Relativo, sem barra no começo.</param>
    ''' <param name="deviceToken">Só nas rotas device-based.</param>
    Private Async Function Chamar(metodo As HttpMethod, caminho As String,
                                  corpo As String, deviceToken As String) As Task(Of String)

        Using requisicao As New HttpRequestMessage(metodo, caminho)
            If corpo IsNot Nothing Then
                requisicao.Content = New StringContent(corpo, Encoding.UTF8, "application/json")
            End If

            If Not String.IsNullOrEmpty(deviceToken) Then
                requisicao.Headers.Add("DeviceToken", deviceToken)
            End If

            Using resposta = Await Http.SendAsync(requisicao)
                Dim texto = Await resposta.Content.ReadAsStringAsync()

                If Not resposta.IsSuccessStatusCode Then
                    ' 400/422 payload · 401 bearer · 402 saldo · 403 device/IP/PJ
                    ' 404 sem dados · 410 rota morta · 429 limite · 5xx servidor
                    Console.Error.WriteLine($"  HTTP {CInt(resposta.StatusCode)} em {caminho}: {Mensagem(texto)}")

                    If resposta.StatusCode = Net.HttpStatusCode.TooManyRequests Then
                        ' Respeite o Retry-After antes de tentar de novo.
                        Console.Error.WriteLine($"  Retry-After: {resposta.Headers.RetryAfter}")
                    End If
                End If

                Return texto
            End Using
        End Using
    End Function

    ''' <summary>Puxa o campo "message" do JSON de erro.</summary>
    Private Function Mensagem(corpo As String) As String
        Try
            Using documento = JsonDocument.Parse(corpo)
                Dim valor As JsonElement = Nothing
                If documento.RootElement.TryGetProperty("message", valor) Then
                    Return valor.ToString()
                End If
            End Using
        Catch ex As JsonException
            ' Corpo não-JSON (ex: HTML de erro do proxy).
        End Try

        Return Truncar(corpo, 200)
    End Function

    Private Function Truncar(texto As String, limite As Integer) As String
        If String.IsNullOrEmpty(texto) OrElse texto.Length <= limite Then Return texto
        Return texto.Substring(0, limite) & "…"
    End Function

End Module
