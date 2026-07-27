<?php

/**
 * Rastreio de encomendas — backend.
 *
 * Duas rotas para a mesma informação, com cobranças diferentes:
 *   /correios/rastreio            device-based, cobra por plano
 *   /consulta/rastreio/credits    por crédito, debita saldo
 *
 * O app usa a primeira e cai para a segunda quando não há device — é um bom
 * exemplo de como conviver com as duas famílias.
 */

declare(strict_types=1);

require_once __DIR__ . '/../_comum/apibrasil.php';

use ApiBrasil\Comum\Entrada;
use ApiBrasil\Comum\Proxy;

/**
 * Código de rastreio dos Correios: 2 letras + 9 dígitos + 2 letras
 * (ex: AA123456789BR). Validar aqui evita gastar uma consulta com código
 * digitado errado.
 */
$codigo = function (Entrada $e): string {
    $valor = strtoupper(preg_replace('/[^A-Za-z0-9]/', '', (string) $e->cru('codigo', '')));

    if (!preg_match('/^[A-Z]{2}[0-9]{9}[A-Z]{2}$/', $valor)) {
        throw new \ApiBrasil\Comum\ErroDeEntrada(
            'Código inválido. Use o formato AA123456789BR.'
        );
    }

    return $valor;
};

Proxy::despachar([
    'device' => [
        'caminho' => '/correios/rastreio',
        'device' => true,
        'deviceEnv' => 'CORREIOS',
        'corpo' => fn (Entrada $e): array => ['code' => $codigo($e)],
    ],
    'credito' => [
        'caminho' => '/consulta/rastreio/credits',
        'corpo' => fn (Entrada $e): array => Proxy::comHomolog(['code' => $codigo($e)]),
    ],
]);
