<?php

/**
 * 03 — WhatsApp
 *
 * Serviço device-based: exige Authorization: Bearer + header DeviceToken.
 * O DeviceToken identifica UMA sessão de WhatsApp; o bearer identifica a conta.
 *
 * Fluxo completo: device → sessão → QR Code → pareamento → envio.
 *
 *   php 03-whatsapp.php                        # usa o device do .env
 *   CRIAR_DEVICE=1 php 03-whatsapp.php         # cria um device novo
 *   NUMERO=5511999999999 php 03-whatsapp.php   # e envia de verdade
 */

declare(strict_types=1);

require_once __DIR__ . '/env.php';

use ApiBrasil\ApiBrasil;
use ApiBrasil\Core\Errors\PermissionError;

exigir('APIBRASIL_BEARER_TOKEN');

$api = new ApiBrasil();
$temDevice = env('APIBRASIL_DEVICE_TOKEN') !== null;

// ---------------------------------------------------------------------------
// 1. O device
// ---------------------------------------------------------------------------
// A SecretKey (painel → API WhatsApp → SecretKey) é a única credencial que cria
// devices. Depois de criado, o device_token substitui ela no dia a dia.
if (env('CRIAR_DEVICE') === '1') {
    $secretKey = exigir('APIBRASIL_SECRET_KEY', 'CRIAR_DEVICE=1 precisa dela para criar o device.');

    $criado = $api->devices->store(
        ['device_name' => 'exemplo-php', 'type' => 'server'],
        ['secretKey' => $secretKey]
    );

    $token = $criado['device']['device_token'] ?? null;
    echo 'Device criado. Guarde este token no seu .env:' . PHP_EOL;
    echo "APIBRASIL_DEVICE_TOKEN={$token}" . PHP_EOL . PHP_EOL;

    $api->setDeviceToken((string) $token);
    $temDevice = true;
}

if (!$temDevice) {
    fwrite(STDERR, 'Defina APIBRASIL_DEVICE_TOKEN no .env, ou rode com CRIAR_DEVICE=1.' . PHP_EOL);
    exit(1);
}

// ---------------------------------------------------------------------------
// 2. A sessão
// ---------------------------------------------------------------------------
// Os webhooks são opcionais, mas é aqui que se registram — não existe outra
// chamada para isso. Sem eles você só descobre mensagens recebidas por polling.
try {
    $sessao = $api->whatsapp->start(array_filter([
        'webhook_wh_message' => env('WEBHOOK_MENSAGENS'), // mensagem recebida
        'webhook_wh_status' => env('WEBHOOK_STATUS'),     // status da sessão mudou
        'webhook_wh_connect' => env('WEBHOOK_CONEXAO'),   // conectou/desconectou
        'webhook_wh_qrcode' => env('WEBHOOK_QRCODE'),     // novo QR Code gerado
    ]));
    echo 'Sessão: ' . ($sessao['message'] ?? json_encode($sessao)) . PHP_EOL;
} catch (PermissionError $e) {
    // 403 aqui é quase sempre DeviceToken de outra API, ou IP fora da whitelist.
    fwrite(STDERR, 'Sem permissão para esse device: ' . $e->getMessage() . PHP_EOL);
    exit(1);
}

// ---------------------------------------------------------------------------
// 3. O QR Code
// ---------------------------------------------------------------------------
// Vem como data URI base64. Numa aplicação real você joga isso num <img src>;
// aqui gravamos em disco para escanear.
$qr = $api->whatsapp->qrcode();
$dataUri = $qr['response']['qrcode'] ?? null;

if (is_string($dataUri) && str_starts_with($dataUri, 'data:image')) {
    file_put_contents(__DIR__ . '/qrcode.png', base64_decode(explode(',', $dataUri, 2)[1]));
    echo 'QR Code salvo em qrcode.png — escaneie no WhatsApp → aparelhos conectados.' . PHP_EOL;
} else {
    echo 'QR Code: ' . json_encode($qr['response'] ?? $qr['message'] ?? 'sessão provavelmente já conectada') . PHP_EOL;
}

// ---------------------------------------------------------------------------
// 4. Envios
// ---------------------------------------------------------------------------
$numero = env('NUMERO');
if ($numero === null) {
    echo PHP_EOL . 'Defina NUMERO=5511999999999 para enviar de verdade.' . PHP_EOL;
    exit(0);
}

// Texto. `time_typing` simula "digitando..." antes de entregar.
$texto = $api->whatsapp->sendText([
    'number' => $numero,
    'text' => 'Olá! Mensagem enviada pela SDK PHP da APIBrasil 👋',
    'time_typing' => 1500,
]);
echo 'Texto: ' . ($texto['message'] ?? json_encode($texto)) . PHP_EOL;

// Arquivo por URL pública. Para base64, use sendFile64.
$api->whatsapp->sendFile([
    'number' => $numero,
    'path' => 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
    'caption' => 'Segue o documento',
]);

// Áudio (o gateway converte para mp3; máx. 6 min) e localização.
$api->whatsapp->sendAudio(['number' => $numero, 'path' => 'https://filesamples.com/samples/audio/mp3/sample3.mp3']);
$api->whatsapp->sendLocation(['number' => $numero, 'lat' => -23.5613, 'lng' => -46.6565]);

// Qualquer action da documentação, mesmo sem método dedicado na SDK.
$api->whatsapp->request('sendLink', [
    'number' => $numero,
    'url' => 'https://apibrasil.com.br',
    'text' => 'Conheça',
]);

// Fila: mesma action, processada de forma assíncrona pelo gateway. É o caminho
// certo para disparos em volume — devolve na hora e não segura sua requisição.
$enfileirado = $api->whatsapp->queue('sendText', [
    'number' => $numero,
    'text' => 'Esta foi pela fila 🚀',
]);
echo 'Fila: ' . ($enfileirado['message'] ?? json_encode($enfileirado)) . PHP_EOL;

// ---------------------------------------------------------------------------
// 5. Vários devices no mesmo processo
// ---------------------------------------------------------------------------
// withDevice devolve um cliente novo, sem alterar o original.
if (($suporteToken = env('APIBRASIL_DEVICE_TOKEN_SUPORTE')) !== null) {
    $suporte = $api->withDevice($suporteToken);
    $suporte->whatsapp->sendText(['number' => $numero, 'text' => 'Falando pela sessão do suporte']);
}
