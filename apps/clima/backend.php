<?php

/**
 * Clima — backend.
 *
 * Serviço device-based: /weather/{action}.
 *
 * Note a grafia da action de coordenadas: `coordenates` — é assim no gateway,
 * não `coordinates`.
 */

declare(strict_types=1);

require_once __DIR__ . '/../_comum/apibrasil.php';

use ApiBrasil\Comum\Entrada;
use ApiBrasil\Comum\Proxy;

Proxy::despachar([
    'cidade' => [
        'caminho' => '/weather/city',
        'device' => true,
        'deviceEnv' => 'CLIMA',
        'corpo' => fn (Entrada $e): array => ['city' => $e->texto('cidade', 120, 'cidade')],
    ],
    'coordenadas' => [
        'caminho' => '/weather/coordenates',
        'device' => true,
        'deviceEnv' => 'CLIMA',
        'corpo' => fn (Entrada $e): array => [
            'lat' => $e->decimal('lat', -90, 90, 'Latitude'),
            'lng' => $e->decimal('lng', -180, 180, 'Longitude'),
        ],
    ],
]);
