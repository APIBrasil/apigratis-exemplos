# JavaScript no navegador

## Leia isto antes de copiar qualquer coisa daqui

**Chamar o gateway direto do navegador expõe o seu Bearer Token para qualquer
visitante da página.** Ele fica visível no DevTools (aba Network), no bundle
JavaScript e no histórico do navegador. Com esse token, qualquer pessoa consome
o seu saldo e acessa os dados da sua conta.

Isso vale para qualquer front-end público: React, Vue, HTML puro, extensão de
navegador, app Flutter distribuído. Não existe "esconder" o token no cliente —
minificar, ofuscar ou montar a string em pedaços não muda nada.

O padrão correto é um **proxy no seu backend**:

```
navegador  →  seu backend (guarda o token)  →  gateway APIBrasil
```

O navegador chama o seu endpoint; o seu backend adiciona o `Authorization` e
repassa. O token nunca sai do servidor.

## Os arquivos

| Arquivo | O que é |
| --- | --- |
| [com-proxy.html](./com-proxy.html) | ✅ o padrão correto — chama `/api/consulta.php` |
| [proxy.php](./proxy.php) | o backend do exemplo acima: valida, adiciona o token, repassa |
| [sem-proxy.html](./sem-proxy.html) | ⚠️ token no cliente. Só para ferramenta interna |

Para apps completos com esse padrão já montado, veja [apps/](../../apps/).

## Quando `sem-proxy.html` é aceitável

Quando **quem abre a página é o dono do token**:

- painel administrativo interno, atrás de login
- ferramenta que roda na sua máquina
- protótipo que você vai jogar fora

Não é aceitável em: site público, landing page, app de cliente, formulário
aberto, página com qualquer visitante que não seja você.

## CORS

O gateway envia os headers de CORS, então a chamada direta funciona do
navegador. **Funcionar não é o mesmo que ser seguro** — o CORS protege os
dados de *outros* sites contra a sua página, não o seu token contra os seus
visitantes.

## Onde guardar o token no backend

Variável de ambiente ou gerenciador de segredos. Nunca:

- num arquivo dentro do diretório servido pelo servidor web
- comitado no repositório
- num campo de banco acessível pela API pública

O [proxy.php](./proxy.php) lê de `getenv()`.
