# Publicar o Apps Script da planilha — FEITO em 28/08/2026

## Situação atual (28/08/2026)

**Publicado e conferido no ar.** A implantação do site está na **Versão 3**,
de 28/08/2026 17:36 (Brasília), com o código deste repositório.

## ⚠️ O diagnóstico de 02/08/2026 estava ERRADO

Ficou registrado por quase um mês que "as doações não chegam à planilha desde
22/05/2026". **Isso nunca foi verdade.** As doações sempre chegaram.

O erro: o teste feito em 02/08 abriu a URL `/exec` no navegador (um GET) e viu
"Função de script não encontrada: doGet". Isso só provava que a versão
publicada não tinha a função de **teste**. Quem grava é o `doPost`, que estava
lá e funcionando.

Conferido em 28/08/2026 abrindo a planilha: 33 linhas, com registros contínuos
em junho, julho e agosto — o mais recente era 18/08/2026 14:53:31 (293/2026).

**Lição:** um GET que falha não diz nada sobre o POST. Para concluir que a
gravação parou, é preciso olhar a planilha.

## Como se publica (o jeito certo — mantém a URL)

O passo a passo antigo mandava "Implantar → **Nova** implantação". Isso está
errado para este projeto: cria uma URL `/exec` **nova**, e o site continuaria
chamando a antiga.

O certo:

1. Abra o projeto: <https://script.google.com/u/0/home/projects/196yDQI-doZraeKIAd_Z_Rd93BGjflUfElFL9eSkZk-VrGWVjJbU36Z60/edit>
   (é o script vinculado à planilha; dá para chegar nele pela planilha, em
   **Extensões → Apps Script**)
2. Cole todo o conteúdo de `google_apps_script.gs` por cima do que está lá.
3. **Salvar** (Cmd+S). Salvar **não** publica nada — as implantações usam
   versões congeladas.
4. **Implantar → Gerenciar implantações**
5. Selecione a implantação **"Sem título"** (é a que o site usa).
6. Clique no **lápis (Editar)**.
7. Em **Versão**, escolha **"Nova versão"**. Preencha a Descrição com a data
   e o que mudou.
8. Confira: Executar como **Eu**, Quem tem acesso **Qualquer pessoa**.
9. **Implantar**. O "Código de implantação" tem que continuar o mesmo —
   é assim que a URL não muda.

## ⚠️ Existem DUAS implantações — não confunda

| Nome | Para que serve | Versão em 28/08/2026 |
|---|---|---|
| **Sem título** | É a que o **site** chama (`crmap-planilha-client.js` e a função `registrar-planilha` da Supabase) | Versão 3, de 28/08/2026 |
| **Webhook CRMAP** | URL separada, provavelmente ligada ao Mercado Pago. **Não foi tocada.** | Versão 1, de 22/03/2026 |

A "Webhook CRMAP" ficou de propósito na versão antiga: o código novo busca o
token do Mercado Pago nas Propriedades do Script, que ainda não foram
preenchidas. Mexer nela sem o token quebraria o webhook.

## Ainda pendente: o token do Mercado Pago

O token de produção esteve público em `crmapoficial.org.br/google_apps_script.gs`
até 02/08/2026. O arquivo saiu do ar, mas **o token precisa ser trocado** —
bloquear não desfaz a exposição.

Depois de gerar o token novo (Mercado Pago → Suas integrações → Credenciais de
produção):

1. No Apps Script: **⚙️ Configurações do projeto → Propriedades do script →
   Adicionar**, com o nome `MP_ACCESS_TOKEN` → **Salvar**.
2. Nas funções da Supabase (`create-preference` e `mp-webhook`): atualizar a
   variável `MP_ACCESS_TOKEN`.

Boa notícia: desde 28/08/2026 o token **não está mais escrito dentro do
código** publicado no Google. Saiu junto com a nova versão.

## Como conferir que está no ar

```
curl -s https://script.google.com/macros/s/AKfycbzRPMVu--BYlX51qU0Mj6P1SBTikDE7RKJhym0c_RMCJ-CoRM_4T4mNHjRudcvx6EK1/exec
```

Tem que responder:

```json
{"ok":true,"service":"CRMAP carteirinha","method":"use POST para registrar na planilha"}
```

Esse teste não escreve nada na planilha.

**Para testar a gravação de verdade**, use a função da Supabase (é o caminho
que o site usa; o POST direto por `curl` esbarra num redirecionamento do
Google e não serve como teste):

```
curl -s -X POST https://qzjvzbvoxwhggvadaroq.supabase.co/functions/v1/registrar-planilha \
  -H "Content-Type: application/json" -H "Authorization: Bearer <chave anon>" \
  -d '{"numero":"999/2026","nome":"TESTE - PODE APAGAR","data":"28/08/2026","evento":"pagamento_pendente"}'
```

Resposta esperada: `{"ok":true,"status":200,"gas":"{\"success\":true}"}`.
Depois **apague a linha de teste da planilha.**

Evento inválido (ex.: `"evento":"coisa_invalida"`) responde `success` sem
escrever nada — serve para testar sem sujar a planilha.

## O que mudou com a Versão 3

- **Acabaram as linhas repetidas.** O código antigo sempre criava linha nova;
  o novo procura o número e atualiza a linha que já existe. Por isso a
  planilha tem a 128/2026 três vezes e a 134/2026 três vezes — de antes.
- **A "Data de Registro" (coluna A) é preservada.** O código do repositório
  sobrescrevia com a data da última alteração; corrigido em 28/08/2026 a
  pedido da Iara. Agora só é preenchida quando a linha nasce.
- Ganhou o `doGet` de teste e o token saiu de dentro do código.

Conferido no ar em 28/08/2026: três envios seguidos no número 999/2026
geraram **uma única linha**, e a Data de Registro (17:38:48) continuou
intacta depois de envios às 17:39:59 e 17:40:02.

Colunas da planilha: A=Data de Registro | B=Número | C=Nome da Guardiã |
D=Data Emissão | E=Pagamento | F=Voluntário | G=Baixou (sem título na
linha 1).
