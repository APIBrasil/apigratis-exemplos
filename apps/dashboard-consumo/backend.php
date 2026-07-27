<?php

/**
 * Dashboard de consumo — backend.
 *
 * Rotas de plataforma: leitura pura, sem DeviceToken e sem custo por consulta.
 * É o único app aqui que não gasta nada para rodar.
 */

declare(strict_types=1);

require_once __DIR__ . '/../_comum/apibrasil.php';

use ApiBrasil\Comum\Entrada;
use ApiBrasil\Comum\Proxy;

/**
 * Janelas aceitas pelos relatórios.
 *
 * Strings, não inteiros: o valor chega do JSON como string e `opcao()` compara
 * com `in_array(..., strict: true)`.
 */
const DIAS = ['7', '15', '30', '60', '90'];

Proxy::despachar([
    // ---------------------------------------------------------------------
    // Conta
    // ---------------------------------------------------------------------
    'saldo' => ['metodo' => 'GET', 'caminho' => '/balance'],
    'plano' => ['metodo' => 'GET', 'caminho' => '/plan'],
    'devices' => ['metodo' => 'GET', 'caminho' => '/devices'],

    // ---------------------------------------------------------------------
    // Relatórios
    // ---------------------------------------------------------------------
    'stats' => ['metodo' => 'GET', 'caminho' => '/dashboard/stats'],
    'rapido' => ['metodo' => 'GET', 'caminho' => '/reports/quick-stats'],
    'resumo' => ['metodo' => 'GET', 'caminho' => '/reports/summary'],

    // A janela vai na query string, não no corpo — são rotas GET.
    'diario' => [
        'metodo' => 'GET',
        'caminho' => '/reports/daily-usage',
        'query' => fn (Entrada $e): array => ['days' => $e->opcao('dias', DIAS, 'Período')],
    ],
    'erros' => [
        'metodo' => 'GET',
        'caminho' => '/reports/error-analysis',
        'query' => fn (Entrada $e): array => ['days' => $e->opcao('dias', DIAS, 'Período')],
    ],
    'por-device' => [
        'metodo' => 'GET',
        'caminho' => '/reports/device-analysis',
        'query' => fn (Entrada $e): array => ['days' => $e->opcao('dias', DIAS, 'Período')],
    ],
    'recentes' => [
        'metodo' => 'GET',
        'caminho' => '/reports/recent-requests',
        'query' => fn (Entrada $e): array => ['limit' => $e->inteiro('limite', 1, 100, 'Limite')],
    ],
]);
