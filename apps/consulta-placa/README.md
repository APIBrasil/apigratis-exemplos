# Consulta de placa

Digite a placa, veja os dados do veículo e o valor FIPE.

![](https://i.imgur.com/BEITa4B.png)

## Rodando

```bash
cd ..                      # a partir de apps/
APIBRASIL_BEARER_TOKEN=... APIBRASIL_DEVICE_TOKEN_VEICULOS=... php -S localhost:8000
```

Abra <http://localhost:8000/consulta-placa/>.

Por padrão roda em **homologação** (dados fictícios, sem debitar). Para valer,
some `APIBRASIL_HOMOLOG=0`.

## Arquivos

| Arquivo | O que é |
| --- | --- |
| [index.html](./index.html) | a tela — não conhece nenhuma credencial |
| [backend.php](./backend.php) | o proxy: valida a placa, adiciona o token, repassa |

## Duas rotas, duas cobranças

O mesmo dado veicular está disponível de duas formas, e a diferença é como
você paga:

| Rota | Autenticação | Cobrança |
| --- | --- | --- |
| `POST /vehicles/dados` | Bearer + **DeviceToken** | por device/plano |
| `POST /consulta/veiculos/credits` | Bearer | debita saldo por consulta |

Este app usa a **primeira** (device-based) — é a de plano. Se você não tem
device de veículos, troque a allowlist do `backend.php` para a rota de crédito;
o front não muda.

## Formato da placa

O gateway aceita os dois padrões brasileiros:

- antigo: `ABC1234`
- Mercosul: `ABC1D23`

O backend normaliza (remove hífen e espaço, sobe para maiúsculas) antes de
enviar. Placa com formato inválido é rejeitada **antes** de virar uma chamada
cobrada.
