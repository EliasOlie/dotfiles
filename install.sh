#!/usr/bin/env bash
# dotfiles eliasolie — instala o ricing numa máquina Arch + Hyprland (config em Lua, 0.57+)
#
#   ./install.sh            liga os arquivos de home/ no $HOME (com backup do que já existir)
#   ./install.sh --packages instala os pacotes de packages.txt (pacman) antes
#   ./install.sh --system   instala também o tema do SDDM e a fonte Archivo no sistema (sudo)
#   ./install.sh --all      tudo acima
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
REPO="$PWD"
STAMP="$(date +%Y%m%d-%H%M%S)"

want_pkgs=0; want_sys=0
for a in "$@"; do
  case "$a" in
    --packages) want_pkgs=1 ;;
    --system)   want_sys=1 ;;
    --all)      want_pkgs=1; want_sys=1 ;;
    -h|--help)  sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "opção desconhecida: $a" >&2; exit 1 ;;
  esac
done

if (( want_pkgs )); then
  echo "==> Pacotes"
  grep -vE '^\s*(#|$)' packages.txt | xargs sudo pacman -S --needed --noconfirm
fi

echo "==> Links em \$HOME"
while IFS= read -r -d '' src; do
  rel="${src#"$REPO/home/"}"
  dst="$HOME/$rel"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$src" ]; then continue; fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then mv "$dst" "$dst.bak-$STAMP"; echo "   backup: ~/$rel.bak-$STAMP"; fi
  ln -s "$src" "$dst"; echo "   ~/$rel"
done < <(find "$REPO/home" -type f -print0)
chmod +x "$REPO"/home/.config/hypr/scripts/*.sh

echo "==> Fonte Archivo (Google Fonts, OFL)"
F="$HOME/.local/share/fonts/Archivo"
if [ ! -f "$F/Archivo[wdth,wght].ttf" ]; then
  mkdir -p "$F"
  curl -fsSL -o "$F/Archivo[wdth,wght].ttf"        'https://github.com/google/fonts/raw/main/ofl/archivo/Archivo%5Bwdth%2Cwght%5D.ttf'
  curl -fsSL -o "$F/Archivo-Italic[wdth,wght].ttf" 'https://github.com/google/fonts/raw/main/ofl/archivo/Archivo-Italic%5Bwdth%2Cwght%5D.ttf'
  curl -fsSL -o "$F/OFL.txt"                       'https://github.com/google/fonts/raw/main/ofl/archivo/OFL.txt'
  fc-cache -f "$HOME/.local/share/fonts" >/dev/null
fi

echo "==> Preferências GTK (gsettings)"
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita'
gsettings set org.gnome.desktop.interface font-name 'Archivo 10'
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 10'

if (( want_sys )); then
  echo "==> Sistema: fonte Archivo e tema do SDDM (sudo)"
  sudo install -Dm644 -t /usr/local/share/fonts/Archivo "$F"/*
  sudo fc-cache -f /usr/local/share/fonts >/dev/null
  sudo rm -rf /usr/share/sddm/themes/eliasolie
  sudo cp -r "$REPO/system/sddm/eliasolie" /usr/share/sddm/themes/eliasolie
  sudo install -Dm644 "$REPO/system/sddm.conf.d/10-eliasolie.conf" /etc/sddm.conf.d/10-eliasolie.conf
fi

if command -v rbw >/dev/null; then
  rbw config set pinentry pinentry-qt >/dev/null || true
  rbw config set lock_timeout 3600 >/dev/null || true
fi

echo
echo "Pronto. Se o Hyprland estiver aberto: hyprctl reload"
echo "No .zshrc, use: ZSH_THEME=\"eliasolie\""
