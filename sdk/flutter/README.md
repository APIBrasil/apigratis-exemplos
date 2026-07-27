# Exemplos — SDK Flutter/Dart

SDK: [`apigratis_sdk_flutter`](https://pub.dev/packages/apigratis_sdk_flutter) ·
Repositório: <https://github.com/APIBrasil/apigratis-sdk-flutter>

Dart >= 3.5 (Flutter 3.19+ e Dart standalone). Toda resposta volta como
`Map<String, dynamic>` já decodificado.

## Rodando

```bash
dart pub get
cp ../../.env-example ../../.env    # e preencha

# Credenciais vêm do ambiente:
set -a && . ../../.env && set +a
dart run bin/01_conta_e_saldo.dart
```

| Arquivo | O que mostra |
| --- | --- |
| [bin/01_conta_e_saldo.dart](./bin/01_conta_e_saldo.dart) | cliente a partir do ambiente, status do gateway, saldo, plano |
| [bin/02_consultas_por_credito.dart](./bin/02_consultas_por_credito.dart) | CNPJ/CPF/veículos, campo `tipo`, homologação, envelope de cobrança |
| [bin/03_whatsapp.dart](./bin/03_whatsapp.dart) | device, sessão, QR Code, envio de texto e mídia, fila |
| [bin/04_servicos_device.dart](./bin/04_servicos_device.dart) | CEP, correios, placa, FIPE, clima, SMS |
| [bin/05_erros_e_retry.dart](./bin/05_erros_e_retry.dart) | erros tipados, política de retry, hooks |

## Em app Flutter

Num app, variáveis de ambiente não existem em runtime — passe por `--dart-define`:

```bash
flutter run \
  --dart-define=APIBRASIL_BEARER_TOKEN=... \
  --dart-define=APIBRASIL_DEVICE_TOKEN=...
```

**Nunca embuta o bearer no binário do app.** Um APK/IPA é distribuído e pode ser
descompilado — a credencial vaza junto. O padrão correto num app de usuário final
é o seu backend guardar o token e o app falar com o seu backend:

```
app Flutter  →  seu backend (guarda o bearer)  →  gateway APIBrasil
```

Use a SDK direto do app só em ferramenta interna, painel administrativo ou
protótipo — onde quem roda já é dono da credencial. Para o padrão com proxy, veja
[apps/](../../apps/).

## Exibindo o QR Code do WhatsApp

O `qrcode` vem como data URI base64 — direto para um `Image.memory`:

```dart
final qr = await api.whatsapp.qrcode();
final dataUri = qr['response']['qrcode'] as String;
final bytes = base64Decode(dataUri.split(',').last);

// no widget:
Image.memory(bytes);
```

## Fechando o cliente

`api.close()` libera o transporte. Em app, mantenha um cliente para o ciclo de
vida do app e feche no `dispose` do provider/bloc que o guarda.
