// 04 — Serviços device-based (fora do WhatsApp)
//
// Todos seguem o mesmo formato: POST /{servico}/{action} com Bearer + DeviceToken.
// O device precisa ser da API correspondente — um DeviceToken de WhatsApp dá 403
// em /vehicles.
//
//     dart run bin/04_servicos_device.dart

import 'dart:convert';
import 'dart:io';

import 'package:apigratis_sdk_flutter/apigratis_sdk_flutter.dart';

final env = Platform.environment;

/// Opções com o token específico do serviço, caindo para o token padrão.
RequestOptions deviceDe(String servico) => RequestOptions(
      deviceToken: env['APIBRASIL_DEVICE_TOKEN_$servico'] ?? env['APIBRASIL_DEVICE_TOKEN'],
    );

/// Roda um bloco e reporta a falha sem derrubar os outros exemplos.
Future<void> tentar(String rotulo, Future<Map<String, dynamic>> Function() chamada) async {
  try {
    final resposta = await chamada();
    final corpo = resposta['response'] ?? resposta;
    final texto = const JsonEncoder.withIndent('  ').convert(corpo);
    print('\n$rotulo:\n${texto.substring(0, texto.length < 600 ? texto.length : 600)}');
  } on NotFoundError catch (e) {
    print('\n$rotulo: sem dados (HTTP ${e.status})');
  } on ApiBrasilError catch (e) {
    print('\n$rotulo: ${e.message} (HTTP ${e.status})');
  }
}

Future<void> main() async {
  if (env['APIBRASIL_BEARER_TOKEN'] == null) {
    stderr.writeln('Defina APIBRASIL_BEARER_TOKEN no ambiente.');
    exit(1);
  }

  final api = ApiBrasil();

  try {
    // CEP — endereço completo com geolocalização.
    await tentar('CEP', () => api.cep.cep({'cep': '01001000'}, deviceDe('CEP')));

    // Ainda em /cep: cidades por DDD, bairros, cidades, estados, distância.
    await tentar('Cidades por DDD',
        () => api.cep.request('cidadesPorDDD', {'ddd': '11'}, deviceDe('CEP')));

    // Correios — rastreio de encomenda.
    await tentar('Rastreio',
        () => api.correios.rastreio({'code': 'AA123456789BR'}, deviceDe('CORREIOS')));

    // Veículos por placa. Diferente de consulta.veiculos (créditos): aqui é device.
    await tentar('Placa · dados',
        () => api.vehicles.dados({'placa': 'ABC1234'}, deviceDe('VEICULOS')));
    await tentar('Placa · FIPE',
        () => api.vehicles.fipe({'placa': 'ABC1234'}, deviceDe('VEICULOS')));

    // Tabela FIPE navegável: referência → marcas → modelos → ano → valor.
    await tentar(
      'FIPE · marcas',
      () => api.fipe.request(
        'ConsultarMarcas',
        {'codigoTabelaReferencia': 300, 'codigoTipoVeiculo': 1},
        deviceDe('VEICULOS'),
      ),
    );

    // Clima por cidade ou por coordenadas.
    await tentar('Clima',
        () => api.weather.request('city', {'city': 'São Paulo'}, deviceDe('CLIMA')));

    // Feriados do ano (nacionais, estaduais, facultativos — o type decide).
    await tentar(
      'Feriados',
      () => api.holidays.request('feriados', {'year': DateTime.now().year}, deviceDe('CLIMA')),
    );

    // GeoIP.
    await tentar('GeoIP', () => api.databaseIp.ip({'ip': '8.8.8.8'}, deviceDe('CEP')));

    // SMS — device-based. Só envia de verdade com NUMERO definido.
    final numero = env['NUMERO'];
    if (numero != null) {
      await tentar(
        'SMS',
        () => api.sms.send({'number': numero, 'message': 'Seu código: 123456'}, deviceDe('SMS')),
      );

      // Alternativa sem device, debitando créditos da conta:
      // await api.sms.sendWithCredits({'number': numero, 'message': 'Olá!'});
    }

    // Serviço sem método dedicado? A saída genérica cobre o gateway inteiro.
    // await api.http.post('translate/text', {'text': 'Olá', 'to': 'en'});
  } finally {
    api.close();
  }
}
