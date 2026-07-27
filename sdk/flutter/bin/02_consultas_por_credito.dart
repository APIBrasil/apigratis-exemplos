// 02 — Consultas por crédito
//
// Rotas /consulta/{servico}/credits. Só precisam do bearer: debitam o saldo da
// conta e ignoram o DeviceToken.
//
// Roda em HOMOLOGAÇÃO por padrão (dados fictícios, sem cobrança).
// Para valer, rode com COBRAR=1.
//
//     dart run bin/02_consultas_por_credito.dart
//     COBRAR=1 dart run bin/02_consultas_por_credito.dart

import 'dart:convert';
import 'dart:io';

import 'package:apigratis_sdk_flutter/apigratis_sdk_flutter.dart';

/// Toda consulta devolve o mesmo envelope:
/// { error, message, balance, tax, valor_consulta, data }.
void resumir(String rotulo, Map<String, dynamic> resposta) {
  print('$rotulo:');
  print('  custou: ${resposta['valor_consulta'] ?? '—'} '
      '| saldo restante: ${resposta['balance'] ?? '—'}');

  final dados = jsonEncode(resposta['data']);
  print('  data: ${dados.substring(0, dados.length < 300 ? dados.length : 300)}');
}

Future<void> main() async {
  if (Platform.environment['APIBRASIL_BEARER_TOKEN'] == null) {
    stderr.writeln('Defina APIBRASIL_BEARER_TOKEN no ambiente.');
    exit(1);
  }

  final api = ApiBrasil();

  // `homolog` é o sandbox da plataforma — não existe URL separada de teste.
  final homolog = Platform.environment['COBRAR'] != '1';
  print(homolog
      ? '· modo homologação (sem cobrança)\n'
      : '· CONSULTAS REAIS — vai debitar saldo\n');

  try {
    // CNPJ — cadastro básico.
    resumir('CNPJ', await api.consulta.cnpj({'cnpj': '00000000000000', 'homolog': homolog}));

    // O campo `tipo` é o que escolhe o PRODUTO dentro do serviço. Mesmo
    // endpoint, preço e retorno diferentes. São 210+ tipos no catálogo.
    resumir(
      'CNPJ · lista-socios',
      await api.consulta.cnpj({
        'cnpj': '00000000000000',
        'tipo': 'lista-socios',
        'homolog': homolog,
      }),
    );

    // CPF.
    resumir('CPF', await api.consulta.cpf({'cpf': '00000000000', 'homolog': homolog}));

    // Veicular por placa.
    resumir('Veículos', await api.consulta.veiculos({'placa': 'ABC1234', 'homolog': homolog}));

    // Qualquer serviço do catálogo, inclusive os sem método dedicado.
    resumir(
      'Serasa Score PF',
      await api.consulta.consulta('cpf', {
        'cpf': '00000000000',
        'tipo': 'serasa-score-pf',
        'homolog': homolog,
      }),
    );

    // Descobrindo o que existe: catálogo vivo do gateway.
    final apis = (await api.catalog.listApis())['apis'] as List? ?? const [];
    print('\n${apis.length} API(s) no catálogo. Primeiras:');
    for (final item in apis.take(5)) {
      final servico = item as Map<String, dynamic>;
      print('  ${servico['name'] ?? '—'} · R\$ ${servico['price'] ?? '—'}');
    }
  } on InsufficientBalanceError catch (e) {
    // 402 — a mensagem do gateway já traz o valor exato da consulta.
    stderr.writeln('Sem saldo: ${e.message}');
    exit(1);
  } on ValidationError catch (e) {
    // 422 — o template do body está em GET /api/v2/endpoint/body.
    stderr.writeln('Body inválido: ${e.message} — ${e.response}');
    exit(1);
  } finally {
    api.close();
  }
}
