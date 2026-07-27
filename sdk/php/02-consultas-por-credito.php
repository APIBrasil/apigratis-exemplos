<?php

/**
 * 02 — Consultas por crédito
 *
 * Rotas /consulta/{servico}/credits. Só precisam do bearer: debitam o saldo da
 * conta e ignoram o DeviceToken.
 *
 * Roda em HOMOLOGAÇÃO por padrão (dados fictícios, sem cobrança).
 * Para valer, rode com COBRAR=1.
 *
 *   php 02-consultas-por-credito.php
 *   COBRAR=1 php 02-consultas-por-credito.php
 */

declare(strict_types=1);

require_once __DIR__ . '/env.php';

use ApiBrasil\ApiBrasil;
use ApiBrasil\Core\Errors\InsufficientBalanceError;
use ApiBrasil\Core\Errors\ValidationError;

exigir('APIBRASIL_BEARER_TOKEN');

$api = new ApiBrasil();

// `homolog: true` é o sandbox da plataforma — não existe URL separada de teste.
$homolog = env('COBRAR') !== '1';
echo $homolog
    ? '· modo homologação (sem cobrança)' . PHP_EOL . PHP_EOL
    : '· CONSULTAS REAIS — vai debitar saldo' . PHP_EOL . PHP_EOL;

/** Toda consulta devolve o mesmo envelope: error, message, balance, valor_consulta, data. */
function resumir(string $rotulo, array $resposta): void
{
    printf("%s:\n", $rotulo);
    printf(
        "  custou: %s | saldo restante: %s\n",
        $resposta['valor_consulta'] ?? '—',
        $resposta['balance'] ?? '—'
    );
    printf("  data: %s\n", substr((string) json_encode($resposta['data'] ?? null), 0, 300));
}

try {
    // CNPJ — cadastro básico.
    resumir('CNPJ', $api->consulta->cnpj(['cnpj' => '00000000000000', 'homolog' => $homolog]));

    // O campo `tipo` é o que escolhe o PRODUTO dentro do serviço. Mesmo endpoint,
    // preço e retorno diferentes. São 210+ tipos no catálogo.
    resumir('CNPJ · lista-socios', $api->consulta->cnpj([
        'cnpj' => '00000000000000',
        'tipo' => 'lista-socios',
        'homolog' => $homolog,
    ]));

    // CPF.
    resumir('CPF', $api->consulta->cpf(['cpf' => '00000000000', 'homolog' => $homolog]));

    // Veicular por placa.
    resumir('Veículos', $api->consulta->veiculos(['placa' => 'ABC1234', 'homolog' => $homolog]));

    // Qualquer serviço do catálogo, inclusive os sem método dedicado.
    resumir('Serasa Score PF', $api->consulta->generic('cpf', [
        'cpf' => '00000000000',
        'tipo' => 'serasa-score-pf',
        'homolog' => $homolog,
    ]));

    // Descobrindo o que existe: catálogo vivo do gateway.
    $catalogo = $api->catalog->apis('consulta');
    $apis = $catalogo['apis'] ?? [];

    printf("\n%d API(s) com \"consulta\" no nome. Primeiras:\n", count($apis));
    foreach (array_slice($apis, 0, 5) as $item) {
        printf("  %s · R$ %s\n", $item['name'] ?? '—', $item['price'] ?? '—');
    }
} catch (InsufficientBalanceError $e) {
    // 402 — a mensagem do gateway já traz o valor exato da consulta.
    fwrite(STDERR, 'Sem saldo: ' . $e->getMessage() . PHP_EOL);
    exit(1);
} catch (ValidationError $e) {
    // 422 — o template do body está em GET /api/v2/endpoint/body.
    fwrite(STDERR, 'Body inválido: ' . $e->getMessage() . PHP_EOL);
    fwrite(STDERR, json_encode($e->getResponse()) . PHP_EOL);
    exit(1);
}
