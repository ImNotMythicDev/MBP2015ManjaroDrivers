#!/bin/bash
set -e

if [ "$EUID" -eq 0 ]; then
    echo "Do not run this script with sudo. Run it as a normal user."
    exit 1
fi

KERNEL_PKG="linux$(uname -r | cut -d. -f1,2 | tr -d '.')"

sudo pacman -Syu --noconfirm \
    "${KERNEL_PKG}-headers" \
    "${KERNEL_PKG}-broadcom-wl" \
    "${KERNEL_PKG}-virtualbox-host-modules" \
    iwd \
    libva-mesa-driver \
    libva-intel-driver \
    intel-media-driver \
    vulkan-intel \
    v4l2loopback-dkms \
    obs-studio \
    virtualbox \
    fakeroot \
    base-devel

echo -e "[device]\nwifi.backend=iwd" | sudo tee /etc/NetworkManager/conf.d/wifi_backend.conf > /dev/null

sudo tee /etc/modprobe.d/broadcom.conf > /dev/null <<EOF
blacklist b43
blacklist b43legacy
blacklist bcm43xx
blacklist bcma
blacklist brcm80211
blacklist brcmfmac
blacklist brcmsmac
blacklist ssb
EOF

echo "wl" | sudo tee /etc/modules-load.d/broadcom.conf > /dev/null

sudo systemctl enable --now iwd
sudo systemctl disable --now wpa_supplicant 2>/dev/null || true
sudo systemctl mask wpa_supplicant
sudo systemctl enable --now NetworkManager
sudo systemctl restart NetworkManager

sudo usermod -aG vboxusers "$USER"
sudo modprobe wl 2>/dev/null || true
sudo modprobe vboxdrv 2>/dev/null || true
sudo modprobe v4l2loopback 2>/dev/null || true

if command -v yay &> /dev/null; then
    yay -S --noconfirm --needed facetimehd-firmware mbpfan-git virtualbox-ext-oracle
    sudo systemctl enable --now mbpfan
fi

echo "Setup completed successfully. Please reboot your system."

