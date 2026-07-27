<?php

/**
 * Consulta CNPJ — backend.
 *
 * Rota por crédito: só o Authorization, sem DeviceToken.
 */

declare(strict_types=1);

require_once __DIR__ . '/../_comum/apibrasil.php';

use ApiBrasil\Comum\Entrada;
use ApiBrasil\Comum\Proxy;

/**
 * O campo `tipo` escolhe o PRODUTO dentro do serviço — e o preço. Sem esta
 * allowlist, o visitante escolheria qualquer produto pago da sua conta.
 *
 * null = cadastro básico (sem campo `tipo` no body).
 */
const TIPOS = [
    'cadastro' => null,
    'socios' => 'lista-socios',
];

Proxy::despachar([
    'consultar' => [
        'caminho' => '/consulta/cnpj/credits',
        'corpo' => function (Entrada $e): array {
            $tipo = $e->opcao('tipo', TIPOS, 'Tipo de consulta');

            return Proxy::comHomolog(array_filter([
                'cnpj' => $e->digitos('cnpj', 14, 'CNPJ'),
                'tipo' => $tipo,
            ], fn ($valor) => $valor !== null));
        },
    ],
]);
