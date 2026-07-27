<?php

/**
 * Envio de SMS — backend.
 *
 * Duas rotas, duas cobranças:
 *   /sms/send            device-based, cobra por plano
 *   /sms/send/credits    debita saldo, sem device
 *
 * SMS custa e não tem desfazer. Este backend valida número, texto e operadora,
 * e envia para UM destinatário por requisição — a lista é percorrida pelo front,
 * o que dá controle de ritmo e relatório por destinatário.
 */

declare(strict_types=1);

require_once __DIR__ . '/../_comum/apibrasil.php';

use ApiBrasil\Comum\Entrada;
use ApiBrasil\Comum\Proxy;

/** Operadoras aceitas pelo gateway. */
const OPERADORAS = ['claro', 'vivo', 'tim', 'oi'];

/**
 * Corpo do envio, igual para as duas rotas.
 *
 * 160 caracteres é o limite de um SMS single-part (GSM-7). Acima disso a
 * mensagem é fragmentada e cobrada como mais de um envio — cortar aqui evita
 * a surpresa na fatura.
 */
$envio = fn (Entrada $e): array => [
    'number' => $e->telefone(),
    'message' => $e->texto('mensagem', 160, 'mensagem'),
    'operator' => $e->opcao('operadora', OPERADORAS, 'Operadora'),
];

Proxy::despachar([
    'device' => [
        'caminho' => '/sms/send',
        'device' => true,
        'deviceEnv' => 'SMS',
        'corpo' => $envio,
    ],
    'credito' => [
        'caminho' => '/sms/send/credits',
        'corpo' => fn (Entrada $e): array => Proxy::comHomolog($envio($e)),
    ],
]);
