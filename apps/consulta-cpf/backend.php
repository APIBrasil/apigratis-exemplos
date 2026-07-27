<?php

/**
 * Consulta CPF — backend.
 *
 * Rota por crédito: só o Authorization, sem DeviceToken.
 *
 * A consulta de CPF exige cadastro prévio na plataforma e, para alguns tipos,
 * conta PJ. Sem isso o gateway responde 403 — não é erro de código.
 */

declare(strict_types=1);

require_once __DIR__ . '/../_comum/apibrasil.php';

use ApiBrasil\Comum\Entrada;
use ApiBrasil\Comum\Proxy;

/**
 * O `tipo` escolhe o produto — e o preço. Um endpoint, vários birôs.
 * null = dados cadastrais básicos (sem campo `tipo`).
 */
const TIPOS = [
    'cadastro' => null,
    'serasa-score' => 'serasa-score-pf',
    'serasa-premium' => 'serasa-premium-pf',
    'spc-serasa' => 'spc-serasa',
    'cred-plus' => 'cred-plus-cpf',
];

Proxy::despachar([
    'consultar' => [
        'caminho' => '/consulta/cpf/credits',
        'corpo' => function (Entrada $e): array {
            $tipo = $e->opcao('tipo', TIPOS, 'Tipo de consulta');

            return Proxy::comHomolog(array_filter([
                'cpf' => $e->digitos('cpf', 11, 'CPF'),
                'tipo' => $tipo,
                // Data de nascimento é exigida por alguns birôs.
                'datanascimento' => $e->texto('nascimento', 10, 'data de nascimento', false) ?: null,
            ], fn ($valor) => $valor !== null && $valor !== ''));
        },
    ],
]);
