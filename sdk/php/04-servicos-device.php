<?php

/**
 * 04 — Serviços device-based (fora do WhatsApp)
 *
 * Todos seguem o mesmo formato: POST /{servico}/{action} com Bearer + DeviceToken.
 * O device precisa ser da API correspondente — um DeviceToken de WhatsApp dá 403
 * em /vehicles.
 *
 *   php 04-servicos-device.php
 */

declare(strict_types=1);

require_once __DIR__ . '/env.php';

use ApiBrasil\ApiBrasil;
use ApiBrasil\Core\Errors\ApiBrasilError;
use ApiBrasil\Core\Errors\NotFoundError;

exigir('APIBRASIL_BEARER_TOKEN');

$api = new ApiBrasil();

/**
 * Cada API tem o seu device. Rode com o token certo por serviço, ou passe
 * `['deviceToken' => ...]` nas opções da chamada — que é o que fazemos aqui.
 */
$devices = [
    'cep' => env('APIBRASIL_DEVICE_TOKEN_CEP', env('APIBRASIL_DEVICE_TOKEN')),
    'correios' => env('APIBRASIL_DEVICE_TOKEN_CORREIOS', env('APIBRASIL_DEVICE_TOKEN')),
    'veiculos' => env('APIBRASIL_DEVICE_TOKEN_VEICULOS', env('APIBRASIL_DEVICE_TOKEN')),
    'clima' => env('APIBRASIL_DEVICE_TOKEN_CLIMA', env('APIBRASIL_DEVICE_TOKEN')),
    'sms' => env('APIBRASIL_DEVICE_TOKEN_SMS', env('APIBRASIL_DEVICE_TOKEN')),
];

/** Roda um bloco e reporta a falha sem derrubar os outros exemplos. */
function tentar(string $rotulo, callable $fn): void
{
    try {
        $resposta = $fn();
        printf("\n%s:\n%s\n", $rotulo, substr(
            (string) json_encode($resposta['response'] ?? $resposta, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE),
            0,
            600
        ));
    } catch (NotFoundError $e) {
        printf("\n%s: sem dados (HTTP %s)\n", $rotulo, $e->getStatus() ?? '—');
    } catch (ApiBrasilError $e) {
        printf("\n%s: %s (HTTP %s)\n", $rotulo, $e->getMessage(), $e->getStatus() ?? '—');
    }
}

// CEP — endereço completo com geolocalização.
tentar('CEP', fn () => $api->cep->cep(['cep' => '01001000'], ['deviceToken' => $devices['cep']]));

// Ainda em /cep: cidades por DDD, bairros, cidades, estados, distância.
tentar('Cidades por DDD', fn () => $api->cep->request('cidadesPorDDD', ['ddd' => '11'], ['deviceToken' => $devices['cep']]));

// Correios — rastreio de encomenda.
tentar('Rastreio', fn () => $api->correios->rastreio(['code' => 'AA123456789BR'], ['deviceToken' => $devices['correios']]));

// Veículos por placa. Diferente de consulta->veiculos (créditos): aqui é device.
tentar('Placa · dados', fn () => $api->vehicles->dados(['placa' => 'ABC1234'], ['deviceToken' => $devices['veiculos']]));
tentar('Placa · FIPE', fn () => $api->vehicles->fipe(['placa' => 'ABC1234'], ['deviceToken' => $devices['veiculos']]));

// Tabela FIPE navegável: referência → marcas → modelos → ano → valor.
tentar('FIPE · marcas', fn () => $api->fipe->request(
    'ConsultarMarcas',
    ['codigoTabelaReferencia' => 300, 'codigoTipoVeiculo' => 1],
    ['deviceToken' => $devices['veiculos']]
));

// Clima por cidade ou por coordenadas.
tentar('Clima', fn () => $api->weather->request('city', ['city' => 'São Paulo'], ['deviceToken' => $devices['clima']]));

// Feriados do ano (nacionais, estaduais, facultativos — o `type` decide).
tentar('Feriados', fn () => $api->holidays->request(
    'feriados',
    ['year' => (int) date('Y')],
    ['deviceToken' => $devices['clima']]
));

// GeoIP.
tentar('GeoIP', fn () => $api->databaseIp->ip(['ip' => '8.8.8.8'], ['deviceToken' => $devices['cep']]));

// SMS — device-based. Só envia de verdade com NUMERO definido.
if (($numero = env('NUMERO')) !== null) {
    tentar('SMS', fn () => $api->sms->send(
        ['number' => $numero, 'message' => 'Seu código: 123456'],
        ['deviceToken' => $devices['sms']]
    ));

    // Alternativa sem device, debitando créditos da conta:
    // $api->sms->sendWithCredits(['number' => $numero, 'message' => 'Olá!']);
}

// Serviço sem método dedicado? A saída genérica cobre o gateway inteiro.
// $api->request('POST', '/translate/text', ['text' => 'Olá', 'to' => 'en']);
