<%
' ============================================================================
'  APIBrasil — funções mínimas para ASP clássico (VBScript)
'
'  Duas famílias de serviço:
'    device-based  -> Authorization + DeviceToken   (/whatsapp, /sms, /cep...)
'    por crédito   -> Authorization                 (/consulta/{servico}/credits)
'
'  Inclua com: <!--#include file="apibrasil.asp"-->
' ============================================================================

Const APIBRASIL_BASE = "https://gateway.apibrasil.io/api/v2"

' Status HTTP e corpo da última chamada — leia depois de cada ApiBrasil*.
Dim ApiBrasilStatus, ApiBrasilCorpo

' ----------------------------------------------------------------------------
' Lê variável de ambiente do pool de aplicação do IIS.
' Nunca escreva token no fonte: o .asp é servido pelo IIS.
' ----------------------------------------------------------------------------
Function GetEnvVar(nome)
    On Error Resume Next
    Dim shell
    Set shell = Server.CreateObject("WScript.Shell")
    GetEnvVar = shell.Environment("Process")(nome)
    Set shell = Nothing
    On Error GoTo 0
End Function

' ----------------------------------------------------------------------------
' Converte responseBody (bytes) para string UTF-8.
' .responseText interpreta como Latin-1 quando o servidor não manda charset,
' e o acento vira "Ã§".
' ----------------------------------------------------------------------------
Function LerRespostaUtf8(http)
    Dim stream
    Set stream = Server.CreateObject("ADODB.Stream")
    stream.Type = 1                  ' binário
    stream.Open
    stream.Write http.responseBody
    stream.Position = 0
    stream.Type = 2                  ' texto
    stream.Charset = "utf-8"
    LerRespostaUtf8 = stream.ReadText
    stream.Close
    Set stream = Nothing
End Function

' ----------------------------------------------------------------------------
' POST JSON no gateway.
'   caminho     : começa com "/" (ex: "/whatsapp/sendText")
'   corpoJson   : string JSON
'   bearer      : JWT da conta
'   deviceToken : só nas rotas device-based; passe "" nas de crédito
'   secretKey   : só em /devices/store; passe "" no resto
' ----------------------------------------------------------------------------
Function ApiBrasilPost(caminho, corpoJson, bearer, deviceToken, secretKey)
    Dim http
    Set http = Server.CreateObject("MSXML2.ServerXMLHTTP")

    ' Sem timeout, uma chamada travada segura um worker do IIS.
    ' resolve, connect, send, receive — em ms.
    http.setTimeouts 5000, 5000, 15000, 30000

    http.Open "POST", APIBRASIL_BASE & caminho, False
    http.setRequestHeader "Content-Type", "application/json; charset=utf-8"
    http.setRequestHeader "Accept", "application/json"
    http.setRequestHeader "Authorization", "Bearer " & bearer

    ' Só mande o que a rota usa. PublicToken não existe no gateway, e SecretKey
    ' só tem função em /devices/store.
    If Len(deviceToken) > 0 Then
        http.setRequestHeader "DeviceToken", deviceToken
    End If
    If Len(secretKey) > 0 Then
        http.setRequestHeader "SecretKey", secretKey
    End If

    http.Send corpoJson

    ApiBrasilStatus = http.Status
    ApiBrasilCorpo = LerRespostaUtf8(http)
    ApiBrasilPost = ApiBrasilCorpo

    Set http = Nothing
End Function

' ----------------------------------------------------------------------------
' GET no gateway (saldo, plano, devices, catálogo).
' ----------------------------------------------------------------------------
Function ApiBrasilGet(caminho, bearer)
    Dim http
    Set http = Server.CreateObject("MSXML2.ServerXMLHTTP")
    http.setTimeouts 5000, 5000, 15000, 30000

    http.Open "GET", APIBRASIL_BASE & caminho, False
    http.setRequestHeader "Accept", "application/json"
    http.setRequestHeader "Authorization", "Bearer " & bearer
    http.Send

    ApiBrasilStatus = http.Status
    ApiBrasilCorpo = LerRespostaUtf8(http)
    ApiBrasilGet = ApiBrasilCorpo

    Set http = Nothing
End Function

' ----------------------------------------------------------------------------
' Explica o status HTTP em português — os do gateway têm semântica.
' ----------------------------------------------------------------------------
Function ApiBrasilExplicaStatus(status)
    Select Case status
        Case 200, 201 ApiBrasilExplicaStatus = "ok"
        Case 400, 422 ApiBrasilExplicaStatus = "payload invalido — confira os campos"
        Case 401      ApiBrasilExplicaStatus = "bearer ausente ou expirado — refaca o login"
        Case 402      ApiBrasilExplicaStatus = "sem saldo/creditos — recarregue"
        Case 403      ApiBrasilExplicaStatus = "sem permissao — DeviceToken, IP whitelist ou API que exige PJ"
        Case 404      ApiBrasilExplicaStatus = "sem dados"
        Case 410      ApiBrasilExplicaStatus = "rota desativada — a mensagem aponta a nova"
        Case 429      ApiBrasilExplicaStatus = "limite por minuto atingido"
        Case Else
            If status >= 500 Then
                ApiBrasilExplicaStatus = "falha do gateway ou do provedor"
            Else
                ApiBrasilExplicaStatus = "status " & status
            End If
    End Select
End Function

' ----------------------------------------------------------------------------
' Escapa uma string para dentro de JSON.
' ----------------------------------------------------------------------------
Function JsonEscape(texto)
    Dim s
    s = Replace(texto, "\", "\\")
    s = Replace(s, """", "\""")
    s = Replace(s, vbCrLf, "\n")
    s = Replace(s, vbCr, "\n")
    s = Replace(s, vbLf, "\n")
    s = Replace(s, vbTab, "\t")
    JsonEscape = s
End Function
%>
