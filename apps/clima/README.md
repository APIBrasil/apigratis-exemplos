# Clima

Condições atuais por cidade ou por coordenadas, com botão para usar a
localização do navegador.

## Rodando

```bash
cd ..                      # a partir de apps/
APIBRASIL_BEARER_TOKEN=... APIBRASIL_DEVICE_TOKEN_CLIMA=... php -S localhost:8000
```

Abra <http://localhost:8000/clima/>.

## Duas actions

| Action | Body |
| --- | --- |
| `POST /weather/city` | `{ city }` |
| `POST /weather/coordenates` | `{ lat, lng }` |

**`coordenates`**, não `coordinates` — é a grafia publicada no catálogo do
gateway. Como a action é repassada verbatim ao provedor, a grafia "correta" em
inglês dá 404.

## Geolocalização do navegador

`navigator.geolocation` exige **HTTPS ou localhost**. Em `localhost` o navegador
libera, que é o motivo de o app rodar sob `php -S` em vez de abrir o HTML pelo
`file://` — ali a API é bloqueada.

O usuário também precisa conceder a permissão, e ela pode ser negada. O app
trata os dois casos (indisponível e negado) com aviso, sem quebrar.

## Campos aninhados

Provedores de clima têm formatos bem diferentes: alguns devolvem tudo na raiz,
outros aninham em `main`, `current` ou `weather[0]`. A função `normalizar()`
achata as variantes num objeto só:

```javascript
{
    ...(dados?.main ?? {}),
    ...(dados?.current ?? {}),
    ...(Array.isArray(dados?.weather) ? dados.weather[0] : dados?.weather ?? {}),
    ...dados,
}
```

Depois, `pegar(dados, 'temp', 'temperature', 'temperatura', 'temp_c')` tenta os
nomes conhecidos em ordem. Para ver o formato que a sua conta recebe, abra
"Resposta completa do gateway".

## Coordenadas com vírgula

O validador `decimal()` do [proxy compartilhado](../_comum/apibrasil.php) troca
vírgula por ponto antes de converter — usuário brasileiro digita `-23,5613` com
frequência, e isso não deveria virar erro.
