#!/usr/bin/env bash
# Data do último snapshot do restic (para o rodapé do desktop e a tela de bloqueio).
#   Lê RESTIC_REPOSITORY/RESTIC_PASSWORD do ~/.zshrc.local (fora do repo público).
#   Saída: "ok <epoch>" | "erro <motivo>"
#   Cacheia por 30 min em $XDG_RUNTIME_DIR para não acordar o repositório à toa.
set -uo pipefail
CACHE="${XDG_RUNTIME_DIR:-/tmp}/restic-last"
if [[ -f $CACHE && $(( $(date +%s) - $(stat -c %Y "$CACHE") )) -lt 1800 && ${1:-} != --force ]]; then
    cat "$CACHE"; exit 0
fi
# Só as linhas export RESTIC_* (não executa o resto do arquivo)
eval "$(grep -E '^export RESTIC_[A-Z_]+=' "$HOME/.zshrc.local" 2>/dev/null)"
if [[ -z ${RESTIC_REPOSITORY:-} ]]; then echo "erro sem-config"; exit 0; fi
t=$(timeout 60 restic snapshots --latest 1 --json --no-lock 2>/dev/null | jq -r 'max_by(.time) | .time // empty' 2>/dev/null)
if [[ -n $t ]]; then out="ok $(date -d "$t" +%s)"; else out="erro sem-resposta"; fi
echo "$out" | tee "$CACHE"
