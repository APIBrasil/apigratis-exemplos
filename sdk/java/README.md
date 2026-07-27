# Exemplos — SDK Java

SDK: `br.com.apibrasil:apigratis-sdk-java` ·
Repositório: <https://github.com/APIBrasil/apigratis-sdk-java>

Java >= 17. O transporte padrão é o `java.net.http.HttpClient` do próprio JDK —
a única dependência obrigatória é o Jackson (JSON). Toda resposta volta como
`Map<String, Object>` já decodificado.

## Rodando

```bash
cp ../../.env-example ../../.env    # e preencha
mvn -q compile

# As variáveis precisam estar no ambiente:
set -a && . ../../.env && set +a    # bash/zsh
mvn -q exec:java -Dexec.mainClass=Exemplo01ContaESaldo
```

| Arquivo | O que mostra |
| --- | --- |
| [Exemplo01ContaESaldo.java](./src/main/java/Exemplo01ContaESaldo.java) | cliente a partir do ambiente, status do gateway, saldo, plano |
| [Exemplo02ConsultasPorCredito.java](./src/main/java/Exemplo02ConsultasPorCredito.java) | CNPJ/CPF/veículos, campo `tipo`, homologação, envelope de cobrança |
| [Exemplo03WhatsApp.java](./src/main/java/Exemplo03WhatsApp.java) | device, sessão, QR Code, envio de texto e mídia, fila |
| [Exemplo04ServicosDevice.java](./src/main/java/Exemplo04ServicosDevice.java) | CEP, correios, placa, FIPE, clima, SMS |
| [Exemplo05ErrosERetry.java](./src/main/java/Exemplo05ErrosERetry.java) | exceções tipadas, política de retry, hooks |

## Particularidades do Java

**`Json.of(...)`** monta os bodies em pares chave/valor, sem `Map.of` verboso:

```java
api.whatsapp.sendText(Json.of("number", "5511999999999", "text", "Olá!"));
```

**Tipando a resposta.** `Json.to(resposta, MinhaClasse.class)` converte o `Map`
em POJO; `Json.string(m, "chave")`, `Json.bool`, `Json.object` e `Json.list` leem
campos sem cast na mão.

**`AutoCloseable`.** O cliente é seguro para uso concorrente e libera o
transporte no `close()`. Use try-with-resources em scripts; em aplicação de
longa vida, mantenha um singleton e feche no shutdown.

**Exceções são `RuntimeException`.** Nada de `throws` obrigatório — mas trate
`ApiBrasilException` nos pontos de borda.

## Spring Boot

```java
@Bean(destroyMethod = "close")
ApiBrasil apiBrasil(@Value("${apibrasil.bearer}") String bearer,
                    @Value("${apibrasil.device}") String device) {
    return ApiBrasil.builder().bearerToken(bearer).deviceToken(device).build();
}
```

## Interface legada

As classes `LoginClient`, `CepClient`, `BairrosClient` e companhia continuam
funcionando (DTOs tipados, `ApiException` checada), mas estão **deprecadas** —
prefira o cliente `ApiBrasil`.
