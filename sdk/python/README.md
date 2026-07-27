# Exemplos — SDK Python

SDK: [`api-brasil`](https://pypi.org/project/api-brasil/) ·
Repositório: <https://github.com/ivanildobarauna-dev/apibrasil-py>

Python >= 3.8. Usa `requests` quando disponível e cai para a stdlib (`urllib`)
automaticamente. Toda resposta volta como **dict** já decodificado.

## Rodando

```bash
python -m venv .venv && . .venv/bin/activate    # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp ../../.env-example ../../.env                # e preencha
python 01_conta_e_saldo.py
```

Os exemplos carregam o `.env` da raiz com [`env.py`](./env.py) — sem depender de
`python-dotenv`. Em produção, exporte as variáveis no ambiente e a SDK as lê sozinha.

| Arquivo | O que mostra |
| --- | --- |
| [01_conta_e_saldo.py](./01_conta_e_saldo.py) | cliente a partir do ambiente, status do gateway, saldo, plano |
| [02_consultas_por_credito.py](./02_consultas_por_credito.py) | CNPJ/CPF/veículos, campo `tipo`, homologação, envelope de cobrança |
| [03_whatsapp.py](./03_whatsapp.py) | device, sessão, QR Code, envio de texto e mídia, fila |
| [04_servicos_device.py](./04_servicos_device.py) | CEP, correios, placa, FIPE, clima, SMS |
| [05_erros_e_retry.py](./05_erros_e_retry.py) | erros tipados, política de retry, hooks |

## Migrando da interface antiga

A `api-brasil` 2.x trouxe o cliente unificado `ApiBrasil`. A interface antiga
(`APIBrasilClient` + `WhatsAppApi`, `to_number()`, `send_message()`) continua
funcionando, mas o caminho novo é bem mais direto:

```python
# antes
api_client = APIBrasilClient(bearer_token=BEARER)
whatsapp = WhatsAppApi(api_brasil_client=api_client, device_token=DEVICE)
whatsapp.to_number("5511999999999")
response, status = whatsapp.send_message(message="Olá")

# agora
api = ApiBrasil()  # lê as credenciais do ambiente
api.whatsapp.send_text({"number": "5511999999999", "text": "Olá"})
```

O pacote `apigratis-sdk-python`, mais antigo, está **descontinuado** — use `api-brasil`.

## Async

A SDK é síncrona. Em código async, jogue as chamadas numa thread:

```python
import asyncio

resposta = await asyncio.to_thread(api.consulta.cnpj, {"cnpj": "00000000000000"})
```

Em Django/FastAPI, monte um cliente por processo (é seguro para uso concorrente)
em vez de instanciar por requisição.
