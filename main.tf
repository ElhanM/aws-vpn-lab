terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
}

# --- 1. Networking & Security ---
data "aws_vpc" "default" {
  default = true
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_subnet" "default_subnet" {
  count                   = length(data.aws_subnets.default.ids) == 0 ? 1 : 0
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.0.0/20"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "vpn-lab-default-subnet"
  }
}

resource "aws_security_group" "vpn_sg" {
  name        = "wireguard-vpn-security-group"
  description = "Allow WireGuard VPN and SSH traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  ingress {
    from_port   = var.vpn_port
    to_port     = var.vpn_port
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "WireGuard VPN"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wireguard-vpn-sg"
  }
}

# --- 2. SSH Key Generation ---
resource "tls_private_key" "vpn_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "random_id" "key_suffix" {
  byte_length = 4
}

resource "aws_key_pair" "generated_key" {
  key_name   = "vpn-lab-key-${random_id.key_suffix.hex}"
  public_key = tls_private_key.vpn_key.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.vpn_key.private_key_pem
  filename        = "${path.module}/generated_key.pem"
  file_permission = "0400"
}

# --- 3. AMI Selection ---
data "aws_ami" "ubuntu_ami" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- 4. VPN Server Instance ---
resource "aws_instance" "vpn_instance" {
  ami           = data.aws_ami.ubuntu_ami.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.generated_key.key_name
  
  vpc_security_group_ids = [aws_security_group.vpn_sg.id]
  subnet_id              = length(data.aws_subnets.default.ids) > 0 ? data.aws_subnets.default.ids[0] : aws_subnet.default_subnet[0].id

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/wireguard-setup.sh", {
    vpn_port    = var.vpn_port
    max_clients = var.max_clients
  })

  tags = {
    Name = "WireGuard-VPN-Server"
  }
}

# --- 5. Generate WireGuard Keys Locally and Client Configs ---
resource "null_resource" "generate_wg_keys" {
  # Trigger recreation when instance changes
  triggers = {
    instance_id = aws_instance.vpn_instance.id
  }

  # Wait for instance to be ready
  provisioner "local-exec" {
    command = "sleep 90"
  }

  # Fetch server public key and generate client configs
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      mkdir -p vpn-configs
      
      # Wait for server to be fully ready
      max_attempts=30
      attempt=0
      while [ $attempt -lt $max_attempts ]; do
        if ssh -i ${local_file.private_key.filename} \
               -o StrictHostKeyChecking=no \
               -o ConnectTimeout=5 \
               ubuntu@${aws_instance.vpn_instance.public_ip} \
               "test -f /etc/wireguard/server_public.key" 2>/dev/null; then
          break
        fi
        echo "Waiting for WireGuard server setup... ($attempt/$max_attempts)"
        sleep 10
        attempt=$((attempt + 1))
      done
      
      # Fetch server public key
      SERVER_PUBLIC_KEY=$(ssh -i ${local_file.private_key.filename} \
                              -o StrictHostKeyChecking=no \
                              ubuntu@${aws_instance.vpn_instance.public_ip} \
                              "cat /etc/wireguard/server_public.key")
      
      # Generate client configurations
      for i in $(seq 1 ${var.max_clients}); do
        # Generate client private key
        CLIENT_PRIVATE_KEY=$(wg genkey)
        CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)
        
        # Create client config file
        cat > vpn-configs/client$i.conf <<EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = 10.8.0.$((i + 1))/24
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = ${aws_instance.vpn_instance.public_ip}:${var.vpn_port}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF
        chmod 600 vpn-configs/client$i.conf
        
        # Add client public key to server
        ssh -i ${local_file.private_key.filename} \
            -o StrictHostKeyChecking=no \
            ubuntu@${aws_instance.vpn_instance.public_ip} \
            "echo '[Peer]' | sudo tee -a /etc/wireguard/wg0.conf && \
             echo 'PublicKey = $CLIENT_PUBLIC_KEY' | sudo tee -a /etc/wireguard/wg0.conf && \
             echo 'AllowedIPs = 10.8.0.$((i + 1))/32' | sudo tee -a /etc/wireguard/wg0.conf && \
             echo '' | sudo tee -a /etc/wireguard/wg0.conf"
      done
      
      # Restart WireGuard to apply changes
      ssh -i ${local_file.private_key.filename} \
          -o StrictHostKeyChecking=no \
          ubuntu@${aws_instance.vpn_instance.public_ip} \
          "sudo systemctl restart wg-quick@wg0"
      
      echo "WireGuard client configurations generated successfully!"
    EOT
  }

  depends_on = [aws_instance.vpn_instance]
}

# --- 6. Create README in vpn-configs ---
resource "local_file" "vpn_configs_readme" {
  filename = "${path.module}/vpn-configs/README.txt"
  content  = <<-EOT
    WireGuard VPN Client Configurations
    ====================================
    
    This directory contains WireGuard configuration files for your devices.
    
    Security Notes:
    - Each file is for ONE device only
    - Do NOT share config files between devices
    - Treat these files like passwords/private keys
    - Each device gets its own unique tunnel
    
    Available Configurations:
    ${join("\n", [for i in range(var.max_clients) : "- client${i + 1}.conf - Device ${i + 1}"])}
    
    Usage:
    - Linux: Use connect-vpn.sh script or manually with 'wg-quick up ./vpn-configs/client1.conf'
    - Android: Import the .conf file in the WireGuard app
    
    Server IP: ${aws_instance.vpn_instance.public_ip}
    VPN Network: 10.8.0.0/24
  EOT

  file_permission = "0644"
  
  depends_on = [null_resource.generate_wg_keys]
}