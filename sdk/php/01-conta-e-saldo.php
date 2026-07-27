<?php

/**
 * 01 — Conta e saldo
 *
 * O básico: montar o cliente, confirmar que o gateway responde e ler os dados
 * da conta. Nada aqui gasta crédito.
 *
 *   php 01-conta-e-saldo.php
 */

declare(strict_types=1);

require_once __DIR__ . '/env.php';

use ApiBrasil\ApiBrasil;
use ApiBrasil\Core\Errors\ApiBrasilError;
use ApiBrasil\Core\Errors\AuthenticationError;

// Sem argumentos, o cliente lê APIBRASIL_BEARER_TOKEN, APIBRASIL_DEVICE_TOKEN,
// APIBRASIL_SECRET_KEY e APIBRASIL_BASE_URL do ambiente.
$api = new ApiBrasil();

// /status é público — separa "minha credencial está errada" de "o gateway caiu".
$status = $api->catalog->status();
echo 'Gateway: ' . ($status['message'] ?? json_encode($status)) . PHP_EOL;

exigir('APIBRASIL_BEARER_TOKEN');

try {
    $saldo = $api->account->balance();
    echo 'Saldo: ' . json_encode($saldo) . PHP_EOL;

    $plano = $api->account->plan();
    echo 'Plano: ' . json_encode($plano) . PHP_EOL;

    // Devices ativos na conta — cada um é uma instância de um serviço.
    $lista = $api->devices->list();
    $devices = $lista['devices'] ?? [];

    echo PHP_EOL . count($devices) . ' device(s):' . PHP_EOL;
    foreach ($devices as $device) {
        printf(
            "  %s · %s · %s\n",
            $device['device_name'] ?? '—',
            $device['api']['name'] ?? '—',
            $device['status'] ?? '—'
        );
    }
} catch (AuthenticationError $e) {
    fwrite(STDERR, 'Bearer inválido ou expirado — refaça o login no painel.' . PHP_EOL);
    exit(1);
} catch (ApiBrasilError $e) {
    fwrite(STDERR, sprintf("Falhou (HTTP %s): %s\n", $e->getStatus() ?? '—', $e->getMessage()));
    exit(1);
}

// Login por email/senha, se você preferir não guardar o JWT:
//
//   $api = new ApiBrasil();
//   $sessao = $api->auth->login(['email' => $email, 'password' => $senha]);
//   if (!empty($sessao['requires_2fa'])) {
//       $api->auth->send2fa(['challenge' => $sessao['challenge'], 'method' => 'email']);
//       $api->auth->verify2fa(['challenge' => $sessao['challenge'], 'code' => '000000']);
//   }
//   // o token já ficou guardado no cliente — siga usando $api normalmente
