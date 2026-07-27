<?php

/**
 * Gestão de devices WhatsApp — backend.
 *
 * O DeviceToken vem do front (é um app multi-device), então as ações abaixo
 * marcam 'device' => true e o proxy lê o token da requisição.
 */

declare(strict_types=1);

require_once __DIR__ . '/../_comum/apibrasil.php';

use ApiBrasil\Comum\Proxy;

/**
 * Repare no que NÃO está aqui: devices/store (criar device consome cota),
 * devices/destroy (apaga de verdade) e qualquer rota de pagamento. Uma
 * allowlist frouxa entrega a conta inteira ao visitante.
 */
Proxy::despachar([
    'listar' => [
        'metodo' => 'GET',
        'caminho' => '/devices',
    ],
    'detalhe' => [
        'metodo' => 'GET',
        'caminho' => '/devices/show',
        'device' => true,
    ],
    'status' => [
        'caminho' => '/whatsapp/getConnectionStatus',
        'device' => true,
    ],
    'iniciar' => [
        'caminho' => '/whatsapp/start',
        'device' => true,
        // Os webhooks são registrados AQUI, e só aqui. Sem eles, mensagem
        // recebida só chega por polling.
        'corpo' => fn (): array => array_filter([
            'webhook_wh_message' => getenv('WEBHOOK_MENSAGENS') ?: null,
            'webhook_wh_status' => getenv('WEBHOOK_STATUS') ?: null,
            'webhook_wh_connect' => getenv('WEBHOOK_CONEXAO') ?: null,
            'webhook_wh_qrcode' => getenv('WEBHOOK_QRCODE') ?: null,
        ]),
    ],
    'qrcode' => [
        'caminho' => '/whatsapp/qrcode',
        'device' => true,
    ],
    'encerrar' => [
        'caminho' => '/whatsapp/logout',
        'device' => true,
    ],
]);
