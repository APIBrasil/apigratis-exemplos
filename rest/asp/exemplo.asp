<%@ Language="VBScript" CodePage="65001" %>
<%
' ============================================================================
'  Exemplos do gateway APIBrasil em ASP clássico.
'
'  Credenciais vêm do ambiente do pool de aplicação do IIS — nunca do fonte.
' ============================================================================
Option Explicit
Response.Charset = "utf-8"
%>
<!--#include file="apibrasil.asp"-->
<%
Dim bearer, deviceToken, numero, resposta

bearer = GetEnvVar("APIBRASIL_BEARER_TOKEN")
deviceToken = GetEnvVar("APIBRASIL_DEVICE_TOKEN")
numero = Request.QueryString("numero")

If Len(bearer) = 0 Then
    Response.Write "<p><strong>Defina APIBRASIL_BEARER_TOKEN</strong> no ambiente do pool de aplicação.</p>"
    Response.End
End If
%>
<!doctype html>
<html lang="pt-BR">
<head>
    <meta charset="utf-8">
    <title>APIBrasil — exemplo ASP</title>
    <style>
        body { font-family: system-ui, sans-serif; max-width: 60rem; margin: 2rem auto; padding: 0 1rem; }
        pre { background: #f4f4f5; padding: 1rem; overflow-x: auto; border-radius: .375rem; }
        .erro { color: #b91c1c; }
    </style>
</head>
<body>

<h1>APIBrasil — exemplo ASP clássico</h1>

<h2>Saldo</h2>
<%
resposta = ApiBrasilGet("/balance", bearer)

If ApiBrasilStatus >= 400 Then
    Response.Write "<p class=""erro"">HTTP " & ApiBrasilStatus & " — " & _
        Server.HTMLEncode(ApiBrasilExplicaStatus(ApiBrasilStatus)) & "</p>"
End If
%>
<pre><%= Server.HTMLEncode(resposta) %></pre>

<h2>Consulta CNPJ (homologação)</h2>
<p>
    Rota por crédito: só o <code>Authorization</code>, sem <code>DeviceToken</code>.
    Com <code>"homolog": true</code> roda em sandbox, sem debitar saldo.
</p>
<%
' Note o "" no lugar do deviceToken: rotas de crédito não usam device.
resposta = ApiBrasilPost("/consulta/cnpj/credits", _
    "{""cnpj"":""00000000000000"",""homolog"":true}", bearer, "", "")

If ApiBrasilStatus >= 400 Then
    Response.Write "<p class=""erro"">HTTP " & ApiBrasilStatus & " — " & _
        Server.HTMLEncode(ApiBrasilExplicaStatus(ApiBrasilStatus)) & "</p>"
End If
%>
<pre><%= Server.HTMLEncode(Left(resposta, 2000)) %></pre>

<%
' ----------------------------------------------------------------------------
' Serviços device-based
' ----------------------------------------------------------------------------
If Len(deviceToken) > 0 Then
%>
    <h2>CEP</h2>
    <p>Rota device-based: <code>Authorization</code> + <code>DeviceToken</code>.</p>
    <%
    resposta = ApiBrasilPost("/cep/cep", "{""cep"":""01001000""}", bearer, deviceToken, "")

    If ApiBrasilStatus >= 400 Then
        Response.Write "<p class=""erro"">HTTP " & ApiBrasilStatus & " — " & _
            Server.HTMLEncode(ApiBrasilExplicaStatus(ApiBrasilStatus)) & "</p>"
    End If
    %>
    <pre><%= Server.HTMLEncode(Left(resposta, 1500)) %></pre>

    <h2>WhatsApp</h2>
    <%
    If Len(numero) > 0 Then
        ' A sessão precisa estar iniciada e pareada (QR Code escaneado).
        Call ApiBrasilPost("/whatsapp/start", "{}", bearer, deviceToken, "")

        resposta = ApiBrasilPost("/whatsapp/sendText", _
            "{""number"":""" & JsonEscape(numero) & """," & _
            """text"":""Olá! Enviado pelo ASP 👋""," & _
            """time_typing"":1500}", bearer, deviceToken, "")

        If ApiBrasilStatus >= 400 Then
            Response.Write "<p class=""erro"">HTTP " & ApiBrasilStatus & " — " & _
                Server.HTMLEncode(ApiBrasilExplicaStatus(ApiBrasilStatus)) & "</p>"
        End If
        %>
        <pre><%= Server.HTMLEncode(Left(resposta, 1000)) %></pre>
        <%
    Else
        %>
        <p>Passe <code>?numero=5511999999999</code> na URL para enviar de verdade.</p>
        <%
    End If
End If
%>

<hr>
<p>
    Documentação das APIs: <a href="https://doc.apibrasil.io">doc.apibrasil.io</a> ·
    Credenciais: <a href="https://apibrasil.com.br">apibrasil.com.br</a>
</p>

</body>
</html>
