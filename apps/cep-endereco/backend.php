<?php

/**
 * CEP e endereço — backend.
 *
 * Serviço device-based: /cep/{action}. Um DeviceToken de outra API dá 403 aqui.
 */

declare(strict_types=1);

require_once __DIR__ . '/../_comum/apibrasil.php';

use ApiBrasil\Comum\Entrada;
use ApiBrasil\Comum\Proxy;

/**
 * Lista fechada — evita mandar UF arbitrária ao gateway.
 *
 * Declarada ANTES do despachar(): ele não retorna, então nada depois dele
 * chega a executar.
 */
const UFS = [
    'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS',
    'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC',
    'SP', 'SE', 'TO',
];

Proxy::despachar([
    // Endereço completo, com geolocalização quando disponível.
    'cep' => [
        'caminho' => '/cep/cep',
        'device' => true,
        'deviceEnv' => 'CEP',
        'corpo' => fn (Entrada $e): array => ['cep' => $e->digitos('cep', 8, 'CEP')],
    ],

    // Os três abaixo alimentam os selects encadeados de UF → cidade → bairro.
    'estados' => [
        'caminho' => '/cep/estados',
        'device' => true,
        'deviceEnv' => 'CEP',
    ],
    'cidades' => [
        'caminho' => '/cep/cidades',
        'device' => true,
        'deviceEnv' => 'CEP',
        'corpo' => fn (Entrada $e): array => ['uf' => $e->opcao('uf', UFS, 'UF')],
    ],
    'bairros' => [
        'caminho' => '/cep/bairros',
        'device' => true,
        'deviceEnv' => 'CEP',
        'corpo' => fn (Entrada $e): array => [
            'uf' => $e->opcao('uf', UFS, 'UF'),
            'cidade' => $e->texto('cidade', 120, 'cidade'),
        ],
    ],

    // Cidades atendidas por um DDD.
    'ddd' => [
        'caminho' => '/cep/cidadesPorDDD',
        'device' => true,
        'deviceEnv' => 'CEP',
        'corpo' => fn (Entrada $e): array => ['ddd' => $e->digitos('ddd', 2, 'DDD')],
    ],
]);
