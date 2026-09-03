# CRMAP — instruções do projeto

> Não existe `AGENTS.md` neste repositório hoje. Se um dia for criado, a
> primeira linha deste arquivo precisa virar `@AGENTS.md` — o Claude Code
> **não** lê `AGENTS.md` sozinho, só via essa importação.

## O básico

| Item | Valor |
|---|---|
| Repositório | `github.com/juativacoesms-ux/crmap` |
| Branch de produção | `main` |
| Domínio publicado | https://crmapoficial.org.br |
| Hospedagem | GitHub Pages, servindo a **raiz** do repositório |
| Na frente do domínio | Cloudflare (proxy ativo, nameservers `raina`/`kanye.ns.cloudflare.com`) |
| Fuso horário | Brasília (UTC−3) em tudo |
| Idioma | Português do Brasil, linguagem simples |

## Como se faz o deploy

Não há build, não há CI, não há `.github/workflows`.

**`git push` para a `main` = publicar no ar.** O GitHub Pages pega a raiz do
repositório e serve como está, em poucos minutos. Tudo que está commitado na
`main` fica público na internet, tenha link para ele ou não.

Consequências práticas:
- Não existe ambiente de homologação. O push é a publicação.
- A Cloudflare tem cache próprio. Se uma mudança não aparecer, pode ser cache —
  conferir com `curl -I` antes de concluir que o deploy falhou.
- Redirecionamentos **não** ficam no repositório: são Redirect Rules no painel
  da Cloudflare. O arquivo `.htaccess` que existe aqui é formato Apache e é
  **ignorado** pelos dois. Ver `docs/redirecionamentos.md`.

## Prazos com data marcada

Nenhum registrado até 28/07/2026. Quando houver, anotar aqui com a data
absoluta (não "semana que vem").

---

## REGRAS INVIOLÁVEIS

- NUNCA fazer git push sem antes, nesta ordem: mostrar o git diff completo,
  revisar cada arquivo alterado procurando erro, testar o que foi afetado,
  e só então publicar
- Depois de todo push: acessar o que está no ar e confirmar que funciona
  de verdade. Se quebrou, reverter na hora e avisar
- Nunca declarar uma tarefa concluída sem verificar no artefato publicado
- Não quebrar produção. Em caso de dúvida, perguntar antes
- Um commit por correção, com mensagem em português
- Nunca usar git push --force
- Nunca apagar arquivo sem confirmação explícita minha
- Manter paridade entre ambientes equivalentes, quando houver
- Responder sempre em pt-BR, linguagem simples, sem jargão
- Horário de Brasília em tudo

---

## Rotina obrigatória de sessão

**No INÍCIO de toda sessão, sem a usuária pedir:**
1. Ler a memória do projeto (`MEMORY.md` e os arquivos de memória).
2. Dar um resumo curto de onde paramos: o que está pendente, o que ficou
   sem publicar, o que está quebrado, o que depende dela.

**No FIM de toda sessão, sem a usuária pedir:**
1. Atualizar o diário de estado na memória (pendências, não publicado,
   branches, quebrado conhecido, o que depende dela).
2. Registrar aqui, na seção "Decisões", qualquer decisão nova e o motivo.

Se a sessão terminar sem isso, a próxima começa cega. Foi exatamente esse o
problema que motivou este arquivo.

**Onde mora cada coisa:**
- Regras, deploy, decisões duradouras → **este arquivo** (versionado no Git,
  sobrevive a troca de máquina, visível para qualquer pessoa do repositório).
- Diário volátil (o que está pendente hoje, o que não subiu) → **memória
  nativa** do Claude Code, em
  `~/.claude/projects/-Users-iarahorta-projetos-crmap/memory/`. Fica fora do
  Git de propósito: muda toda sessão e encheria o histórico de commits.

---

## Decisões tomadas (não desfazer sem ler o motivo)

### 03/09/2026 — O sistema APONTA o telefone incompleto, nunca completa sozinho
**Motivo:** a Iara mandou atualizar os contatos das pacientes com a lista que
ela montou (`~/Downloads/contatos crmap0309`). Medido antes de mexer: a lista
tem o **mesmo defeito** do sistema — **67 dos 81** contatos do PDF (83%) e
**61 de 89** das fichas por terapeuta estão com 10 dígitos em vez de 11.
No banco, 6 das 7 fichas idem. Cruzando os dois lados, **nenhuma** ficha do
sistema encontra número completo na lista; onde o nome bate, os dois estão
truncados — às vezes de forma diferente (Helena: `3188418250` no banco,
`3198418250` no PDF; Liderjane em três versões, com DDD 31 e 37).
**Como fica:** não houve importação. As telas passaram a **marcar em vermelho**
quem tem 10 dígitos, com a contagem no topo do bloco, e quem conhece a
paciente corrige.
**O que NÃO fazer:** deduzir o dígito que falta e gravar. Dá para inferir que
é o 9, mas a posição varia e o resultado é o telefone de alguém — aviso de
consulta de terapia para número errado expõe dado sensível de saúde, o mesmo
motivo da decisão de 02/09/2026 logo abaixo.
**Fixo tem 10 dígitos e é legítimo:** o aviso só aparece quando o primeiro
dígito depois do DDD é 6, 7, 8 ou 9 — faixa que não pode ser fixo. Não trocar
essa regra por "todo mundo com 10 dígitos", senão a tela passa a acusar
telefone certo.

### 03/09/2026 — A diretoria também corrige contato de paciente
**Motivo:** a correção de nome e WhatsApp existia desde 29/08/2026, mas só na
tela da profissional. A diretoria não tinha por onde fazer, então toda
correção virava pedido manual para a Iara. As funções do banco já aceitavam
`p_modo = 'coordenacao'` desde 29/08 — faltava só a tela.
**Como fica:** `/saude/controle/` tem o bloco "Contatos das pacientes", com
todas as fichas e o mesmo botão Corrigir da profissional. Cada profissional
continua vendo só quem ela atendeu.
**Junto disso:** fichas gravadas como `+55 31 8841-8250` eram contadas com 12
dígitos e apareciam sem formatação na tela. `soDigitosBr()` tira o código do
país — mas só quando sobra um telefone válido, para não mutilar o DDD 55, que
é o Rio Grande do Sul.
**Pendente:** `painel/contatos-pacientes-2026-09-03.sql` ainda **não foi
aplicado**. Ele faz a diretoria enxergar ficha **sem consulta marcada** — hoje
invisível, e é justamente onde o WhatsApp errado se esconde, porque a mensagem
nunca chegou. A tela funciona com ou sem ele (testado nos dois casos).

### 02/09/2026 — O e-mail da PACIENTE é discreto; o da profissional não
**Motivo:** ao marcar consulta sai aviso por e-mail para as duas. A CRMAP
atende mulheres em acompanhamento psicológico — **dado sensível de saúde**
(LGPD art. 5º, II) — e caixa de e-mail costuma ser compartilhada com
companheiro ou familiar.
**Como fica:** o e-mail da **paciente** não diz o tipo de atendimento, nem o
número da sessão, nem valor, nem a palavra terapia: só que ela tem um
atendimento na CRMAP, o dia, a hora e um WhatsApp de contato. O da
**profissional** é completo — é a ficha de trabalho dela.
**Não uniformizar os dois textos** sem falar com a Iara. Foi decisão dela em
02/09/2026, depois de o risco ser levantado.
O e-mail da paciente é campo **opcional**, e a tela avisa que só deve ser
preenchido com o consentimento dela.

### 02/09/2026 — Datas da Saúde sempre por `dataBrasilia()`, nunca `toISOString()`
**Motivo:** `hoje()` era `new Date().toISOString().slice(0,10)` — que é **UTC**.
Das 21h à meia-noite de Brasília o sistema achava que já era o dia seguinte.
Para quem atende à noite isso significava o campo Data nascendo com **amanhã**
e o filtro "De" começando amanhã, fazendo as **consultas de hoje sumirem da
lista**. Viola a regra de horário deste arquivo, e passou despercebido porque
só aparece depois das 21h.
**Como fica:** `dataBrasilia(somarDias)` no `saude-common.js`, fixo em UTC−3
(o Brasil não tem horário de verão desde 2019). **Nunca voltar a usar
`toISOString()` cru para data neste projeto.**

### 02/09/2026 — `min-width:0` nos filhos do `.grid-2` (não remover)
**Motivo:** a página da agenda **rolava para o lado inteira no celular** —
medido, 725px de conteúdo numa tela de 390px, com cabeçalho e rodapé
espremidos em meia tela. A causa não era a tabela: num CSS Grid os itens
nascem com `min-width:auto` e **não deixam o conteúdo encolher**, então a
tabela de 8 colunas empurrava a coluna, o grid e a página.
**Como fica:** `.grid-2 > * { min-width: 0 }` e `.card { min-width: 0 }`.
Tirar essas duas linhas traz o defeito de volta.

### 02/09/2026 — O guia `/saude/como-usar/` acompanha a tela
**Motivo:** é o passo a passo que a coordenação manda para as profissionais
pelo WhatsApp, e ele cita **os nomes dos botões como estão hoje**
("Aconteceu", "Não veio", "Reabrir", "Atualizar").
**Como fica:** mudou nome de botão ou fluxo em `/saude/`? Atualizar o guia na
mesma tarefa, senão ele passa a ensinar o que não existe mais.

### 02/09/2026 — "Esqueci minha senha" por e-mail, e num SUBDOMÍNIO
**Motivo:** a Iara perguntou por que a Jórsia não conseguia redefinir a senha.
A resposta foi que **redefinir senha não existia** — nem botão na tela `/saude/`,
nem função no banco. Quem esquecia ficava presa até alguém com a senha
institucional destravar em `/saude/controle/`. O custo estava no banco: em
31/08/2026 às 22:31 a Jórsia **se cadastrou de novo** (id 39) por não conseguir
entrar, e digitou o WhatsApp com um dígito a menos — então o cadastro novo
também não abria.

**Como fica:** código de 6 dígitos por e-mail, válido 30 minutos, 5 tentativas,
3 pedidos por hora. `painel/reset-senha-email-2026-09-02.sql` +
`supabase/functions/reset-senha/` + a caixa em `saude/index.html`.

**O que NÃO pode ser desfeito por engano:** as funções `_reset_gerar_codigo` e
`_reset_confirmar` **não têm grant para `anon`**, e a tabela `senha_reset_codigos`
tem RLS ligada **sem policy nenhuma**. Só a Edge Function as alcança, com a
chave de serviço. Um `grant ... to anon` ali transformaria a recuperação em
porta aberta: daria para pedir o código de qualquer pessoa e lê-lo na própria
resposta.

**Por que o remetente é `envio.crmapoficial.org.br` e não o domínio raiz:** o
`crmapoficial.org.br` já usa o **Email Routing da Cloudflare** (MX
`route1/2/3.mx.cloudflare.net`, SPF `include:_spf.mx.cloudflare.net`) e tem
**DMARC `p=reject`**. Pôr o Resend no raiz exigiria trocar o SPF e o MX de lá,
**quebrando o e-mail que a CRMAP já usa**. No subdomínio os dois convivem.

**A contrapartida, assumida:** 2 profissionais ativas sem e-mail (Fátima id 1 e
Rosilaine id 3) continuam dependendo da coordenação. As duas também estão sem
WhatsApp, então já não entravam.

### 29/08/2026 — Sem Mercado Pago: doação e carteirinha por PIX
**Motivo:** a Iara pediu ("hoje usamos apenas chave pix"), e a investigação
antes de mexer mostrou algo pior do que simplificação: **o aviso automático do
Mercado Pago nunca funcionou**. Nenhum dos 22 registros tem confirmação vinda
de lá — o que está guardado é o número da *intenção* de pagamento. E a página
só libera o download quando o banco diz `approved`. Ou seja: a pessoa pagava,
voltava, via "aguarde 1–2 minutos" e **nunca conseguia baixar**. Havia 13
pessoas reais nessa fila, a mais antiga desde 29/05/2026.
**Como fica:** o botão registra o pedido como pendente
(`registrar_intencao_carteirinha`), avisa a planilha e abre uma caixa com o QR
Code e a chave PIX — o mesmo QR da campanha, testado com transferência real em
31/07/2026. A liberação passa a ser a diretora clicando em **Aprovar manual**,
que é como já funcionava na prática.
**A contrapartida, assumida:** a carteirinha não sai na hora. Mas antes
também não saía — a diferença é que agora a pessoa sabe disso desde o começo.
**Não voltar a colocar intermediário de pagamento** sem confirmar que o aviso
automático grava mesmo no banco. O teste é olhar se aparece `payment_id`
numérico em `pagamentos_carteirinha`, não se a tela do checkout abre.

### 29/08/2026 — O WhatsApp da paciente é o que liga o histórico dela
**Motivo:** a paciente é criada quando a terapeuta marca a primeira consulta,
identificada pelo telefone. Um dígito errado cria uma ficha nova, e a contagem
das 8 sessões gratuitas recomeça do zero — é ela que decide quem paga.
**Como fica:** a terapeuta tem "Minhas pacientes", com a lista e a correção de
nome e WhatsApp. Cada uma só vê e corrige quem ELA atendeu; a coordenação vê
todas. Se o telefone novo já for de outra ficha, o sistema **recusa e explica**
em vez de decidir sozinho: juntar dois históricos é decisão de quem conhece o
caso.

### 29/08/2026 — Arquivo compartilhado entre telas não pode assumir campos
**Motivo:** `saude-common.js` é usado por `/saude/` e por `/saude/controle/`,
que não têm os mesmos campos. O código preenchia `txtPixInline` direto; esse
elemento só existe na tela da coordenação, então em `/saude/` a linha
quebrava e **nada depois dela rodava** — nem o nome da profissional no topo,
nem o carregamento da agenda. A terapeuta entrava e via "Minhas consultas"
vazia para sempre. Ninguém percebeu porque a tela abria normalmente.
**Como fica:** existe um `preencher(id, prop, valor)` que só age se o elemento
existir. Ao mexer nesse arquivo, lembrar que ele roda em duas telas diferentes.
**Junto disso:** os arquivos comuns passaram a ser chamados com `?v=data`.
Sem isso o navegador continua servindo a versão antiga depois de uma correção
— aconteceu comigo no meio do teste.


### 28/08/2026 — Foto do site só pode vir do nosso próprio Storage
**Motivo:** se o painel aceitasse um endereço qualquer, o site poderia acabar
apontando para uma imagem hospedada fora — que some quando o dono apagar, ou
troca de conteúdo sem ninguém saber.
**Como fica:** as fotos vão para o bucket **`fotos-site`**, que nasceu com
limite de 5 MB e só aceita imagem. `salvar_conteudo_site` recusa qualquer
endereço que não comece com o Storage deste projeto, e `textos-do-site.js`
confere de novo antes de trocar.
**Nome novo a cada envio** (`chave-timestamp.ext`): reaproveitar o nome faria
o navegador continuar mostrando a foto antiga guardada no cache.
**Capa da home:** é `background-image` com gradiente por cima. O código troca
só a parte `url(...)` e preserva o gradiente — não sobrescreve a propriedade
inteira.
**⚠️ Risco que continua aberto:** a política do Storage permite que qualquer
pessoa com a chave pública envie arquivo (`INSERT` com `with_check: true`, sem
restrição de bucket, tamanho ou tipo). O bucket novo tem limites próprios, mas
o `fotos-produtos` não tem nenhum. Vale apertar isso.

### 28/08/2026 — O menu não é editável pelo painel
**Motivo:** os nomes do menu orientam quem visita o site e aparecem em todas
as páginas. Um nome trocado sem querer atrapalha a navegação inteira, e o
ganho é pequeno — nome de menu quase nunca muda.
**Como fica:** menu continua no código. Texto de conteúdo (título, parágrafo,
card, rodapé) é editável; estrutura de navegação, não.
**Mesma lógica vale para link e telefone:** o telefone do rodapé da campanha é
um `<a>` e ficou de fora; só o endereço ao lado dele virou editável.


### 28/08/2026 — Só vira editável o que é TEXTO PURO
**Motivo:** ao abrir a edição para as outras páginas, vários parágrafos têm
`<a>` ou `<strong>` dentro. A troca usa `textContent`, então marcá-los
**apagaria o link**. Na página da campanha isso derrubaria o link do terreno e
o WhatsApp da coordenação — bem no lugar onde a instituição arrecada.
**Como fica:** só recebe `data-site` o elemento cujo conteúdo é texto puro.
Parágrafo com link ou negrito continua fixo no código; se precisar mudar, é
pedido para quem mexe no código mesmo.
**Caso especial resolvido:** o `<h1>` da campanha quebra em duas linhas com
`<br>`. Virou dois `<span data-site>` separados, um por linha, para a quebra
não se perder.
**Onde o código mora:** `textos-do-site.js` na raiz, carregado com `defer`
pelas cinco páginas. Antes o trecho estava embutido no `index.html`; virou
arquivo único para não existirem cinco cópias divergentes.
**Ao mexer:** conferir que banco e HTML batem — cada `data-site` precisa de uma
linha em `conteudo_site` e vice-versa. Um comando que compara os dois lados
está no diário da sessão de 28/08/2026.

### 28/08/2026 — Carteirinha que já foi baixada precisa ser "liberada de novo"
**Motivo:** `carteirinha.html` só libera o download quando existe uma linha
com aquele número e status `approved`. Quando a pessoa baixa, o status vira
`downloaded` — e ela **não consegue baixar de novo**. Quem perdia o arquivo
dependia da Iara mexer no banco.
**Como fica:** `gerenciar_carteirinha` com as ações `corrigir_nome`,
`liberar_download` (devolve para `approved`), `cancelar` (status `cancelado`)
e `reabrir`. Na tela, os botões mudam conforme a situação da linha.
**Cuidado que ficou no código:** liberar o download de uma carteirinha
cancelada é recusado — tem que reabrir antes. Sem isso, "cancelada" viraria
um rótulo sem efeito.


### 28/08/2026 — Texto editável mora no HTML; o banco só guarda o que mudou
**Motivo:** a diretora precisa trocar frases e cards da home sem pedir para
ninguém. A saída óbvia — a página buscar todo o texto do banco — quebraria a
regra de 31/07/2026: se o JavaScript falhar, a página fica **vazia**.
**Como fica:** o texto original continua escrito no `index.html` e é o que
aparece. Cada pedaço editável leva `data-site="chave"`. Depois que a página já
apareceu, um trecho no fim do `index.html` busca `conteudo_site_publico()` e
troca só o que estiver diferente. Sem JavaScript, o site fica com o texto
original — completo, nunca vazio.
**Segurança:** a troca usa **`textContent`, nunca `innerHTML`**. Um `<` num
texto digitado pela diretora vira letra na tela, não tag. Provado com um
texto malicioso de verdade.
**Quem lê e quem escreve:** o site **lê sem senha** (é conteúdo público, com
policy de select para `anon`). Escrever e listar no painel exigem a senha, por
`salvar_conteudo_site` e `listar_conteudo_site`. Escrita direta na tabela está
revogada para `anon`.
**Ao acrescentar um pedaço editável:** marcar com `data-site` no HTML **e**
inserir a linha em `conteudo_site` com o texto atual, o rótulo que a diretora
vai ler e o grupo. Se faltar a linha no banco, o campo não aparece no painel;
se faltar a marcação no HTML, o texto salvo não vai para lugar nenhum.

### 28/08/2026 — A diretora troca a própria senha, e a senha é uma só
**Motivo:** até aqui a senha só era trocada por script no terminal da Iara. Em
05/08/2026 a senha se perdeu e a diretora ficou sem acesso esperando a Iara ter
tempo. Autonomia de verdade inclui a própria chave da porta.
**Como fica:** `trocar_senha_painel(atual, nova)` em Configurações. Exige a
senha **atual** — sem isso, quem encontrasse um painel aberto trancaria a
diretora para fora. Recusa menos de 10 caracteres, espaço nas pontas (causa
clássica de "digitei certo e não entra") e senha igual à anterior.
**A tela precisa continuar avisando** que essa senha abre o painel **e** o
`/saude/controle/`, e que ninguém consegue vê-la depois de salva.
**Como testar sem a senha de produção:** criar uma chave separada em
`painel_config` (`senha_teste_hash`), apontar uma cópia da função para ela,
testar e apagar. Conferir a impressão digital (`md5(valor)`) do hash real
antes e depois: tem que ser idêntica.

### 28/08/2026 — Tela de gestão mostra QUEM NÃO CONSEGUE ENTRAR, não só "ativo sim/não"
**Motivo:** a tela da coordenação da Saúde listava uma coluna "Ativa: Sim/Não",
e com isso ninguém percebeu que **a Coordenadora de Saúde Mental e a
Vice/Diretora estavam sem acesso desde agosto**. Elas foram desativadas por
estarem sem WhatsApp — e o login é por WhatsApp. "Ativa: Não" não conta essa
história; "Desativada — não entra" conta.
**Como fica:** a coluna chama-se "Situação" e diz o motivo em vermelho. O
resumo no topo separa quem entra de quem não entra. **"Pode entrar" exige as
duas coisas: estar ativa E ter WhatsApp** — contar só as ativas mentiria para
quem está ativa sem telefone (erro que os testes pegaram antes de publicar).
**Regra que fica:** em tela de gestão, mostrar a consequência, não o campo do
banco. Quem lê precisa saber o que fazer, não qual coluna está marcada.

### 28/08/2026 — Como testar função do banco sem ter a senha do painel
**Motivo:** as funções do painel são protegidas por `_senha_painel_ok`, e a
senha é bcrypt — eu não a tenho e não posso lê-la. Sem isso eu só conseguiria
testar o caminho do erro. Trocar a senha de produção para testar está fora de
questão: derrubaria a diretora.
**Como se faz:** gerar do próprio arquivo uma cópia da função com nome de
teste e **sem a checagem de senha**, criar registros fictícios, rodar todos os
casos (inclusive o login de verdade no fim), e então **apagar a cópia e os
registros** e conferir que a contagem voltou ao normal. O corpo testado é o
mesmo do código real — só a porta de entrada muda.
**Não fazer:** testar dentro de `begin/rollback` mexendo na senha. Se a
transação não fechar como esperado, a senha de produção fica trocada.

### 28/08/2026 — Tabela de gestão vira cartão no celular
**Motivo:** a tabela de profissionais tem 5 colunas e 3 botões, e precisa de
~580px. Numa tela de 360px o conteúdo **vazava sem rolagem** — os botões
ficavam fora do alcance, e a diretoria usa celular. Mesmo problema já resolvido
no painel em 14/08.
**Como fica:** abaixo de 700px o `thead` some, cada linha vira um cartão e o
rótulo da coluna aparece como etiqueta, vindo de `data-rotulo` na `<td>`.
Botões com 44px de altura mínima.
**Regra que fica:** toda tabela nova de gestão nasce com esse tratamento.
Conferir medindo `scrollWidth` contra `clientWidth`, não no olho.

### 28/08/2026 — A "Data de Registro" da planilha nunca é sobrescrita
**Motivo:** o código novo do Apps Script procura a carteirinha pelo número e
regrava a linha inteira — o que acabou com as linhas repetidas, mas apagava a
coluna A de quem voltasse para baixar. A Iara escolheu manter a data original.
**Como fica:** em `google_apps_script.gs`, a coluna A só é preenchida quando a
linha nasce (`if (rowIdx <= 0 || !linha.atualizado)`). Conferido no ar: três
envios seguidos no mesmo número deixaram uma linha só, com a data do primeiro.

### 28/08/2026 — Publicar o Apps Script é "Nova versão", nunca "Nova implantação"
**Motivo:** o passo a passo antigo mandava criar uma **nova implantação**, o
que gera uma URL `/exec` diferente — o site continuaria chamando a antiga e a
gravação pararia sem aviso. O certo é **Gerenciar implantações → a "Sem título"
→ lápis → Versão: Nova versão → Implantar**, que mantém o mesmo código de
implantação e a mesma URL.
**Atenção:** existem **duas** implantações. A "Sem título" é a do site
(Versão 3, de 28/08/2026). A **"Webhook CRMAP"** tem URL própria, é
provavelmente do Mercado Pago, e ficou de propósito na Versão 1 de março —
o código novo busca o token nas Propriedades do Script, que ainda estão
vazias, então publicá-lo ali quebraria o webhook.

### 28/08/2026 — Um GET que falha não prova nada sobre o POST
**Motivo:** em 02/08/2026 eu concluí, a partir de um GET na URL `/exec` que
respondia "Função de script não encontrada: doGet", que **as doações não
chegavam à planilha desde 22/05**. Ficou quase um mês registrado como a
segunda pendência mais grave do projeto. Era falso: quem grava é o `doPost`,
que estava lá e funcionando. A planilha tinha registros contínuos de junho,
julho e agosto — o mais novo era de 18/08/2026.
**Como fica:** antes de declarar que uma gravação parou, **abrir o destino e
olhar**. Um teste que falha só prova o que ele testa.

### 14/08/2026 — Texto que veio do banco nunca entra como HTML no painel
**Motivo:** o nome de quem faz carteirinha vem de um formulário **público**, e
o painel jogava esse nome direto no HTML da página (`${p.nome_pagador}`). Quem
doasse usando `<img src=x onerror=...>` como nome executaria código dentro do
painel **já logado da diretora** — com a senha na memória da página. O mesmo
valia para nome, preço e endereço de foto dos produtos.
**Como fica:** existe a função `esc()` em `painel/index.html`, e **todo** texto
vindo do banco passa por ela antes de virar HTML. O `id` do produto passa por
`Number()`. Provado com um nome malicioso de verdade no teste: o texto aparece
na tela como texto e nenhuma tag é criada.
**Regra que fica:** ao montar HTML com `innerHTML` a partir de dado do banco,
passar por `esc()`. Não existe dado "confiável" numa tabela que o público
alimenta.

### 14/08/2026 — A tela de carteirinhas é a lista de todo mundo, não só de quem pagou
**Motivo:** a diretora precisava ver quem já fez carteirinha. A tela existia,
mas se chamava "Relatório Pagamentos" e prometia "veja quem **pagou**" — o que
esconde justamente as 13 pendentes. A tabela `pagamentos_carteirinha` guarda
**todo mundo que passou pelo fluxo**: a linha nasce quando a pessoa clica para
doar (`create-preference`), não quando o pagamento é confirmado.
**Como fica:** a tela virou "Carteirinhas emitidas", com resumo em números
(total / pagas / pendentes / voluntárias), busca por nome ou número, e data e
hora sempre em Brasília. No celular cada linha vira um cartão com rótulos —
tabela de 6 colunas em tela de 360px é ilegível, e a diretoria usa celular.
**Nenhum SQL foi preciso:** a função `listar_pagamentos_painel` já existia
desde a migração de 01/08 e já devolvia todas as colunas. Conferido no banco:
ela enxerga as 21 linhas e a chave pública pode chamá-la.
**Armadilha corrigida junto:** lista vazia tinha dois motivos possíveis —
ninguém fez carteirinha, ou a senha não passou (a função devolve `[]` nos dois
casos). Os dois diziam "nenhum pagamento registrado", o que faria a diretora
concluir que ninguém se cadastrou. Agora a tela pergunta ao banco qual é o
caso e diz a frase certa.

### 05/08/2026 — A senha do painel se troca por caixa segura, nunca por SQL colado
**Motivo:** a diretora não conseguia entrar, e a senha definida em 01/08 tinha
se perdido — ela é bcrypt no banco, não existe jeito de ler de volta. Trocar
exigia rodar SQL com a senha nova dentro, e colar senha no chat a grava no
histórico para sempre.
**Como fica:** `~/bin/senha-painel` abre uma caixa do macOS com texto
escondido, pede duas vezes, grava o hash pela Management API e confere
sozinho (senha nova aceita? antiga derrubada?). A senha não passa pelo chat,
não vai para arquivo nenhum, não aparece no `ps`. `--testar` só confere, sem
alterar. Recusa senha com menos de 10 caracteres ou com espaço nas pontas —
espaço nas pontas é a causa clássica de "digitei certo e não entra", e
aparar em silêncio deixaria a pessoa com senha diferente da que pensa.
**Onde a senha mora:** uma linha só, `senha_painel_hash` em `painel_config`.
Nenhum arquivo do repositório guarda senha. Sete funções a conferem, todas
por `_senha_painel_ok` — inclusive a `confirmar_pagamento`, que aprova doação
manual. Por isso trocar a senha **não quebra nada**: é um `update` e pronto.
**Atenção que não é óbvia:** as funções `_saude_senha_ok` e
`_saude_senha_coord_ok` também apontam para esse mesmo hash, e delas dependem
outras 13 funções da Saúde. **A senha do painel é também a senha de
`/saude/controle/`.** Trocar uma troca as duas.
**Lição cara desta sessão:** a primeira versão do script embutia o programa
Python por `/dev/fd/3`; dentro de um cano, no macOS, isso entrega um programa
**vazio**. Ele saiu com código 0 sem fazer nada, e a Iara achou que tinha
trocado a senha. Eu tinha testado a sintaxe e as partes separadas, **não o
script montado**. Testar o artefato inteiro, sempre.

### 05/08/2026 — Botão que dispara ação lenta vira "carregando" no primeiro toque
**Motivo:** no painel a pessoa apertava e a tela não mudava até o banco
responder, então apertava de novo. Não era só incômodo: **"Publicar Agora"
cadastrava o produto duplicado** e "Aprovar manual" aprovava e avisava a
planilha duas vezes. O "Entrar" não dava sinal nenhum, e os outros três
mostravam uma caixinha "Aguardando..." que **não impedia clique**.
**Padrão do projeto agora:** toda ação que fala com o banco usa
`ocupar(botao, texto)`, que desativa o botão, põe uma roda girando e troca o
texto (`Entrando...`, `Publicando...`, `Aprovando...`, `Excluindo...`), e
devolve a função que libera — chamada sempre no `finally`. Se o botão já
estiver ocupado, `ocupar` devolve `null` e a ação **não roda de novo**. A tela
de espera passou a cobrir a tela inteira, então nada mais é clicável enquanto
a ação corre.
**Corrigido junto, achado na revisão:** `excluirProduto` não tinha
`try/finally` — um erro deixava a tela de espera travada e o painel parecia
congelado; e `carregarProdutos` estourava se a consulta voltasse nula,
derrubando o carregamento inteiro.
**Como foi conferido:** Chromium 390×800 com respostas do Supabase fingidas e
rede lenta de propósito; 18 verificações, rodadas contra o arquivo local **e
contra o site no ar**, incluindo "3 toques = 1 chamada só" nos quatro botões.
Mais um teste sem fingimento nenhum, com senha errada, contra o Supabase de
verdade. Armadilhas do Playwright ficaram anotadas na memória do projeto.

### 02/08/2026 — Segredo nunca mais dentro de arquivo do repositório
**Motivo:** o `google_apps_script.gs` tinha o **Access Token de produção do
Mercado Pago** em texto puro, e estava público em
`crmapoficial.org.br/google_apps_script.gs` (respondia 200). É a chave que
movimenta pagamento — mais grave que a senha do painel. A falha foi da lista
de exclusão que criei em 01/08: bloqueei `.sql`, `.md`, `docs/` e `scripts/`,
e não pensei em `.gs`.
**Como fica:** o token saiu do código e passou a vir das **Propriedades do
Script** do Google, por `mpToken_()`, que falha com mensagem clara se não
estiver cadastrado. O arquivo pode ser lido por qualquer um sem risco.
**Bloquear não basta:** o token esteve exposto por tempo indeterminado e
**precisa ser trocado** no painel do Mercado Pago. Depois, atualizar também a
variável `MP_ACCESS_TOKEN` das funções da Supabase.
**Varredura feita na mesma hora, e o que NÃO é problema:** todas as chaves
Supabase nos arquivos do site são `anon` (públicas por natureza, e agora sem
nada atrás por causa do RLS); o `APP_USR` de `carteirinha.html` é a chave
**pública** do Mercado Pago, que o site precisa ter; as 4 funções de servidor
usam `Deno.env.get` e não têm segredo embutido. Saíram da publicação também
`supabase/` e qualquer `.py` solto.
**Regra que fica:** ao acrescentar tipo de arquivo novo ao repositório,
conferir se precisa entrar no `exclude` do `_config.yml`. Ele é a única coisa
que separa "está no Git" de "está na internet".

### 02/08/2026 — O e-mail do site não depende mais de JavaScript
**Motivo:** a Cloudflare tinha o *Email Address Obfuscation* ligado e trocava
todo `mailto:` por um script. Quem estivesse sem JavaScript — conexão ruim,
celular antigo, bloqueador — via `[email protected]` no lugar do
endereço, inclusive **na página de doação**. Isso contrariava a decisão de
31/07 (a página de doação não pode depender de JavaScript).
**Contrapartida aceita:** o endereço fica visível para robôs de spam. A Iara
escolheu assim: spam se filtra, doadora que não acha o contato é doação
perdida.
**Junto disso:** o site inteiro passou a usar `contato@crmapoficial.org.br`.
A página da campanha mostrava um Gmail; dois endereços obrigavam a olhar duas
caixas de entrada.

### 02/08/2026 — Foto de produto comprimida entra com nome novo, o original fica
**Motivo:** as 59 fotos somavam **42,2 MB** no armazenamento do Supabase
(média de 733 KB, a maior com 3,7 MB) e a página `/produtos/` era a mais pesada
do site. O redimensionamento por URL da Supabase (`/render/image/`) responde
**403** — é recurso de plano pago e não está ligado, então a única saída era
reenviar as fotos.
**Como foi feito:** lado maior de 1000px (o cartão mostra 320px; 1000px cobre
tela 3× com folga), JPEG qualidade 80, progressivo. Resultado: **42,2 MB → 5,0
MB, 88% menor**. Na página: ao abrir caiu de 7,7 MB para **0,72 MB**; rolando
tudo, de 28 MB para **3,35 MB**.
**A parte que importa:** as comprimidas subiram com nome NOVO (sufixo
`-menor.jpg`) e só o campo `foto_url` do banco mudou. **Nenhum original foi
apagado ou sobrescrito** — eles continuam no armazenamento, ao lado. Desfazer é
rodar um `update` que devolve os endereços antigos, sem reenviar nada.
**Onde está o desfazimento:** `~/Documents/crmap-fotos-originais-2026-08-02/`
(fora do repositório, porque são 52 MB de imagem). Tem os 70 originais
conferidos byte a byte, o `desfazer.sql`, o `mapa-troca.json` e um `LEIA-ME.txt`.
**Ao cadastrar produto novo pelo painel:** a foto entra como veio do celular,
sem compressão. Vale repetir esse processo de tempos em tempos, ou um dia
comprimir no próprio painel antes de enviar.

### 01/08/2026 — O que vai para o ar passa a ser uma lista, não o repositório inteiro
**Motivo:** o GitHub Pages serve a raiz, então tudo que está commitado vira
endereço público. Estavam abertos: `CLAUDE.md`, os 4 `backup*.md`,
`docs/redirecionamentos.md`, os **9 arquivos `.sql` do painel** (um deles com
a senha em texto puro) e o `cnpj.zip`. O Jekyll já estava ligado (não existe
`.nojekyll`), então bastou criar `_config.yml` com `exclude:`.
**Consequência prática:** ao acrescentar arquivo interno novo ao repositório,
conferir se precisa entrar nessa lista. O `_config.yml` é hoje a única coisa
que separa "está no Git" de "está na internet".

### 01/08/2026 — A senha nunca mais fica escrita em arquivo do repositório
**Motivo:** a senha do painel estava em texto puro em `painel/index.html:167`,
e a senha da secretaria estava **renderizada na tela** de `/saude/controle/`,
visível para qualquer pessoa que abrisse a página. As duas são públicas há
tempo indeterminado e precisam ser trocadas, não só escondidas.
**Como fica:** quem julga a senha é o banco, pela função
`validar_senha_painel`, com hash bcrypt guardado em `painel_config`. O painel
só envia o que a pessoa digitou. O SQL está em
`painel/migracao-seguranca-2026-08-01.sql`.
**Limite consciente:** eu não tenho credencial do Supabase e **não consigo
executar nem testar** esse SQL. Ele foi escrito lendo os `.sql` e o código do
site, e traz seção de teste e de desfazimento. A coluna `senha_acesso` não é
apagada de propósito — é a rede de segurança até os logins com hash serem
confirmados por uma profissional de verdade, do celular dela.

### 01/08/2026 — O token da Cloudflare mora nas Chaves do macOS, não no `.zshrc`
**Motivo:** o `~/.zshrc` só é lido em terminal interativo. As sessões de
comando do Claude Code são não-interativas e **não** leem esse arquivo —
testado: o terminal da Iara enxergava a variável e eu não. Por isso a linha
está no `~/.zshenv`, que vale para as duas situações. O token em si fica nas
Chaves (`cloudflare-crmap-api-token`), nunca em arquivo; `~/bin/token-cloudflare`
abre uma caixa do macOS com texto escondido para guardar ou trocar.
**Contrapartida aceita:** depende do Keychain estar destravado.

### 01/08/2026 — O logo tinha a grade de transparência gravada nos pixels
**Motivo:** o `logo.png` original trazia 263.596 pixels **opacos** formando um
xadrez cinza numa meia-lua embaixo do círculo — resquício de exportação com a
grade do editor visível. Aparecia em todas as páginas, gritante sobre fundo
escuro. A grade estava toda FORA do desenho, então foi removida sem tocar na
arte, junto com a compressão (4.442 KB → 45 KB).
**Vale também para o `logo-leve.png`,** que herdava o mesmo defeito.

### 01/08/2026 — Grade responsiva: o `min()` vale para o site inteiro, não só para a galeria
**Motivo:** a regra de 29/07 tinha ficado só na galeria do Arraiá. Medido com
navegador em tela de 360px: na página Ações os cartões chegavam a **374px**, e
como a `section` tem `overflow: hidden`, o excedente era **cortado** — sumia,
não rolava. Corrigido em `.grid-gallery` (Ações) e `.board-grid` (home).
**Padrão do projeto agora:** toda grade nova usa
`minmax(min(Xpx, 100%), 1fr)`. Nunca `minmax(Xpx, 1fr)` puro.

### 31/07/2026 — O QR Code do PIX é desenhado no HTML, não é arquivo de imagem
**Motivo:** a Iara não tinha o código "Pix Copia e Cola" do banco, então o
código foi montado aqui (padrão BR Code / EMV) a partir do CNPJ e do município
do `cnpj.pdf`: chave `65198846000123`, recebedor `CRMAP`, cidade `POMPEU`,
**sem valor fixo** (campo 54 ausente de propósito — quem doa escolhe quanto).
O QR virou um `<path>` SVG dentro do próprio `casa-de-acolhimento.html`:
2,3 KB, zero requisição, não borra por mais que a pessoa aproxime a tela.
**Como refazer se a chave mudar:** o script está descrito na memória do
projeto. Sempre reler o QR gerado com um leitor independente antes de publicar
— foi assim que se conferiu este (OpenCV devolveu o código idêntico).
**Contrapartida aceita:** o código fica congelado no HTML. Se o CNPJ mudar,
tem que gerar de novo — não é buscado de lugar nenhum.
**CONFIRMADO NA PRÁTICA em 31/07/2026:** a Iara escaneou o QR publicado e
transferiu R$ 1,00. O valor caiu na conta da CRMAP. A partir daí a página está
liberada para divulgação. Repetir esse teste sempre que o código Pix mudar —
conferência técnica não substitui a transferência de verdade.

### 31/07/2026 — Página de campanha usa `logo-leve.png`, não o `logo.png`
**Motivo:** o `logo.png` tem 4,4 MB e aparece no topo de toda página. Usar ele
faria a página da campanha nascer com 4,4 MB — o oposto do pedido. O
`logo-leve.png` tem **18 KB** (260 px, PNG de 128 cores) e é visualmente
idêntico no tamanho em que aparece (130 px).
**Testado:** 64 cores dava 10 KB mas perdia a transparência da borda e criava
um halo rosado. 128 cores é o menor que preserva.
**Vale só para `casa-de-acolhimento.html`.** As outras páginas continuam com o
logo de 4,4 MB — trocar em todas ainda não foi autorizado.

### 31/07/2026 — Página de doação não pode depender de JavaScript
**Motivo:** o resto do site usa a classe `.reveal`, que deixa o bloco com
`opacity: 0; visibility: hidden` até o JavaScript revelar ao rolar a tela. Numa
página de arrecadação isso é risco real: se o JS falhar (internet ruim, celular
antigo, bloqueador), a chave PIX e o QR Code ficam **invisíveis**. A página da
campanha e o bloco novo da home não usam `.reveal` por isso. O único JS da
página é o botão de copiar — e ele tem caminho reserva (`execCommand`) para
celular antigo, mais uma mensagem de erro que manda copiar à mão.

### 31/07/2026 — A campanha entra no menu de todas as páginas, em verde
**Motivo:** escolha da Iara. Verde comum e não vermelho porque o vermelho já é
do "Gerar Carteirinha" — dois vermelhos competem e nenhum se destaca. Entrou em
7 páginas, inclusive a do Terreno (é o terreno onde a casa será construída) e a
área da Saúde. Na home há também um bloco de destaque logo depois da capa,
porque é por lá que a maioria do público entra.

### 29/07/2026 — Foto de galeria vem do Flickr, nunca copiada para cá
**Motivo:** a galeria do Arraiá tem 188 fotos no álbum do Instituto Guaicuy.
Copiar as escolhidas para o repositório engordaria o Git para sempre (o Git
guarda cada versão de arquivo binário) e o site já sofre de peso de imagem.
As 12 fotos são carregadas de `live.staticflickr.com`, com `loading="lazy"`,
e cada uma leva à sua página no Flickr — o que também cumpre o crédito que o
Flickr pede. Crédito visível na página: JhenLoure / Instituto Guaicuy.
**Contrapartida aceita:** se o Instituto Guaicuy apagar o álbum, a galeria
esvazia. Em troca, o repositório não cresce e a página abre rápido no celular.
**Como pegar o álbum inteiro:** a página do Flickr só entrega ~50 das 188 no
HTML (o resto é JavaScript). O caminho é usar a chave pública de API que está
na própria página e chamar `flickr.photosets.getPhotos`. Está detalhado na
memória do projeto.

### 29/07/2026 — Grade responsiva usa `minmax(min(Xpx, 100%), 1fr)`
**Motivo:** as grades antigas usam `minmax(320px, 1fr)` (home) e
`minmax(350px, 1fr)` (ações). Esse mínimo é absoluto: em celular de 360px de
largura não sobra espaço suficiente, o bloco fica mais largo que a tela e o
`overflow: hidden` da `section` **corta** o conteúdo em vez de rolar. O
`min(Xpx, 100%)` deixa a coluna encolher e resolve.
**Aplicado em:** só na galeria do Arraiá (`acoes/index.html`). As duas grades
antigas continuam com o defeito — corrigir exige testar telas e ainda não foi
autorizado. Serve de modelo para quando for.

### 29/07/2026 — Correção do vazamento do Supabase é por privilégio de coluna
**Motivo:** as tabelas `pagamentos_carteirinha` e `profissionais_saude` estavam
legíveis por qualquer pessoa com a chave `anon` (que é pública por natureza —
o problema nunca foi a chave, foram as regras). Simplesmente bloquear a leitura
quebraria o site: a carteirinha precisa consultar o status da doação e a área
da saúde precisa listar as profissionais. A solução é `REVOKE SELECT` na tabela
e `GRANT SELECT` **só nas colunas que o site realmente usa** — some a
`senha_acesso`, o telefone e o e-mail, e nada para de funcionar.
Fechar as escritas abertas é seguro porque **todas** as funções de escrita e de
login são `SECURITY DEFINER` (conferido uma a uma).
**Limite:** eu não tenho credencial do Supabase e não consigo executar. O SQL
pronto está na memória do projeto; só a Iara roda, no SQL Editor.
**Ainda aberto:** a senha do painel em texto puro em `painel/index.html:167` e
`painel/setup_supabase.sql:43`, os dois públicos no ar. Sai só tirando
`painel/` do repositório — depende de autorização explícita.

### 28/07/2026 — O site fala "doação", não "pagamento"
**Motivo:** o botão de baixar já dizia "Conferir e doar!" enquanto o de
verificar dizia "Já paguei". A página falava duas línguas. Trocamos os 10
textos visíveis de `carteirinha.html` e os 2 de `c.carteirinha.voluntario.html`
("Sem pagamento" → "Gratuita").
**Limite consciente:** só texto que a pessoa lê. Nomes de variável, IDs
(`verificarPagamentoBtn`), a tabela `pagamentos_carteirinha` do Supabase, o SDK
do Mercado Pago e as chaves de evento continuam com "pag" — mexer neles
quebraria a integração. Conferido um a um contra a versão publicada.
**Fora do alcance:** a tela do Mercado Pago continua dizendo "pagamento", e
isso não está no nosso controle.
**Não vale para:** `saude/` (ali "consulta paga" é a consulta que a paciente
paga à terapeuta da 9ª sessão em diante — não é doação), `produtos/` (texto
jurídico "não intermedeia pagamentos") e `painel/` (interno).

### 28/07/2026 — O token da Cloudflare vive numa variável de ambiente
**Motivo:** segredo colado no chat fica gravado no histórico e teria que ser
revogado. O token está em `CLOUDFLARE_API_TOKEN`, nunca escrito no repositório.
Zona `9643300d83ca240d3c4764c23bd744f1`; ruleset dos redirecionamentos
`488b470ce3064f23a8030cd7b92bec9c`. Usar sempre como `$CLOUDFLARE_API_TOKEN`
dentro do comando, sem imprimir o valor e sem `curl -v`.

### 28/07/2026 — Redirecionamentos vão para a Cloudflare, não para o repositório
**Motivo:** o `.htaccess` descreve 16 redirecionamentos e **nenhum** funciona
(GitHub Pages e Cloudflare não leem Apache). Páginas HTML de redirecionamento
resolveriam só parte: `/index.html` *é* a home, não dá para transformá-la em
redirecionamento sem derrubar o site — e HTML não devolve 301 de verdade.
A Cloudflare já está na frente do domínio, então não é dependência nova.
**Contrapartida aceita:** a configuração fica no painel, fora do Git; por isso
existe `docs/redirecionamentos.md` como registro.

### 28/07/2026 — URL oficial da carteirinha é `/carteirinha` (curta)
**Motivo:** escolha da Iara, por ser mais fácil de divulgar.
Implica: `canonical` e `og:url` de `carteirinha.html`, os links em `index.html`
e o `<loc>` do `sitemap.xml` apontam para a curta; a Cloudflare redireciona
`/carteirinha.html` e `/carteirinha/` para ela com 301.

### 28/07/2026 — Domínio `cdrmap.com.br` foi abandonado
**Motivo:** a CRMAP não tem mais o registro (confirmado pela Iara; o DNS já não
resolve). A regra de redirecionamento do `.htaccess` sai sem substituição.
Quem tiver link antigo já não chega ao site — isso é o estado atual, não uma
regressão.

### 28/07/2026 — Apagar conteúdo morto em vez de redirecionar
**Motivo:** `index_backup.html` (home antiga) e `crmap2/` (site antigo inteiro)
estavam **acessíveis no ar**. Apagar resolve de vez e não gasta regra da
Cloudflare. Vale também para `c.voluntario.html` e para o `.htaccess`.
