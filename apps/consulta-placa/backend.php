<?php

/**
 * Consulta de placa — backend.
 *
 * Usa as rotas device-based (/vehicles/*), que cobram por plano. Para a versão
 * por crédito, troque o caminho por /consulta/veiculos/credits e remova
 * 'device' => true — o front não muda.
 */

declare(strict_types=1);

require_once __DIR__ . '/../_comum/apibrasil.php';

use ApiBrasil\Comum\Entrada;
use ApiBrasil\Comum\Proxy;

/** Placa é validada antes de virar chamada cobrada. */
$placa = fn (Entrada $e): array => Proxy::comHomolog(['placa' => $e->placa()]);

Proxy::despachar([
    'dados' => [
        'caminho' => '/vehicles/dados',
        'device' => true,
        'deviceEnv' => 'VEICULOS',
        'corpo' => $placa,
    ],
    'fipe' => [
        'caminho' => '/vehicles/fipe',
        'device' => true,
        'deviceEnv' => 'VEICULOS',
        'corpo' => $placa,
    ],
]);
