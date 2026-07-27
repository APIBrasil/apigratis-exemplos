# Exemplos — SDK C++

Repositório: <https://github.com/APIBrasil/apigratis-sdk-cpp>

C++17, portável (Linux, macOS, Windows/MSVC). HTTP via **libcurl**, JSON via
**nlohmann/json**. Toda resposta volta como `apibrasil::Json` (alias de
`nlohmann::json`).

## Requisitos

- Compilador C++17 (GCC 8+, Clang 7+, MSVC 2019+)
- CMake >= 3.16
- libcurl (dev) — `sudo apt install libcurl4-openssl-dev cmake g++`
- nlohmann/json — encontrado no sistema ou baixado via `FetchContent`

No Windows, use [vcpkg](https://vcpkg.io/): `vcpkg install curl nlohmann-json`.

## Rodando

```bash
cmake -B build
cmake --build build

# Credenciais vêm do ambiente:
set -a && . ../../.env && set +a
./build/01-conta-e-saldo          # Linux/macOS
.\build\Debug\01-conta-e-saldo    # Windows
```

| Arquivo | O que mostra |
| --- | --- |
| [01-conta-e-saldo.cpp](./01-conta-e-saldo.cpp) | cliente a partir do ambiente, status do gateway, saldo, plano |
| [02-consultas-por-credito.cpp](./02-consultas-por-credito.cpp) | CNPJ/CPF/veículos, campo `tipo`, homologação, envelope de cobrança |
| [03-whatsapp.cpp](./03-whatsapp.cpp) | device, sessão, QR Code, envio de texto e mídia, fila |
| [04-servicos-device.cpp](./04-servicos-device.cpp) | CEP, correios, placa, FIPE, clima, SMS |
| [05-erros-e-retry.cpp](./05-erros-e-retry.cpp) | exceções tipadas, política de retry, hooks |

O [CMakeLists.txt](./CMakeLists.txt) daqui busca a SDK via `FetchContent` — não
precisa instalar nada além das dependências acima.

## Particularidades do C++

**Bodies com initializer list.** `{{"number", "5511..."}, {"text", "Olá"}}`
constrói o `Json` direto, sem builder.

**Erros são exceções.** Toda resposta com status >= 400 lança uma exceção da
hierarquia `apibrasil::ApiBrasilError`. Capture da mais específica para a mais
genérica.

**O cliente não é copiável.** Os serviços guardam um ponteiro para o
`HttpClient` do objeto — passe por referência, e use `withDevice()` (que devolve
`shared_ptr`) para uma segunda instância.

**Sem sandbox por URL.** A homologação das consultas é por chamada:
`{"homolog", true}` no corpo.
