# Redirecionamentos do crmapoficial.org.br

**Onde ficam:** painel da Cloudflare, não neste repositório.
GitHub Pages não lê `.htaccess` e a Cloudflare também não. O arquivo
`.htaccess` da raiz descreve 16 redirecionamentos e **nenhum deles funciona**.
Este documento existe para que o conhecimento sobreviva quando o `.htaccess`
for apagado.

Última verificação no ar: 28/07/2026.

**Situação em 28/07/2026, 16h30 (Brasília): tudo abaixo está APLICADO e
verificado no ar.** O "Always Use HTTPS" foi ligado pela Iara no painel; as 3
Redirect Rules foram criadas via API da Cloudflare (ruleset
`488b470ce3064f23a8030cd7b92bec9c`, fase `http_request_dynamic_redirect`, zona
`9643300d83ca240d3c4764c23bd744f1`). O resultado dos testes está no fim deste
arquivo.

---

## O que já funciona sozinho (NÃO criar regra para isto)

Medido com `curl` em 28/07/2026:

| URL | O que acontece hoje | Quem faz |
|---|---|---|
| `https://www.crmapoficial.org.br/` | 301 → `https://crmapoficial.org.br/` | automático |
| `http://www.crmapoficial.org.br/` | 301 → `http://crmapoficial.org.br/` | automático (mantém HTTP — corrigido pelo "Always Use HTTPS") |
| `/acoes` | 301 → `/acoes/` | GitHub Pages |
| `/saude/controle` | 301 → `/saude/controle/` | GitHub Pages |
| `/carteirinha` | 200, serve `carteirinha.html` | GitHub Pages (URL sem extensão) |
| `/c.carteirinha.voluntario` | 200 | GitHub Pages |

Ou seja: das regras do `.htaccess`, a maioria já é feita por outra camada.
Só sobra o que está listado abaixo.

---

## Configuração necessária na Cloudflare

### 1. Always Use HTTPS (chave, não é Redirect Rule) — FEITO

`SSL/TLS → Edge Certificates → Always Use HTTPS: ligado`

Ligado em 28/07/2026 às 14h20 (Brasília). O modo SSL da zona está em **Full**,
então não há risco de laço.

Resolveu: antes disso, `http://crmapoficial.org.br/` respondia **200 em HTTP**,
sem redirecionar para HTTPS. Substitui as linhas 11–13 do `.htaccess`.

Pré-requisito: `SSL/TLS → Overview` precisa estar em **Full** ou
**Full (strict)**. Em "Flexible" o Always Use HTTPS gera laço infinito.

### 2. Redirect Rules (Rules → Redirect Rules) — FEITO

Criadas em 28/07/2026 às 16h25 (Brasília) — horário confirmado no campo
`last_updated` do ruleset —, as três com código **301** e "Preserve query
string" ligado.

#### Regra 1 — `carteirinha` para a URL curta

```
(http.request.uri.path eq "/carteirinha.html") or (http.request.uri.path eq "/carteirinha/")
```
→ `https://crmapoficial.org.br/carteirinha`

Motivo: a URL oficial de divulgação é a curta (decisão de 28/07/2026 no
`CLAUDE.md`). Antes da regra, `/carteirinha.html` respondia 200 — conteúdo
duplicado — e `/carteirinha/` com barra dava **404**.

**ATENÇÃO — nunca usar `starts_with(http.request.uri.path, "/carteirinha")`.**
Existem na raiz `carteirinha-base-data.js` e `carteirinha-base.png`, que a
página carrega. Uma regra por prefixo redirecionaria esses dois arquivos e
**quebraria a carteirinha**. Só correspondência exata.

#### Regra 2 — carteirinha do voluntário para a URL curta

```
(http.request.uri.path eq "/c.carteirinha.voluntario.html") or
(http.request.uri.path eq "/c.carteirinha.voluntario/") or
(http.request.uri.path eq "/c.carteirinha.voluntário") or
(http.request.uri.path eq "/c.carteirinha.voluntário/") or
(http.request.uri.path eq "/c.carteirinha.volunt%C3%A1rio")
```
→ `https://crmapoficial.org.br/c.carteirinha.voluntario`

Motivo: mesma lógica da regra 1. As variantes com acento existem porque o
`.htaccess` (linhas 27–28) tentava tratá-las; hoje dão 404.

A forma percent-encoded (`%C3%A1`) e a forma com acento literal podem ou não
ser normalizadas pela Cloudflare antes da regra rodar — por isso as duas estão
na lista. Testar depois de criar.

#### Regra 3 — `/index.html` para a raiz

```
(http.request.uri.path eq "/index.html")
```
→ `https://crmapoficial.org.br/`

Motivo: hoje `/index.html` responde 200 e a home responde 200. São a mesma
página em dois endereços — conteúdo duplicado para busca. Substitui a linha 16
do `.htaccess`.

---

## PENDENTE — regra 4, Casa de Acolhimento (criada em 31/07/2026, ainda NÃO aplicada)

A página `/casa-de-acolhimento` foi publicada em 31/07/2026. Medido no ar
logo depois do deploy:

| URL | Hoje | Deveria ser |
|---|---|---|
| `/casa-de-acolhimento` | 200 ✅ | 200 |
| `/casa-de-acolhimento.html` | **200** (conteúdo duplicado) | 301 → `/casa-de-acolhimento` |
| `/casa-de-acolhimento/` | **404** | 301 → `/casa-de-acolhimento` |

Expressão a criar, no mesmo ruleset das outras três, com 301 e "Preserve
query string" ligado:

```
(http.request.uri.path eq "/casa-de-acolhimento.html") or
(http.request.uri.path eq "/casa-de-acolhimento/")
```
→ `https://crmapoficial.org.br/casa-de-acolhimento`

**Correspondência exata (`eq`), nunca `starts_with`** — mesma regra de sempre.

**Por que não foi aplicada:** a variável `CLOUDFLARE_API_TOKEN` não estava
disponível na sessão de 31/07/2026. Sem ela não dá para chamar a API. A regra
não é urgente: o endereço oficial já funciona. O que fica pendente é o endereço
duplicado (ruim para busca) e o 404 de quem digitar com barra no fim.

---

## Observação — a Cloudflare reescreve e-mails nas páginas

Descoberto em 31/07/2026 ao comparar a home publicada com o repositório: o
que sai no ar **não é byte a byte** igual ao arquivo. A Cloudflare tem o
"Email Address Obfuscation" ligado e troca todo `mailto:` por um link
`/cdn-cgi/l/email-protection` mais um script que remonta o endereço.

Serve para atrapalhar robôs de spam, mas **depende de JavaScript**: com o JS
desligado a pessoa vê "[email protected]" no lugar do endereço. Ao comparar
arquivo local com o site no ar, essa diferença é esperada e não é erro.

---

## O que foi deliberadamente NÃO redirecionado

| `.htaccess` | Decisão | Motivo |
|---|---|---|
| `cdrmap.com.br` → domínio novo | descartado | a CRMAP não tem mais o registro; o DNS nem resolve |
| `index_backup.html` → `/` | apagar o arquivo | decisão de 28/07/2026: apagar conteúdo morto em vez de gastar regra |
| `crmap2/` → `/` | apagar a pasta | idem |
| `c.voluntario.html` → carteirinha do voluntário | apagar o arquivo | idem |
| `/acoes`, `/produtos`, `/terreno`, `/saude` sem barra | nada a fazer | o GitHub Pages já resolve |

`index_backup.html` ainda tem dois links para `carteirinha.html`
(linhas 526 e 847) — some junto com o arquivo.

---

## Como testar depois de mexer

```
curl -sS -o /dev/null -w '%{http_code} -> %{redirect_url}\n' <URL>
```

Esperado depois de tudo pronto:

| URL | Esperado |
|---|---|
| `http://crmapoficial.org.br/` | 301 → `https://crmapoficial.org.br/` |
| `/carteirinha.html` | 301 → `/carteirinha` |
| `/carteirinha/` | 301 → `/carteirinha` |
| `/carteirinha` | 200 (não pode redirecionar — laço) |
| `/carteirinha-base-data.js` | 200 (não pode redirecionar) |
| `/c.carteirinha.voluntario.html` | 301 → `/c.carteirinha.voluntario` |
| `/index.html` | 301 → `/` |

A Cloudflare tem cache próprio. Se algo não mudar, testar de novo alguns
minutos depois antes de concluir que falhou.

---

## Resultado medido em 28/07/2026, 16h30 (Brasília)

Tudo abaixo foi medido com `curl` **depois** de criar as regras.

| URL | Resultado |
|---|---|
| `http://crmapoficial.org.br/` | 301 → `https://crmapoficial.org.br/` |
| `/carteirinha.html` | 301 → `/carteirinha` |
| `/carteirinha/` | 301 → `/carteirinha` |
| `/index.html` | 301 → `/` |
| `/c.carteirinha.voluntario.html` | 301 → `/c.carteirinha.voluntario` |
| `/c.carteirinha.voluntario/` | 301 → `/c.carteirinha.voluntario` |
| `/c.carteirinha.volunt%C3%A1rio` | 301 → `/c.carteirinha.voluntario` |
| `/carteirinha` | 200 (não redireciona — correto) |
| `/c.carteirinha.voluntario` | 200 (não redireciona — correto) |
| `/carteirinha-base-data.js` | 200, 514 KB (intacto) |
| `/carteirinha-base.png` | 200, 386 KB (intacto) |
| `/` | 200 |
| `/carteirinha.html?nome=teste&x=1` | 301 → `/carteirinha?nome=teste&x=1` (query preservada) |

Toda cadeia termina em **1 salto** e HTTP 200. Nenhum laço. As duas
carteirinhas abrem de verdade (títulos "Gerador de Carteirinha - CRMAP" e
"Carteirinha Voluntário – CRMAP").

Sobre o acento: a Cloudflare normalizou a forma percent-encoded, então a regra
pegou. As variantes com acento literal seguem na expressão por segurança.

### Como mexer nessas regras pela API

```
curl -sS "https://api.cloudflare.com/client/v4/zones/9643300d83ca240d3c4764c23bd744f1/rulesets/488b470ce3064f23a8030cd7b92bec9c" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"
```

Substituir todas as regras: `PUT` em
`/zones/{zona}/rulesets/phases/http_request_dynamic_redirect/entrypoint`
com corpo `{"rules": [...]}` — **só** o campo `rules`; mandar `kind` ou `phase`
faz a API recusar. O token fica na variável de ambiente
`CLOUDFLARE_API_TOKEN`, nunca escrito neste repositório.
