#!/usr/bin/env bash
# Boot eliasolie (Plymouth) + fonte de emoji + cursor lima na tela de login.
# Rode você mesmo (pede sudo):  bash ~/work/dotfiles/system/install-boot.sh
#
# O que faz (com backup de tudo que altera):
#   1. instala plymouth e noto-fonts-emoji
#   2. copia o tema system/plymouth/eliasolie e define como padrão (sem atraso)
#   3. coloca o hook "plymouth" no mkinitcpio, logo depois de "udev"
#   4. adiciona "quiet splash" nas entradas do systemd-boot (/boot/loader/entries)
#   5. regera o initramfs
#   6. copia o Eliasolie-Cursor para /usr/share/icons e aponta o SDDM para ele
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"

echo "==> Pacotes"
sudo pacman -S --needed --noconfirm plymouth noto-fonts-emoji

echo "==> Tema Plymouth"
sudo install -d /usr/share/plymouth/themes/eliasolie
sudo install -m644 "$REPO"/system/plymouth/eliasolie/* /usr/share/plymouth/themes/eliasolie/
sudo install -d /etc/plymouth
printf '[Daemon]\nTheme=eliasolie\nShowDelay=0\n' | sudo tee /etc/plymouth/plymouthd.conf >/dev/null

echo "==> mkinitcpio: hook plymouth"
if ! grep -qE '^HOOKS=.*\bplymouth\b' /etc/mkinitcpio.conf; then
    sudo cp /etc/mkinitcpio.conf "/etc/mkinitcpio.conf.bak-$STAMP"
    sudo sed -i -E '/^HOOKS=/ s/\budev\b/udev plymouth/' /etc/mkinitcpio.conf
fi
grep -E '^HOOKS=' /etc/mkinitcpio.conf

echo "==> systemd-boot: quiet splash"
for e in /boot/loader/entries/*.conf; do
    [[ -e $e ]] || continue
    sudo cp "$e" "$e.bak-$STAMP"
    sudo sed -i -E '/^options/ { /(^|\s)quiet(\s|$)/! s/$/ quiet/ }' "$e"
    sudo sed -i -E '/^options/ { /(^|\s)splash(\s|$)/! s/$/ splash/ }' "$e"
    echo "   $(basename "$e"): $(grep -E '^options' "$e" | sed 's/root=[^ ]*/root=…/')"
done

echo "==> Regerando initramfs (demora um pouco)"
sudo mkinitcpio -P

echo "==> Cursor lima na tela de login (SDDM)"
if [[ -d $HOME/.local/share/icons/Eliasolie-Cursor ]]; then
    sudo cp -r "$HOME/.local/share/icons/Eliasolie-Cursor" /usr/share/icons/
    sudo sed -i 's/^CursorTheme=.*/CursorTheme=Eliasolie-Cursor/' /etc/sddm.conf.d/10-eliasolie.conf 2>/dev/null || true
fi

echo
echo "Pronto! O tema aparece no próximo boot."
echo "Prévia agora (5 s, Ctrl+Alt+F2 se travar):  sudo plymouthd; sudo plymouth --show-splash; sleep 5; sudo plymouth quit"
