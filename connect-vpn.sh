#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Check if WireGuard is installed
if ! command -v wg &> /dev/null; then
    echo -e "${RED}WireGuard is not installed!${NC}"
    echo -e "${YELLOW}Install it with:${NC}"
    echo "  sudo apt update"
    echo "  sudo apt install wireguard wireguard-tools"
    exit 1
fi

# Default to client1 config
CONFIG_FILE="${1:-vpn-configs/client1.conf}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Configuration file not found: $CONFIG_FILE${NC}"
    echo -e "${YELLOW}Available configurations:${NC}"
    ls -1 vpn-configs/*.conf 2>/dev/null || echo "  No configurations found. Run 'terraform apply' first."
    exit 1
fi

# Extract interface name from config file (basename without .conf extension)
INTERFACE_NAME=$(basename "$CONFIG_FILE" .conf)

# Check if already connected
if wg show "$INTERFACE_NAME" &>/dev/null; then
    echo -e "${YELLOW}VPN is already connected!${NC}"
    echo -e "${CYAN}Current status:${NC}"
    wg show "$INTERFACE_NAME"
    echo ""
    read -p "Disconnect and reconnect? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Disconnecting...${NC}"
        wg-quick down "$CONFIG_FILE" 2>/dev/null || true
        sleep 1
    else
        exit 0
    fi
fi

echo -e "${BLUE}|============================================================|${NC}"
echo -e "${BLUE}|            AWS VPN Lab - Connecting to VPN                 |${NC}"
echo -e "${BLUE}|============================================================|${NC}"
echo -e "${CYAN}Using configuration: $CONFIG_FILE${NC}"
echo -e "${CYAN}Interface name: $INTERFACE_NAME${NC}"
echo ""

# Connect to VPN
echo -e "${YELLOW}Establishing VPN connection...${NC}"
wg-quick up "$CONFIG_FILE"

# Wait a moment for connection to establish
sleep 2

# Show status
echo ""
echo -e "${GREEN}✓ VPN Connected Successfully!${NC}"
echo ""
echo -e "${CYAN}Connection Details:${NC}"
wg show "$INTERFACE_NAME"

# Get and display public IP
echo ""
echo -e "${CYAN}Your public IP address:${NC}"
PUBLIC_IP=$(curl -s ifconfig.me || echo "Unable to fetch")
echo -e "${GREEN}$PUBLIC_IP${NC}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}VPN is now active!${NC}"
echo -e "${YELLOW}All your internet traffic is now encrypted and routed through AWS.${NC}"
echo ""
echo -e "${CYAN}To disconnect, press Ctrl+C or run:${NC}"
echo -e "  sudo wg-quick down $CONFIG_FILE"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Trap Ctrl+C to gracefully disconnect
trap "echo ''; echo -e '${YELLOW}Disconnecting VPN...${NC}'; wg-quick down '$CONFIG_FILE'; echo -e '${GREEN}✓ VPN Disconnected${NC}'; exit 0" INT TERM

# Keep script running
echo -e "${CYAN}Press Ctrl+C to disconnect...${NC}"
while true; do
    sleep 1
done