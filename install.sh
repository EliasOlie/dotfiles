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
  if command -v yay >/dev/null; then
    grep -vE '^\s*(#|$)' packages-aur.txt | xargs yay -S --needed --noconfirm
  else
    echo "   (yay não encontrado: instale à mão os pacotes de packages-aur.txt)"
  fi
fi

echo "==> oh-my-zsh + plugins"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
fi
ZC="$HOME/.oh-my-zsh/custom/plugins"
for p in zsh-users/zsh-autosuggestions zsh-users/zsh-completions zsh-users/zsh-syntax-highlighting; do
  [ -d "$ZC/${p#*/}" ] || git clone --depth=1 "https://github.com/$p" "$ZC/${p#*/}"
done
[ -f "$HOME/.zshrc.local" ] || { umask 077; echo "# Segredos e ajustes desta máquina (fora do git)" > "$HOME/.zshrc.local"; }

echo "==> Links em \$HOME"
# Pastas linkadas inteiras (o Neovim grava o nvim-pack-lock.json dentro da própria config)
for d in .config/nvim; do
  if [ "$(readlink -f "$HOME/$d")" != "$REPO/home/$d" ]; then
    [ -e "$HOME/$d" ] && mv "$HOME/$d" "$HOME/$d.bak-$STAMP"
    mkdir -p "$(dirname "$HOME/$d")"; ln -sfn "$REPO/home/$d" "$HOME/$d"; echo "   ~/$d/"
  fi
done
while IFS= read -r -d '' src; do
  rel="${src#"$REPO/home/"}"
  dst="$HOME/$rel"
  mkdir -p "$(dirname "$dst")"
  if [ "$(readlink -f "$dst")" = "$src" ]; then continue; fi   # já aponta pro repo (link direto ou pasta linkada)
  if [ -e "$dst" ] || [ -L "$dst" ]; then mv "$dst" "$dst.bak-$STAMP"; echo "   backup: ~/$rel.bak-$STAMP"; fi
  ln -s "$src" "$dst"; echo "   ~/$rel"
done < <(find "$REPO/home" -type f -print0)
chmod +x "$REPO"/home/.config/hypr/scripts/*.sh
chmod +x "$REPO"/home/.local/bin/* 2>/dev/null || true
# AppImages de ~/AppImages no lançador (vigia a pasta)
systemctl --user daemon-reload && systemctl --user enable --now appimages-sync.path >/dev/null 2>&1 || true

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
# Cursor Eliasolie (Bibata Modern com borda lima), gerado a partir do fonte do Bibata
if [[ ! -d $HOME/.local/share/icons/Eliasolie-Cursor ]]; then
  tmp=$(mktemp -d); git clone -q --depth 1 https://github.com/ful1e5/Bibata_Cursor.git "$tmp/bibata" \
    && python3 "$REPO/rice/gen-cursor.py" "$tmp/bibata" >/dev/null; rm -rf "$tmp"
fi
gsettings set org.gnome.desktop.interface cursor-theme 'Eliasolie-Cursor'
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
