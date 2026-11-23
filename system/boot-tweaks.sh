#!/usr/bin/env bash
# Ajustes de boot e login (rode você mesmo; pede sudo):
#   bash ~/work/dotfiles/system/boot-tweaks.sh             aplica os dois
#   bash ~/work/dotfiles/system/boot-tweaks.sh --undo-sddm volta o login para Xorg
#
# 1. systemd-boot sem espera no menu (timeout 0): ~5 s a menos no boot.
#    Para ver o menu quando precisar: segure Espaço logo ao ligar.
# 2. Tela de login (SDDM) em Wayland sobre o weston, sem Xorg: mesmo tema,
#    e o compositor do login fecha quando você entra no Hyprland (~65 MB).
#    Se a tela de login não abrir: Ctrl+Alt+F3, entre com usuário e senha e rode
#    este script com --undo-sddm (depois: sudo systemctl restart sddm).
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"

if [[ ${1:-} == --undo-sddm ]]; then
    sudo rm -f /etc/sddm.conf.d/20-wayland.conf
    echo "Login voltou para Xorg. Vale no próximo login (ou: sudo systemctl restart sddm — fecha a sessão!)."
    exit 0
fi

echo "==> 1. systemd-boot: menu sem espera"
L=/boot/loader/loader.conf
if sudo test -f "$L"; then
    sudo cp "$L" "$L.bak-$STAMP"
    if sudo grep -qE '^\s*timeout' "$L"; then sudo sed -i -E 's/^\s*timeout.*/timeout 0/' "$L"
    else echo "timeout 0" | sudo tee -a "$L" >/dev/null; fi
    sudo grep -E '^\s*timeout' "$L"
else
    echo "   (sem $L — o bootloader não é systemd-boot? pulei)"
fi

echo "==> 2. Login (SDDM) em Wayland com weston"
sudo pacman -S --needed --noconfirm weston
sudo install -Dm644 "$REPO/system/sddm-wayland/sddm-weston.ini" /etc/sddm-weston.ini
sudo install -Dm644 "$REPO/system/sddm.conf.d/20-wayland.conf" /etc/sddm.conf.d/20-wayland.conf

echo
echo "Pronto! O boot mais rápido e o login em Wayland valem a partir do próximo boot."
echo "Se a tela de login não abrir: Ctrl+Alt+F3 → entre → bash $REPO/system/boot-tweaks.sh --undo-sddm → sudo systemctl restart sddm"
