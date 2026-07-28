#!/bin/bash
# Trava mecânica de publicação — CRMAP
#
# Roda como hook PreToolUse do Claude Code, em toda chamada de Bash.
# Se o comando não for "git push", sai calado e não atrapalha nada.
# Se for, faz 4 verificações. Qualquer uma que falhe BLOQUEIA o push.
#
# Testar à mão:
#   echo '{"tool_input":{"command":"git push"}}' | .claude/hooks/verificar-antes-do-push.sh

set -uo pipefail

ENTRADA=$(cat)
COMANDO=$(printf '%s' "$ENTRADA" | jq -r '.tool_input.command // ""' 2>/dev/null)

# Não é push? Libera na hora, sem custo.
case "$COMANDO" in
  *push*) ;;
  *) exit 0 ;;
esac
printf '%s' "$COMANDO" | grep -qE '(^|[;&|[:space:]])git([[:space:]]+-[^[:space:]]+)*[[:space:]]+push' || exit 0

REPO="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$REPO" 2>/dev/null || exit 0

negar() {
  jq -nc --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

# ---------------------------------------------------------------- 1. force push
if printf '%s' "$COMANDO" | grep -qE '(--force|--force-with-lease|(^|[[:space:]])-[a-zA-Z]*f)'; then
  negar "BLOQUEADO: git push --force é proibido neste projeto (regra inviolável do CLAUDE.md). Não existe exceção. Se o histórico precisa mudar, converse com a Iara antes."
fi

# ------------------------------------------------- 2. mudança sem commit no ar
SUJO=$(git status --porcelain --untracked-files=no 2>/dev/null)
if [ -n "$SUJO" ]; then
  negar "BLOQUEADO: existe alteração sem commit. Publicar agora deixaria o site e o repositório fora de sincronia.

Arquivos alterados e não commitados:
$SUJO

Faça o commit (ou descarte) antes de publicar."
fi

# -------------------------------------------- 3. link interno quebrado no site
QUEBRADOS=""
for f in index.html carteirinha.html c.carteirinha.voluntario.html \
         acoes/index.html produtos/index.html terreno/index.html \
         saude/index.html saude/controle/index.html painel/index.html; do
  [ -f "$f" ] || continue
  dir=$(dirname "$f")
  while read -r ref; do
    [ -n "$ref" ] || continue
    limpo="${ref%%\?*}"; limpo="${limpo%%#*}"
    [ -n "$limpo" ] || continue
    if [ "${limpo#/}" != "$limpo" ]; then alvo=".${limpo}"; else alvo="$dir/$limpo"; fi
    if [ ! -e "$alvo" ] && [ ! -e "${alvo%/}/index.html" ] && [ ! -e "${alvo}.html" ]; then
      QUEBRADOS="${QUEBRADOS}  $f  ->  $ref"$'\n'
    fi
  done < <(grep -oE '(href|src)="[^"#$]+"' "$f" 2>/dev/null \
             | sed -E 's/^(href|src)="//; s/"$//' \
             | grep -vE '^(https?:|mailto:|tel:|data:|//|#)' | sort -u)
done
if [ -n "$QUEBRADOS" ]; then
  negar "BLOQUEADO: há link interno apontando para arquivo que não existe. Publicar assim coloca link quebrado no ar.

$QUEBRADOS
Corrija os caminhos ou crie os arquivos que faltam."
fi

# ------------------------------------------------- 4. selo de verificação
SELO="$REPO/.claude/push-ok"
CABECA=$(git rev-parse HEAD 2>/dev/null)
SELADO=$(cat "$SELO" 2>/dev/null | tr -d '[:space:]')

if [ "$SELADO" != "$CABECA" ]; then
  negar "BLOQUEADO: este commit ainda não foi verificado.

Regra inviolável do CLAUDE.md — antes de publicar é preciso, NESTA ORDEM:
  1. mostrar o git diff completo
  2. revisar cada arquivo alterado procurando erro
  3. testar o que foi afetado
  4. só então publicar

Feito isso, liberar com:
  git rev-parse HEAD > .claude/push-ok

O selo vale só para o commit ${CABECA:0:8}. Qualquer commit novo exige
verificar de novo. Não crie o selo antes de realmente ter testado — ele
existe para deixar registro de que a verificação aconteceu."
fi

exit 0
