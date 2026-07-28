# Redirecionamentos do crmapoficial.org.br

**Onde ficam:** painel da Cloudflare, não neste repositório.
GitHub Pages não lê `.htaccess` e a Cloudflare também não. O arquivo
`.htaccess` da raiz descreve 16 redirecionamentos e **nenhum deles funciona**.
Este documento existe para que o conhecimento sobreviva quando o `.htaccess`
for apagado.

Última verificação no ar: 28/07/2026.

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

### 1. Always Use HTTPS (chave, não é Redirect Rule)

`SSL/TLS → Edge Certificates → Always Use HTTPS: ligado`

Resolve: `http://crmapoficial.org.br/` responde **200 em HTTP** hoje, sem
redirecionar para HTTPS. Substitui as linhas 11–13 do `.htaccess`.

Pré-requisito: `SSL/TLS → Overview` precisa estar em **Full** ou
**Full (strict)**. Em "Flexible" o Always Use HTTPS gera laço infinito.

### 2. Redirect Rules (Rules → Redirect Rules)

Todas com código **301** e "Preserve query string" ligado.

#### Regra 1 — `carteirinha` para a URL curta

```
(http.request.uri.path eq "/carteirinha.html") or (http.request.uri.path eq "/carteirinha/")
```
→ `https://crmapoficial.org.br/carteirinha`

Motivo: a URL oficial de divulgação é a curta (decisão de 28/07/2026 no
`CLAUDE.md`). Hoje `/carteirinha.html` responde 200 — conteúdo duplicado — e
`/carteirinha/` com barra dá **404**.

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
