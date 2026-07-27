// 01 — Conta e saldo
//
// O básico: montar o cliente, confirmar que o gateway responde e ler os dados
// da conta. Nada aqui gasta crédito.
//
//     dart run bin/01_conta_e_saldo.dart

import 'dart:io';

import 'package:apigratis_sdk_flutter/apigratis_sdk_flutter.dart';

Future<void> main() async {
  // Sem argumentos, o cliente lê APIBRASIL_BEARER_TOKEN, APIBRASIL_DEVICE_TOKEN,
  // APIBRASIL_SECRET_KEY e APIBRASIL_BASE_URL do ambiente (ou de --dart-define).
  final api = ApiBrasil();

  try {
    // O catálogo público serve para separar "minha credencial está errada" de
    // "o gateway caiu".
    final apis = await api.catalog.listApis();
    print('Gateway respondeu: ${(apis['apis'] as List?)?.length ?? 0} API(s) no catálogo');

    if (Platform.environment['APIBRASIL_BEARER_TOKEN'] == null) {
      stderr.writeln('\nDefina APIBRASIL_BEARER_TOKEN no ambiente para seguir.');
      exit(1);
    }

    print('Saldo: ${await api.account.balance()}');
    print('Plano: ${await api.account.plan()}');

    // Devices ativos na conta — cada um é uma instância de um serviço.
    final lista = await api.devices.list();
    final devices = (lista['devices'] as List?) ?? const [];

    print('\n${devices.length} device(s):');
    for (final item in devices) {
      final device = item as Map<String, dynamic>;
      final servico = (device['api'] as Map<String, dynamic>?)?['name'] ?? '—';
      print('  ${device['device_name'] ?? '—'} · $servico · ${device['status'] ?? '—'}');
    }
  } on AuthenticationError {
    stderr.writeln('Bearer inválido ou expirado — refaça o login no painel.');
    exit(1);
  } on ApiBrasilError catch (e) {
    stderr.writeln('Falhou (HTTP ${e.status}): ${e.message}');
    exit(1);
  } finally {
    // Libera o transporte. Em app, feche no dispose de quem guarda o cliente.
    api.close();
  }

  // Login por email/senha, se você preferir não guardar o JWT:
  //
  //   final resultado = await ApiBrasil.login({'email': email, 'password': senha});
  //   final api = resultado.client;   // o token já está no cliente
  //
  // Contas com 2FA: api.auth.login() → api.auth.verify2fa().
}
