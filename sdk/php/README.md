# Exemplos — SDK PHP

SDK: [`jhowbhz/apigratis-sdk-php`](https://packagist.org/packages/jhowbhz/apigratis-sdk-php) ·
Repositório: <https://github.com/APIBrasil/apigratis-sdk-php>

PHP >= 8.0. Usa Guzzle quando disponível e cai para cURL automaticamente.
Toda resposta volta como **array associativo** já decodificado.

## Rodando

```bash
composer install
cp ../../.env-example ../../.env    # e preencha
php 01-conta-e-saldo.php
```

Os exemplos carregam o `.env` da raiz do repositório com um parser mínimo
([env.php](./env.php)) — sem depender de `vlucas/phpdotenv`. Em produção, use as
variáveis de ambiente reais do servidor (ou o `.env` do seu framework).

| Arquivo | O que mostra |
| --- | --- |
| [01-conta-e-saldo.php](./01-conta-e-saldo.php) | cliente a partir do ambiente, status do gateway, saldo, plano |
| [02-consultas-por-credito.php](./02-consultas-por-credito.php) | CNPJ/CPF/veículos, campo `tipo`, homologação, envelope de cobrança |
| [03-whatsapp.php](./03-whatsapp.php) | device, sessão, QR Code, envio de texto e mídia, fila |
| [04-servicos-device.php](./04-servicos-device.php) | CEP, correios, placa, FIPE, clima, SMS |
| [05-erros-e-retry.php](./05-erros-e-retry.php) | erros tipados, política de retry, hooks |

## Laravel

Registre o cliente como singleton e injete onde precisar:

```php
// AppServiceProvider::register()
$this->app->singleton(ApiBrasil::class, fn () => new ApiBrasil([
    'bearerToken' => config('services.apibrasil.bearer'),
    'deviceToken' => config('services.apibrasil.device'),
]));
```

```php
public function enviar(ApiBrasil $api, Request $request)
{
    $api->whatsapp->sendText([
        'number' => $request->input('numero'),
        'text'   => $request->input('texto'),
    ]);
}
```

Para disparos em volume, prefira a fila do gateway (`$api->whatsapp->queue(...)`)
ou uma Job do Laravel — não segure a request HTTP do seu usuário.
