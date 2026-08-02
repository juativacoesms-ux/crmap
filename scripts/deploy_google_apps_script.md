# Publicar o Apps Script da planilha — PENDENTE desde 22/05/2026

## Situação, medida em 02/08/2026

**O código publicado no Google ainda é o antigo.** A implantação descrita
aqui nunca foi feita.

Como se provou, sem escrever nada na planilha: o arquivo
`google_apps_script.gs` deste repositório tem a função `doGet`, e a URL
publicada respondeu **"Função de script não encontrada: doGet"**. São
códigos diferentes. O do repositório também abre a planilha por
`openById(SPREADSHEET_ID)` — a correção do erro
`Cannot read properties of null (reading 'getActiveSheet')` que impedia a
gravação desde maio.

**Consequência provável:** as doações não estão sendo gravadas na planilha
desde 22/05/2026. Os registros no Supabase estão íntegros (20 em 02/08); só
a planilha ficou para trás. Conferir abrindo a planilha.

## Antes de implantar — trocar o token do Mercado Pago

Em 02/08/2026 descobriu-se que `google_apps_script.gs` estava **público** em
`crmapoficial.org.br/google_apps_script.gs`, com o Access Token de produção
do Mercado Pago em texto puro. O arquivo já saiu do ar (`_config.yml`), mas
**o token precisa ser trocado** — bloquear não desfaz a exposição.

1. Painel do Mercado Pago → Suas integrações → sua aplicação →
   **Credenciais de produção** → gerar novo **Access Token**
2. Atualizar a variável `MP_ACCESS_TOKEN` nas funções da Supabase
   (`create-preference` e `mp-webhook`)

## Passo a passo da implantação

1. Abra <https://script.google.com> e o projeto ligado à URL
   `/macros/s/AKfycbzRPMVu--BYlX51qU0Mj6P1SBTikDE7RKJhym0c_RMCJ-CoRM_4T4mNHjRudcvx6EK1/exec`

2. **⚙️ Configurações do projeto → Propriedades do script → Adicionar:**

   | Propriedade | Valor |
   |---|---|
   | `MP_ACCESS_TOKEN` | o Access Token **novo** do Mercado Pago |

   → **Salvar propriedades do script**

   O token não fica mais escrito dentro do código (mudança de 02/08/2026).
   Se a propriedade não existir, as funções de pagamento param com uma
   mensagem clara em vez de falharem em silêncio.

3. Substitua todo o código pelo arquivo `google_apps_script.gs` deste
   repositório.

4. **Salvar** (Ctrl+S).

5. **Implantar → Nova implantação →** tipo **App da Web** →
   Executar como **Eu** → Quem tem acesso: **Qualquer pessoa**.

6. Use a mesma URL `/exec`. Se mudar, atualizar
   `crmap-planilha-client.js`.

## Como conferir que deu certo

Abra a URL `/exec` no navegador. Tem que responder:

```json
{"ok":true,"service":"CRMAP carteirinha","method":"use POST para registrar na planilha"}
```

Se aparecer a página de erro do Google dizendo "Função de script não
encontrada: doGet", a implantação **não** pegou — o código publicado ainda é
o antigo. Esse teste não escreve nada na planilha.

Colunas na planilha: **Pagamento** (PENDENTE / PAGO / Voluntário) e
**Baixou** (SIM/NÃO).
