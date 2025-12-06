output "vpn_server_ip" {
  description = "The public IP address of the VPN server"
  value       = aws_instance.vpn_instance.public_ip
}

output "vpn_server_region" {
  description = "The AWS region where the VPN server is deployed"
  value       = var.aws_region
}

output "vpn_port" {
  description = "WireGuard VPN port"
  value       = var.vpn_port
}

output "connection_instructions" {
  description = "Instructions for connecting to the VPN"
  value       = <<-EOT
╔════════════════════════════════════════════════════════════╗
║           AWS VPN Lab - Ready to Connect! 🔐               ║
╚════════════════════════════════════════════════════════════╝

VPN Server IP: ${aws_instance.vpn_instance.public_ip}
Region: ${var.aws_region}
Instance Type: ${var.instance_type}

⚡ NEXT STEPS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📁 Client configurations generated in: ./vpn-configs/

🖥️  LINUX/DESKTOP CONNECTION:
   Run the connection script:
   
   ./connect-vpn.sh

   Or manually:
   sudo wg-quick up ./vpn-configs/client1.conf

📱 MOBILE DEVICES (Android):
   1. Install WireGuard app from Play Store
   2. Transfer vpn-configs/client2.conf to your device
   3. Import the config file in the app
   4. Toggle VPN on

✅ VERIFY CONNECTION:
   curl ifconfig.me  # Should show: ${aws_instance.vpn_instance.public_ip}
   sudo wg show      # Shows WireGuard status

🔒 SECURITY:
   • Each device has a unique config file
   • Never share config files between devices
   • Configs are in vpn-configs/ (gitignored)

⚠️  REMEMBER TO DESTROY:
   When finished, run: terraform destroy
   (Use same variables as terraform apply)

EOT
}

output "available_configs" {
  description = "List of generated client configuration files"
  value       = [for i in range(var.max_clients) : "vpn-configs/client${i + 1}.conf"]
}