# Apps completos

Não são snippets: são 14 aplicações que rodam de ponta a ponta, com front-end e
backend. Todas seguem o mesmo padrão de segurança — **o token fica no servidor**.

```
navegador  →  backend.php (guarda o token)  →  gateway APIBrasil
```

## Rodando

Sirva a partir **desta pasta**, não de dentro do app — os arquivos compartilhados
em [`_comum/`](./_comum/) precisam estar no alcance do servidor:

```bash
cp ../.env-example ../.env      # e preencha
APIBRASIL_BEARER_TOKEN=... php -S localhost:8000
```

Depois abra o app que quiser:

```
http://localhost:8000/consulta-cnpj/
http://localhost:8000/fipe-tabela/
http://localhost:8000/dashboard-consumo/
```

O `php -S` é só para desenvolvimento. Em produção use Apache, Nginx + PHP-FPM, ou
o que você já tem.

Se preferir carregar tudo de uma vez:

```bash
set -a && . ../.env && set +a && php -S localhost:8000
```

## Os 14 apps

**Consultas por crédito** — só precisam do bearer; debitam saldo:

| App | O que faz |
| --- | --- |
| [consulta-cnpj/](./consulta-cnpj/) | cadastro, quadro societário, exportação CSV |
| [consulta-cpf/](./consulta-cpf/) | dados cadastrais e score de crédito (5 produtos) |
| [distancia-cep/](./distancia-cep/) | km entre dois CEPs + simulação de frete |

**Serviços device-based** — exigem `DeviceToken` da API correspondente:

| App | O que faz |
| --- | --- |
| [cep-endereco/](./cep-endereco/) | autocompletar de endereço, UF → cidade → bairro, DDD |
| [consulta-placa/](./consulta-placa/) | dados do veículo e valor FIPE pela placa |
| [fipe-tabela/](./fipe-tabela/) | cascata referência → marca → modelo → ano → preço |
| [rastreio-correios/](./rastreio-correios/) | histórico dos Correios em linha do tempo |
| [clima/](./clima/) | condições por cidade ou coordenadas |
| [feriados/](./feriados/) | calendário do ano, com contagem de emendas |
| [sms-envio/](./sms-envio/) | envio em lote com relatório por destinatário |

**WhatsApp e Evolution:**

| App | O que faz |
| --- | --- |
| [whatsapp-devices/](./whatsapp-devices/) | devices da conta, status de sessão e QR Code |
| [whatsapp-envio/](./whatsapp-envio/) | texto, arquivo, áudio, link, localização, fila |
| [evolution-crud/](./evolution-crud/) | CRUD de instâncias Evolution |

**Plataforma** — leitura pura, não gasta nada:

| App | O que faz |
| --- | --- |
| [dashboard-consumo/](./dashboard-consumo/) | saldo, plano, uso diário, erros, por device |

## Variáveis de ambiente

| Variável | Usada por |
| --- | --- |
| `APIBRASIL_BEARER_TOKEN` | **todos** |
| `APIBRASIL_DEVICE_TOKEN` | fallback de qualquer app device-based |
| `APIBRASIL_DEVICE_TOKEN_CEP` | cep-endereco, distancia-cep |
| `APIBRASIL_DEVICE_TOKEN_VEICULOS` | consulta-placa, fipe-tabela |
| `APIBRASIL_DEVICE_TOKEN_CORREIOS` | rastreio-correios |
| `APIBRASIL_DEVICE_TOKEN_CLIMA` | clima, feriados |
| `APIBRASIL_DEVICE_TOKEN_SMS` | sms-envio |
| `APIBRASIL_DEVICE_TOKEN_WHATSAPP` | whatsapp-envio |
| `APIBRASIL_SECRET_KEY` | evolution-crud (criar device) |
| `APIBRASIL_HOMOLOG=0` | desliga a homologação — **passa a cobrar** |

Os `_SUFIXO` são opcionais: sem eles, o proxy cai para `APIBRASIL_DEVICE_TOKEN`.

## A camada compartilhada

[`_comum/`](./_comum/) é o que faz 14 apps caberem em pouca linha:

| Arquivo | O que é |
| --- | --- |
| [apibrasil.php](./_comum/apibrasil.php) | o proxy: allowlist, validadores, credenciais, repasse de status |
| [app.css](./_comum/app.css) | tokens de estilo, formulários, tabelas, cartões, modal — claro e escuro |
| [app.js](./_comum/app.js) | `chamar()`, `conteudo()`, `definicoes()`, `tabela()`, `exportarCsv()`… |

Um `backend.php` inteiro fica assim:

```php
require_once __DIR__ . '/../_comum/apibrasil.php';

Proxy::despachar([
    'consultar' => [
        'caminho' => '/consulta/cnpj/credits',
        'corpo' => fn (Entrada $e) => Proxy::comHomolog([
            'cnpj' => $e->digitos('cnpj', 14, 'CNPJ'),
        ]),
    ],
]);
```

### O que o proxy garante

1. **Valida a entrada.** `digitos()`, `texto()`, `opcao()`, `placa()`,
   `telefone()`, `url()`, `decimal()`, `slug()`. Sem isso você virou um proxy
   aberto para o seu saldo: qualquer um manda qualquer payload e você paga.
2. **Restringe as rotas** por allowlist. Um proxy que aceita caminho arbitrário
   dá ao visitante a API inteira da conta — inclusive as rotas de pagamento.
3. **Monta o corpo no servidor.** Nada do cliente é repassado cru; se fosse, a
   validação não valeria nada.
4. **Repassa o status do gateway.** 402/403/422 preservados para o front decidir
   a mensagem. Trocar tudo por 500 joga a informação no lixo.
5. **Não vaza configuração.** Erro interno vira `error_log()` no servidor e
   mensagem genérica para o cliente.

## Por que backend, e não fetch direto

Chamar o gateway do navegador coloca o seu Bearer Token no DevTools de todo
visitante. Ele consome o seu saldo e acessa os dados da sua conta. Não há como
esconder um token no cliente — minificar e ofuscar não muda nada.

A comparação lado a lado está em [rest/browser/](../rest/browser/).

## Detalhes que valem levar para o seu código

**Homologação por padrão.** Todo app que cobra roda com `homolog: true` até você
definir `APIBRASIL_HOMOLOG=0`. Um exemplo que debita saldo na primeira execução é
uma pegadinha, não um exemplo.

**`allSettled`, não `all`.** Vários apps fazem chamadas paralelas em que algumas
podem falhar por falta de plano ou de device. Um app que quebra inteiro por causa
de um recurso ausente é pior que um app parcial.

**Nomes de campo variam.** Provedores por trás do gateway devolvem `logradouro`
ou `street`, `eventos` ou `events`. O helper `pegar(objeto, ...chaves)` tenta as
variantes em ordem — é o que faz o app sobreviver a uma troca de provedor.

**Case de action importa.** O gateway repassa a action verbatim ao provedor:
`ConsultarMarcas` funciona, `consultarMarcas` dá 404 lá em cima. Veja
[fipe-tabela](./fipe-tabela/).
