<?php

/**
 * Feriados — backend.
 *
 * Serviço device-based: /holidays/{action}.
 *
 * A action é `feriados` (em português). Não existe /holidays/holidays.
 */

declare(strict_types=1);

require_once __DIR__ . '/../_comum/apibrasil.php';

use ApiBrasil\Comum\Entrada;
use ApiBrasil\Comum\Proxy;

/** O `type` decide o conjunto retornado. */
const TIPOS = ['nacional', 'estadual', 'facultativo'];

Proxy::despachar([
    'feriados' => [
        'caminho' => '/holidays/feriados',
        'device' => true,
        'deviceEnv' => 'CLIMA',
        'corpo' => function (Entrada $e): array {
            $corpo = [
                'year' => $e->inteiro('ano', 1900, 2200, 'Ano'),
                'type' => $e->opcao('tipo', TIPOS, 'Tipo de feriado'),
            ];

            // Feriado estadual precisa saber de qual estado.
            if ($corpo['type'] === 'estadual') {
                $corpo['state'] = $e->texto('uf', 2, 'UF');
            }

            return $corpo;
        },
    ],
]);
