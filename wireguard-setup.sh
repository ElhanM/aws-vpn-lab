#!/bin/bash
set -e

exec > >(tee /var/log/wireguard-setup.log)
exec 2>&1

echo "=== WireGuard VPN Server Setup ==="
echo "Started at: $(date)"

# Update system
echo "Updating system packages..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install WireGuard
echo "Installing WireGuard..."
apt-get install -y wireguard iptables

# Enable IP forwarding
echo "Enabling IP forwarding..."
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
sysctl -p

# Generate server keys
echo "Generating WireGuard server keys..."
wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
chmod 600 /etc/wireguard/server_private.key
chmod 644 /etc/wireguard/server_public.key

SERVER_PRIVATE_KEY=$(cat /etc/wireguard/server_private.key)
SERVER_PUBLIC_KEY=$(cat /etc/wireguard/server_public.key)

# Get network interface
NET_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

# Create WireGuard server configuration
echo "Creating WireGuard server configuration..."
cat > /etc/wireguard/wg0.conf << EOF
[Interface]
Address = 10.8.0.1/24
ListenPort = ${vpn_port}
PrivateKey = $SERVER_PRIVATE_KEY

# NAT and forwarding rules
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $NET_INTERFACE -j MASQUERADE; ip6tables -A FORWARD -i wg0 -j ACCEPT; ip6tables -t nat -A POSTROUTING -o $NET_INTERFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $NET_INTERFACE -j MASQUERADE; ip6tables -D FORWARD -i wg0 -j ACCEPT; ip6tables -t nat -D POSTROUTING -o $NET_INTERFACE -j MASQUERADE

EOF

# Set permissions
chmod 600 /etc/wireguard/wg0.conf

# Enable and start WireGuard
echo "Starting WireGuard service..."
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# Create status script
cat > /usr/local/bin/vpn-status << 'STATUSEOF'
#!/bin/bash
echo "=== WireGuard VPN Status ==="
echo "Server Public Key: $(cat /etc/wireguard/server_public.key)"
echo ""
wg show
echo ""
echo "Active connections: $(wg show wg0 peers 2>/dev/null | wc -l || echo 0)"
STATUSEOF

chmod +x /usr/local/bin/vpn-status

echo "=== WireGuard VPN Server Setup Complete ==="
echo "Server Public Key: $SERVER_PUBLIC_KEY"
echo "Completed at: $(date)"

# Create ready flag
touch /var/lib/cloud/instance/vpn-ready