#!/usr/bin/env bash
# Bitwarden/Vaultwarden (rbw) pelo rofi — credenciais e notas. Ver bitwarden.py.
#   bitwarden.sh        lista (Super+Shift+P)     bitwarden.sh totp   copia TOTP (Super+Alt+P)
exec "$HOME/.config/hypr/scripts/bitwarden.py" "$@"
