#!/usr/bin/env bash
# Bitwarden/Vaultwarden via rbw + rofi-rbw
#   bitwarden.sh        -> escolhe item e DIGITA usuário/senha na janela ativa
#   bitwarden.sh totp   -> escolhe item e copia o código TOTP (clipboard limpa sozinho)
set -u
pkill -x rofi && exit 0

note() { notify-send -a bitwarden "Bitwarden" "$1" 2>/dev/null; }

if ! rbw config show 2>/dev/null | grep -q '"base_url": *"http'; then
  note "rbw ainda não configurado. No terminal: rbw config set base_url https://SEU-VAULTWARDEN && rbw config set email SEU@EMAIL && rbw login"
  exit 1
fi

# Desbloqueia (abre o pinentry) se o cofre estiver trancado
rbw unlocked 2>/dev/null || rbw unlock || { note "Cofre continua trancado"; exit 1; }

# Ajuda própria no rodapé da janela: curta, leve, em minúsculas
k() { printf "<span foreground='#C8F031'>%s</span> %s" "$1" "$2"; }
SEP="<span foreground='#2A2A27'>  ·  </span>"
HELP="<span font_size='small' foreground='#8A8A84'>$(k '↵' digitar)$SEP$(k 'alt u' usuário)$SEP$(k 'alt p' senha)$SEP$(k 'alt t' totp)$SEP$(k 'alt m' mais)</span>"
THEME='mainbox { children: [ inputbar, listview, message ]; } message { padding: 10px 0 0 0; border: 1px 0 0 0; border-color: #2A2A27; } textbox { horizontal-align: 0.5; }'

case "${1:-}" in
  totp) exec rofi-rbw --action copy --target totp --clear-after 30 ;;
  *)    exec rofi-rbw --no-help --selector-args "-mesg \"$HELP\" -theme-str '$THEME'" ;;
esac
