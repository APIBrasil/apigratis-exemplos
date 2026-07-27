<?php

/**
 * Tabela FIPE — backend.
 *
 * Serviço device-based: /fipe/{action}.
 *
 * ATENÇÃO ao case das actions: são PascalCase (`ConsultarMarcas`), não
 * camelCase. O gateway repassa a action verbatim para o provedor, então
 * `consultarMarcas` dá 404 lá em cima.
 */

declare(strict_types=1);

require_once __DIR__ . '/../_comum/apibrasil.php';

use ApiBrasil\Comum\Entrada;
use ApiBrasil\Comum\Proxy;

/**
 * 1 = carro, 2 = moto, 3 = caminhão.
 *
 * Strings, não inteiros: o valor chega do JSON como string e `opcao()` compara
 * com `in_array(..., strict: true)`.
 */
const TIPOS_VEICULO = ['1', '2', '3'];

/** Opções comuns a todas as ações deste app. */
$fipe = fn (string $action, ?callable $corpo = null): array => array_filter([
    'caminho' => "/fipe/{$action}",
    'device' => true,
    'deviceEnv' => 'VEICULOS',
    'corpo' => $corpo,
]);

Proxy::despachar([
    // 1. Qual mês/ano da tabela consultar. Sem body.
    'referencias' => $fipe('ConsultarTabelaDeReferencia'),

    // 2. Marcas daquela referência, para o tipo de veículo.
    'marcas' => $fipe('ConsultarMarcas', fn (Entrada $e): array => [
        'codigoTabelaReferencia' => $e->inteiro('referencia', 1, 99999, 'Referência'),
        'codigoTipoVeiculo' => $e->opcao('tipo', TIPOS_VEICULO, 'Tipo de veículo'),
    ]),

    // 3. Modelos da marca.
    'modelos' => $fipe('ConsultarModelos', fn (Entrada $e): array => [
        'codigoTabelaReferencia' => $e->inteiro('referencia', 1, 99999, 'Referência'),
        'codigoTipoVeiculo' => $e->opcao('tipo', TIPOS_VEICULO, 'Tipo de veículo'),
        'codigoMarca' => $e->inteiro('marca', 1, 999999, 'Marca'),
    ]),

    // 4. Anos disponíveis daquele modelo.
    'anos' => $fipe('ConsultarAnoModelo', fn (Entrada $e): array => [
        'codigoTabelaReferencia' => $e->inteiro('referencia', 1, 99999, 'Referência'),
        'codigoTipoVeiculo' => $e->opcao('tipo', TIPOS_VEICULO, 'Tipo de veículo'),
        'codigoMarca' => $e->inteiro('marca', 1, 999999, 'Marca'),
        'codigoModelo' => $e->inteiro('modelo', 1, 9999999, 'Modelo'),
    ]),

    // 5. O preço. `codigoTipoCombustivel` e `anoModelo` vêm partidos do
    //    `codigoAnoModelo` devolvido no passo anterior (ex: "2015-1").
    'valor' => $fipe('ConsultarValorComTodosParametros', fn (Entrada $e): array => [
        'codigoTabelaReferencia' => $e->inteiro('referencia', 1, 99999, 'Referência'),
        'codigoTipoVeiculo' => $e->opcao('tipo', TIPOS_VEICULO, 'Tipo de veículo'),
        'codigoMarca' => $e->inteiro('marca', 1, 999999, 'Marca'),
        'codigoModelo' => $e->inteiro('modelo', 1, 9999999, 'Modelo'),
        'anoModelo' => $e->inteiro('ano', 1900, 2100, 'Ano do modelo'),
        'codigoTipoCombustivel' => $e->inteiro('combustivel', 1, 9, 'Tipo de combustível'),
        'tipoConsulta' => 'tradicional',
    ]),
]);
