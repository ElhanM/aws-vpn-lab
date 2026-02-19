#!/bin/bash
set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Check if WireGuard is installed
if ! command -v wg &> /dev/null; then
    echo "WireGuard is not installed!"
    echo "Install it with:"
    echo "  sudo apt update"
    echo "  sudo apt install wireguard wireguard-tools"
    exit 1
fi

# Default to client1 config
CONFIG_FILE="${1:-vpn-configs/client1.conf}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file not found: $CONFIG_FILE"
    echo "Available configurations:"
    ls -1 vpn-configs/*.conf 2>/dev/null || echo "  No configurations found. Run 'terraform apply' first."
    exit 1
fi

# Extract interface name from config file (basename without .conf extension)
INTERFACE_NAME=$(basename "$CONFIG_FILE" .conf)

# Check if already connected
if wg show "$INTERFACE_NAME" &>/dev/null; then
    echo "VPN is already connected!"
    echo "Current status:"
    wg show "$INTERFACE_NAME"
    echo ""
    read -p "Disconnect and reconnect? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Disconnecting..."
        wg-quick down "$CONFIG_FILE" 2>/dev/null || true
        sleep 1
    else
        exit 0
    fi
fi

echo "============================================================"
echo "             AWS VPN Lab - Connecting to VPN                "
echo "============================================================"
echo "Using configuration: $CONFIG_FILE"
echo "Interface name:      $INTERFACE_NAME"
echo ""

# Connect to VPN
echo "Establishing VPN connection..."
wg-quick up "$CONFIG_FILE"

# Wait a moment for connection to establish
sleep 2

echo ""
echo "VPN Connected Successfully!"
echo ""
echo "Connection Details:"
wg show "$INTERFACE_NAME"

# Get and display public IP
echo ""
echo "Your public IP address:"
PUBLIC_IP=$(curl -s ifconfig.me || echo "Unable to fetch")
echo "$PUBLIC_IP"

echo ""
echo "------------------------------------------------------------"
echo "VPN is now active!"
echo "All your internet traffic is now encrypted and routed through AWS."
echo ""
echo "To disconnect, press Ctrl+C or run:"
echo "  sudo wg-quick down $CONFIG_FILE"
echo "------------------------------------------------------------"

# Trap Ctrl+C to gracefully disconnect
trap "echo ''; echo 'Disconnecting VPN...'; wg-quick down '$CONFIG_FILE'; echo 'VPN Disconnected'; exit 0" INT TERM

# Keep script running
echo "Press Ctrl+C to disconnect..."
while true; do
    sleep 1
done