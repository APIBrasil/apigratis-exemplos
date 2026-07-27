// 03 — WhatsApp
//
// Serviço device-based: exige Authorization: Bearer + header DeviceToken.
// O DeviceToken identifica UMA sessão de WhatsApp; o bearer identifica a conta.
//
// Fluxo completo: device → sessão → QR Code → pareamento → envio.
//
//     dart run bin/03_whatsapp.dart
//     CRIAR_DEVICE=1 dart run bin/03_whatsapp.dart
//     NUMERO=5511999999999 dart run bin/03_whatsapp.dart

import 'dart:convert';
import 'dart:io';

import 'package:apigratis_sdk_flutter/apigratis_sdk_flutter.dart';

Future<void> main() async {
  final env = Platform.environment;

  if (env['APIBRASIL_BEARER_TOKEN'] == null) {
    stderr.writeln('Defina APIBRASIL_BEARER_TOKEN no ambiente.');
    exit(1);
  }

  final api = ApiBrasil();
  var temDevice = env['APIBRASIL_DEVICE_TOKEN'] != null;

  try {
    // -----------------------------------------------------------------------
    // 1. O device
    // -----------------------------------------------------------------------
    // A SecretKey (painel → API WhatsApp → SecretKey) é a única credencial que
    // cria devices. Depois de criado, o device_token substitui ela no dia a dia.
    if (env['CRIAR_DEVICE'] == '1') {
      final secretKey = env['APIBRASIL_SECRET_KEY'];
      if (secretKey == null) {
        stderr.writeln('CRIAR_DEVICE=1 exige APIBRASIL_SECRET_KEY.');
        exit(1);
      }

      // A rota canônica de criação é POST /devices/store, com a SecretKey no
      // header. `api.http` é a saída genérica para qualquer rota do gateway,
      // já com os headers de autenticação.
      final criado = await api.http.post(
        'devices/store',
        {'device_name': 'exemplo-dart', 'type': 'server'},
        RequestOptions(secretKey: secretKey),
      );

      final token = (criado['device'] as Map<String, dynamic>?)?['device_token'];
      print('Device criado. Guarde este token no seu ambiente:');
      print('APIBRASIL_DEVICE_TOKEN=$token\n');

      api.setDeviceToken(token as String);
      temDevice = true;
    }

    if (!temDevice) {
      stderr.writeln('Defina APIBRASIL_DEVICE_TOKEN, ou rode com CRIAR_DEVICE=1.');
      exit(1);
    }

    // -----------------------------------------------------------------------
    // 2. A sessão
    // -----------------------------------------------------------------------
    // Os webhooks são opcionais, mas é aqui que se registram — não existe outra
    // chamada para isso. Sem eles você só descobre mensagens recebidas por polling.
    final webhooks = <String, dynamic>{
      if (env['WEBHOOK_MENSAGENS'] != null) 'webhook_wh_message': env['WEBHOOK_MENSAGENS'],
      if (env['WEBHOOK_STATUS'] != null) 'webhook_wh_status': env['WEBHOOK_STATUS'],
      if (env['WEBHOOK_CONEXAO'] != null) 'webhook_wh_connect': env['WEBHOOK_CONEXAO'],
      if (env['WEBHOOK_QRCODE'] != null) 'webhook_wh_qrcode': env['WEBHOOK_QRCODE'],
    };

    try {
      final sessao = await api.whatsapp.start(webhooks);
      print('Sessão: ${sessao['message'] ?? sessao}');
    } on PermissionError catch (e) {
      // 403 aqui é quase sempre DeviceToken de outra API, ou IP fora da whitelist.
      stderr.writeln('Sem permissão para esse device: ${e.message}');
      exit(1);
    }

    // -----------------------------------------------------------------------
    // 3. O QR Code
    // -----------------------------------------------------------------------
    // Vem como data URI base64. Num app Flutter isso vira um Image.memory;
    // aqui gravamos em disco para escanear.
    final qr = await api.whatsapp.qrcode();
    final resposta = qr['response'];
    final dataUri = resposta is Map<String, dynamic> ? resposta['qrcode'] as String? : null;

    if (dataUri != null && dataUri.startsWith('data:image')) {
      await File('qrcode.png').writeAsBytes(base64Decode(dataUri.split(',').last));
      print('QR Code salvo em qrcode.png — escaneie no WhatsApp → aparelhos conectados.');
    } else {
      print('QR Code: ${resposta ?? qr['message'] ?? 'sessão provavelmente já conectada'}');
    }

    // -----------------------------------------------------------------------
    // 4. Envios
    // -----------------------------------------------------------------------
    final numero = env['NUMERO'];
    if (numero == null) {
      print('\nDefina NUMERO=5511999999999 para enviar de verdade.');
      return;
    }

    // Texto. time_typing simula "digitando..." antes de entregar.
    final texto = await api.whatsapp.sendText({
      'number': numero,
      'text': 'Olá! Mensagem enviada pela SDK Dart da APIBrasil 👋',
      'time_typing': 1500,
    });
    print('Texto: ${texto['message'] ?? texto}');

    // Arquivo por URL pública. Para base64, use sendFile64.
    await api.whatsapp.sendFile({
      'number': numero,
      'path': 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
      'caption': 'Segue o documento',
    });

    // Áudio (o gateway converte para mp3; máx. 6 min) e localização.
    await api.whatsapp.sendAudio({
      'number': numero,
      'path': 'https://filesamples.com/samples/audio/mp3/sample3.mp3',
    });
    await api.whatsapp.sendLocation({'number': numero, 'lat': -23.5613, 'lng': -46.6565});

    // Qualquer action da documentação, mesmo sem método dedicado na SDK.
    await api.whatsapp.request('sendLink', {
      'number': numero,
      'url': 'https://apibrasil.com.br',
      'text': 'Conheça',
    });

    // Fila: mesma action, processada de forma assíncrona pelo gateway. É o
    // caminho certo para disparos em volume — devolve na hora e não segura a
    // sua requisição.
    final enfileirado = await api.whatsapp.queue('sendText', {
      'number': numero,
      'text': 'Esta foi pela fila 🚀',
    });
    print('Fila: ${enfileirado['message'] ?? enfileirado}');

    // -----------------------------------------------------------------------
    // 5. Vários devices no mesmo processo
    // -----------------------------------------------------------------------
    // withDevice devolve um cliente novo, sem alterar o original.
    final suporteToken = env['APIBRASIL_DEVICE_TOKEN_SUPORTE'];
    if (suporteToken != null) {
      final suporte = api.withDevice(suporteToken);
      await suporte.whatsapp.sendText({
        'number': numero,
        'text': 'Falando pela sessão do suporte',
      });
      suporte.close();
    }
  } finally {
    api.close();
  }
}
