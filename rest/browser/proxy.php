<?php

/**
 * Proxy mínimo para o gateway APIBrasil.
 *
 * O navegador chama este arquivo; ele adiciona o Bearer Token e repassa ao
 * gateway. O token nunca sai do servidor.
 *
 * Rodando local:
 *   APIBRASIL_BEARER_TOKEN=... php -S localhost:8000
 *   http://localhost:8000/com-proxy.html
 *
 * Três coisas que um proxy precisa fazer, e que este faz:
 *   1. validar a entrada (senão você virou um proxy aberto para o seu saldo)
 *   2. restringir quais rotas podem ser chamadas (allowlist, não passa-tudo)
 *   3. repassar o status do gateway, para o front tratar 402/403/422
 */

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

// ---------------------------------------------------------------------------
// 1. Só POST
// ---------------------------------------------------------------------------
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    header('Allow: POST');
    echo json_encode(['error' => true, 'message' => 'Use POST.']);
    exit;
}

$bearer = getenv('APIBRASIL_BEARER_TOKEN');

if ($bearer === false || $bearer === '') {
    // Não vaze detalhe de configuração para o cliente.
    error_log('APIBRASIL_BEARER_TOKEN não definido no ambiente.');
    http_response_code(500);
    echo json_encode(['error' => true, 'message' => 'Serviço indisponível.']);
    exit;
}

// ---------------------------------------------------------------------------
// 2. Validação da entrada
// ---------------------------------------------------------------------------
// Sem isso, qualquer visitante manda qualquer payload e gasta o seu saldo.
$entrada = json_decode(file_get_contents('php://input') ?: '{}', true);
$cnpj = preg_replace('/\D/', '', (string) ($entrada['cnpj'] ?? ''));

if (strlen($cnpj) !== 14) {
    http_response_code(422);
    echo json_encode(['error' => true, 'message' => 'CNPJ deve ter 14 dígitos.']);
    exit;
}

// Numa aplicação real, adicione também:
//   - rate limit por IP ou por sessão
//   - autenticação do seu próprio usuário
//   - cache das consultas (CNPJ muda pouco e cada consulta custa)

// ---------------------------------------------------------------------------
// 3. Chamada ao gateway
// ---------------------------------------------------------------------------
// Rota por crédito: só o Authorization, sem DeviceToken.
$curl = curl_init('https://gateway.apibrasil.io/api/v2/consulta/cnpj/credits');

curl_setopt_array($curl, [
    CURLOPT_POST => true,
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_CONNECTTIMEOUT => 15,
    CURLOPT_TIMEOUT => 30,
    CURLOPT_HTTPHEADER => [
        'Content-Type: application/json',
        'Accept: application/json',
        'Authorization: Bearer ' . $bearer,
    ],
    CURLOPT_POSTFIELDS => json_encode([
        'cnpj' => $cnpj,
        // Troque para false quando quiser dados reais (e debitar saldo).
        'homolog' => true,
    ]),
]);

$resposta = curl_exec($curl);
$status = (int) curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
$erroCurl = curl_error($curl);

// Sem curl_close(): desde o PHP 8.0 o handle é um objeto e a função é um no-op
// deprecado.

if ($resposta === false) {
    error_log("Falha ao chamar o gateway: {$erroCurl}");
    http_response_code(502);
    echo json_encode(['error' => true, 'message' => 'Falha ao consultar o serviço.']);
    exit;
}

// ---------------------------------------------------------------------------
// 4. Repassa status e corpo
// ---------------------------------------------------------------------------
// Manter o status preserva a semântica para o front: 402 saldo, 403 permissão,
// 422 payload, 429 limite. Trocar tudo por 500 joga essa informação no lixo.
http_response_code($status);
echo $resposta;
