#!/bin/bash

# Ensure script is NOT run as root directly
if [ "$EUID" -eq 0 ]; then
  echo "[WARN] Do not run this script with sudo or as root directly."
  echo "[INFO] Run it as your normal user: ./fix-wifi.sh"
  exit 1
fi

LOGFILE="$HOME/wifi_fix_$(date +%Y%m%d_%H%M%S).log"

# Log function
log_msg() {
  local level="$1"
  local message="$2"
  echo "[$level] $(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOGFILE"
}

clear
echo "===================================================="
echo "    Manjaro NetworkManager iwd Wi-Fi Fix & Check    "
echo "===================================================="
echo "[WARN] DISCLAIMER: This script modifies system network"
echo "[WARN] configurations. I am not responsible for any"
echo "[WARN] broken connections or system instability."
echo "===================================================="
read -p "Do you wish to proceed? [Y/n]: " proceed
case "$proceed" in
  [yY][eE][sS]|[yY]|"")
    log_msg "INFO" "User accepted the disclaimer. Starting setup..."
    ;;
  *)
    echo "[INFO] Aborted by user."
    exit 0
    ;;
esac

# Step 1: Check and install iwd using package query commands
log_msg "INFO" "Checking if iwd package is installed..."
if pacman -Qi iwd &> /dev/null; then
  log_msg "INFO" "iwd is already installed."
else
  log_msg "WARN" "iwd is missing. Installing via pacman..."
  sudo pacman -S --noconfirm iwd >> "$LOGFILE" 2>&1
  if pacman -Qi iwd &> /dev/null; then
    log_msg "INFO" "Successfully installed iwd."
  else
    log_msg "WARN" "Failed to install iwd. Check your internet connection."
  fi
fi

# Step 2: Disable and mask wpa_supplicant to resolve conflict issues
log_msg "INFO" "Disabling and masking wpa_supplicant to prevent connection conflicts..."
sudo systemctl disable --now wpa_supplicant >> "$LOGFILE" 2>&1
sudo systemctl mask wpa_supplicant >> "$LOGFILE" 2>&1
if ! systemctl is-enabled wpa_supplicant &> /dev/null; then
  log_msg "INFO" "wpa_supplicant successfully disabled and masked."
else
  log_msg "WARN" "wpa_supplicant could not be fully disabled."
fi

# Step 3: Configure NetworkManager to use iwd backend
log_msg "INFO" "Creating NetworkManager backend configuration for iwd..."
sudo mkdir -p /etc/NetworkManager/conf.d
sudo tee /etc/NetworkManager/conf.d/wifi_backend.conf > /dev/null << 'EOF'
[device]
wifi.backend=iwd
EOF
log_msg "INFO" "Configuration written to /etc/NetworkManager/conf.d/wifi_backend.conf"

# Step 4: Enable iwd service and restart NetworkManager
log_msg "INFO" "Enabling iwd service and restarting NetworkManager..."
sudo systemctl enable --now iwd >> "$LOGFILE" 2>&1
sudo systemctl restart NetworkManager >> "$LOGFILE" 2>&1

if systemctl is-active --quiet NetworkManager && systemctl is-active --quiet iwd; then
  log_msg "INFO" "NetworkManager and iwd services are running properly."
else
  log_msg "WARN" "One or more network services failed to start cleanly."
fi

echo "--------------------------------------------------"
echo "[INFO] Fix applied successfully! Log saved to: $LOGFILE"
echo "--------------------------------------------------"

# Step 5: Reboot prompt
read -p "Would you like to reboot now? [Y/n]: " reboot_choice
case "$reboot_choice" in
  [yY][eE][sS]|[yY]|"")
    log_msg "INFO" "User chose to reboot. Rebooting system..."
    sudo reboot
    ;;
  *)
    echo "[INFO] Reboot skipped. Please remember to reboot manually later."
    log_msg "INFO" "User skipped reboot."
    ;;

esac

