<?php

/**
 * Distância entre CEPs — backend.
 *
 * Duas rotas para a mesma conta:
 *   /cep/distancia/calcular          device-based (serviço /cep)
 *   /cep/distancia/calcular          por crédito  (rota dedicada em credits.php)
 *
 * O caminho é o mesmo; o que muda é a presença do DeviceToken. Sem device, o
 * gateway resolve pela rota de crédito e debita saldo.
 */

declare(strict_types=1);

require_once __DIR__ . '/../_comum/apibrasil.php';

use ApiBrasil\Comum\Entrada;
use ApiBrasil\Comum\Proxy;

/** Os dois CEPs, validados antes de virar chamada cobrada. */
$ceps = fn (Entrada $e): array => [
    'cep_origem' => $e->digitos('origem', 8, 'CEP de origem'),
    'cep_destino' => $e->digitos('destino', 8, 'CEP de destino'),
];

Proxy::despachar([
    'device' => [
        'caminho' => '/cep/distancia/calcular',
        'device' => true,
        'deviceEnv' => 'CEP',
        'corpo' => $ceps,
    ],
    'credito' => [
        'caminho' => '/cep/distancia/calcular',
        'corpo' => fn (Entrada $e): array => Proxy::comHomolog($ceps($e)),
    ],

    // Endereço de cada ponta, para mostrar de onde para onde.
    'endereco' => [
        'caminho' => '/cep/cep',
        'device' => true,
        'deviceEnv' => 'CEP',
        'corpo' => fn (Entrada $e): array => ['cep' => $e->digitos('cep', 8, 'CEP')],
    ],
]);
