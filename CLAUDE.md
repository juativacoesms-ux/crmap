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
