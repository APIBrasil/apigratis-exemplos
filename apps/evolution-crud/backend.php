<?php

/**
 * CRUD de instâncias Evolution — backend.
 *
 * Evolution tem um nível a mais que os outros serviços:
 * /evolution/{controller}/{action}
 */

declare(strict_types=1);

require_once __DIR__ . '/../_comum/apibrasil.php';

use ApiBrasil\Comum\Entrada;
use ApiBrasil\Comum\Proxy;

Proxy::despachar([
    // ---------------------------------------------------------------------
    // Plataforma
    // ---------------------------------------------------------------------
    'listar' => [
        'metodo' => 'GET',
        'caminho' => '/devices',
    ],
    'servidores' => [
        'metodo' => 'GET',
        'caminho' => '/servers',
    ],
    'criar-device' => [
        'caminho' => '/devices/store',
        // ESTE é o único lugar onde a SecretKey tem função.
        'secret' => true,
        'corpo' => fn (Entrada $e): array => [
            'server_search' => $e->slug('servidor', 64, 'Servidor'),
            'type' => 'cellphone',
            'device_name' => $e->slug('nome', 40, 'Nome do device'),
            'device_key' => $e->slug('nome', 40, 'Nome do device'),
            'webhook_wh_message' => getenv('WEBHOOK_MENSAGENS') ?: '',
            'webhook_wh_status' => getenv('WEBHOOK_STATUS') ?: '',
        ],
    ],

    // ---------------------------------------------------------------------
    // Evolution — instância
    // ---------------------------------------------------------------------
    'criar-instancia' => [
        'caminho' => '/evolution/instance/create',
        'device' => true,
        // O instanceName precisa ser IGUAL ao device_name — é assim que o
        // gateway amarra a instância ao device.
        'corpo' => fn (Entrada $e): array => [
            'instanceName' => $e->slug('nome', 40, 'Nome da instância'),
            'qrcode' => true,
        ],
    ],
    'estado' => [
        'caminho' => '/evolution/instance/connectionState',
        'device' => true,
    ],
    'reiniciar' => [
        'caminho' => '/evolution/instance/restart',
        'device' => true,
    ],
    'apagar' => [
        'caminho' => '/evolution/instance/delete',
        'device' => true,
    ],

    // ---------------------------------------------------------------------
    // Evolution — mensagem
    // ---------------------------------------------------------------------
    'enviar' => [
        'caminho' => '/evolution/message/sendText',
        'device' => true,
        'corpo' => fn (Entrada $e): array => [
            'number' => $e->telefone(),
            'options' => ['delay' => 1200, 'presence' => 'composing'],
            'textMessage' => ['text' => $e->texto('texto', 4096, 'mensagem')],
        ],
    ],
]);
