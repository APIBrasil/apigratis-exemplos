// 05 — Erros, retry e observabilidade
//
// A parte que separa um script de uma integração de produção.
//
//     dart run bin/05_erros_e_retry.dart

import 'dart:io';

import 'package:apigratis_sdk_flutter/apigratis_sdk_flutter.dart';

/// Repete só o que é seguro repetir: falha de servidor e de rede.
/// Timeout fica de fora — pode indicar trabalho já concluído no servidor.
Future<T> comRetrySeguro<T>(Future<T> Function() chamada, {int tentativas = 3}) async {
  for (var i = 1;; i++) {
    try {
      return await chamada();
    } on TimeoutError {
      // TimeoutError estende NetworkError — capture antes dele.
      rethrow;
    } on ApiBrasilError catch (e) {
      final podeRepetir = e is ServerError || e is NetworkError;
      if (!podeRepetir || i >= tentativas) rethrow;

      await Future<void>.delayed(Duration(milliseconds: 250 * (1 << i)));
    }
  }
}

Future<void> main() async {
  if (Platform.environment['APIBRASIL_BEARER_TOKEN'] == null) {
    stderr.writeln('Defina APIBRASIL_BEARER_TOKEN no ambiente.');
    exit(1);
  }

  // ---------------------------------------------------------------------------
  // Retry
  // ---------------------------------------------------------------------------
  // O padrão são 2 tentativas extras, backoff exponencial com jitter, SÓ em 429
  // e falha de conexão — e respeitando o Retry-After da resposta.
  //
  // Timeout e erro de negócio nunca são repetidos: um sendText que deu timeout
  // pode ter sido entregue, e uma consulta repetida cobra duas vezes.
  final api = ApiBrasil(
    timeout: const Duration(seconds: 30),
    retry: const RetryConfig(
      retries: 3,
      minDelay: Duration(milliseconds: 500),
      retryOnStatuses: [429, 503],
    ),
    // Hooks: é aqui que você pluga log estruturado, métricas ou tracing.
    hooks: ApiBrasilHooks(
      onRequest: (i) => print('→ ${i.method} ${i.url} (tentativa ${i.attempt})'),
      onResponse: (i) => print('← ${i.status} em ${i.duration.inMilliseconds}ms'),
      onRetry: (i) => stderr.writeln('↻ retry em ${i.delay.inMilliseconds}ms: ${i.reason}'),
    ),
  );

  // Para desligar: retry: RetryConfig.disabled.

  try {
    // -------------------------------------------------------------------------
    // Erros
    // -------------------------------------------------------------------------
    // Cada status HTTP do gateway vira uma classe. Todas estendem ApiBrasilError
    // e carregam .status, .code, .message e .response (o corpo original).
    try {
      await api.consulta.cpf({'cpf': '00000000000'});
    } on ValidationError catch (e) {
      // 400/422 — o body está errado. O template certo vem de
      // GET /api/v2/endpoint/body, e a doc está em doc.apibrasil.io.
      stderr.writeln('Payload inválido: ${e.message} — ${e.response}');
    } on AuthenticationError {
      // 401 — bearer ausente/expirado. Refaça o login; não faça retry cego.
      stderr.writeln('Refaça o login.');
    } on InsufficientBalanceError catch (e) {
      // 402 — a mensagem já traz o valor exato da consulta que faltou.
      stderr.writeln('Recarregue: ${e.message}');
    } on PermissionError catch (e) {
      // 403 — DeviceToken de outra API, IP fora da whitelist, ou API que exige
      // cadastro PJ. Três causas, um só status: leia a mensagem.
      stderr.writeln('Sem permissão: ${e.message}');
    } on NotFoundError catch (e) {
      // 404 = não achou o dado. 410 = rota desativada, e a mensagem aponta a nova.
      stderr.writeln('${e.status == 410 ? 'Rota descontinuada' : 'Sem dados'}: ${e.message}');
    } on RateLimitError catch (e) {
      // 429 — a SDK já tentou de novo antes de chegar aqui.
      stderr.writeln('Limite atingido. Aguarde ${e.retryAfter?.inMilliseconds}ms.');
    } on ServerError catch (e) {
      // 5xx — gateway ou provedor upstream. Repetir com backoff faz sentido.
      stderr.writeln('Falha do servidor: ${e.status} ${e.message}');
    } on TimeoutError {
      // Estourou o tempo. ATENÇÃO: a operação pode ter completado no servidor.
      // Em envios e consultas, confirme o estado antes de repetir.
      stderr.writeln('Timeout — verifique o estado antes de tentar de novo.');
    } on NetworkError catch (e) {
      // Não chegou a haver resposta: DNS, TLS, conexão recusada.
      stderr.writeln('Falha de rede: ${e.message}');
    } on ApiBrasilError catch (e) {
      stderr.writeln('Erro da SDK (HTTP ${e.status}, código ${e.code}): ${e.message}');
    }

    // -------------------------------------------------------------------------
    // Idempotência na prática
    // -------------------------------------------------------------------------
    try {
      print('\nSaldo: ${await comRetrySeguro(api.account.balance)}');
    } on ApiBrasilError catch (e) {
      stderr.writeln('Desisti: ${e.message}');
    }
  } finally {
    api.close();
  }
}
