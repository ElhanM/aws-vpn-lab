# AWS VPN Lab 🔐

This repository contains **Infrastructure as Code (Terraform)** to spin up a personal, on-demand WireGuard VPN server on AWS. Deploy your own private VPN in minutes and pay only when you use it.

## 🎯 Project Goal & Architecture

To create a **"dispose-on-demand"** VPN solution. We use Terraform to automate the creation and destruction of infrastructure, ensuring you only pay for resources while they are in use.

**🔒 Security & Privacy**

  * **Your Own VPN:** Complete control over your VPN server - no third-party logging.
  * **WireGuard Protocol:** Modern, fast, and secure VPN protocol.
  * **Encrypted Traffic:** All your internet traffic is encrypted and routed through AWS.
  * **No Data Retention:** Destroy the server when done - no logs, no traces.

## 🚧 Step 1: AWS Account Setup

### 1.1 Create an IAM User

**⚠️ Important:** Do NOT use root user access keys.

1.  Log into AWS Console and search for **IAM**.
2.  Click **Users** -> **Create user**.
3.  Set username: `terraform-deployer`.
4.  Select **Attach policies directly**.
5.  Search and check: **AdministratorAccess**.
6.  Click **Next** -> **Create user**.

### 1.2 Create Access Keys

1.  Click your new user (`terraform-deployer`).
2.  Go to **Security credentials** -> **Access keys** -> **Create access key**.
3.  Select **Command Line Interface (CLI)**.
4.  Check the confirmation box and click **Next**.
5.  Click **Create access key**.
6.  **Download the CSV** or copy the **Access Key ID** and **Secret Access Key**.

### 1.3 Configure Credentials

Create a file named `terraform.tfvars` in the project root.

```bash
cat > terraform.tfvars << 'EOF'
aws_access_key_id     = "AKIA..."  # Replace with your Access Key ID
aws_secret_access_key = "your-secret-access-key-here"
EOF
```

*Note: `terraform.tfvars` is ignored by Git to prevent accidental commits.*

## 💻 Server Selection

### VPN Server Options

All VPN traffic runs on lightweight instances - no GPU needed.

| Instance Type | vCPUs | RAM | Cost/Hour | Best For |
|---------------|-------|-----|-----------|----------|
| `t3.micro` (Default) | 2 | 1GB | ~$0.01 | Personal use, 1-2 devices |
| `t3.small` | 2 | 2GB | ~$0.02 | Family use, 3-5 devices |
| `t3.medium` | 2 | 4GB | ~$0.04 | Heavy usage, 5+ devices |

**Default Configuration:** `t3.micro` is perfect for most personal VPN needs and costs approximately **$7.20/month** if left running 24/7, or just **$0.24/day** for occasional use.

## 🌍 Region Selection

Choose a region close to you for best performance, or far from you for geo-spoofing. The default is **N. Virginia (us-east-1)**.

## 🔧 VPN Configuration

The VPN server supports:

  * **Multiple Devices:** Connect phones, laptops, tablets simultaneously.
  * **WireGuard Protocol:** Fast, secure, battery-efficient.
  * **Split Tunneling:** Optional - route only specific traffic through VPN.
  * **Kill Switch:** Automatically blocks traffic if VPN disconnects.

## 🚀 Usage

### 1. Initialize

```bash
terraform init
```

### 2. Deploy Your VPN Server

Select your preferences and deploy:

```bash
# Default (t3.micro in us-east-1)
terraform apply

# Custom region
terraform apply -var="aws_region=eu-west-2"

# Larger instance for family use
terraform apply -var="instance_type=t3.small"
```

Type `yes` when prompted.

### 3. Get Your VPN Configuration

After deployment completes, Terraform will output:

  * **Server IP address**
  * **WireGuard configuration file** (automatically generated)
  * **QR code** for mobile devices

### 4. Connect Your Devices

**For Desktop (Windows/Mac/Linux):**

1.  Install WireGuard: [wireguard.com/install](https://www.wireguard.com/install/)
2.  Import the generated configuration file
3.  Activate the tunnel

**For Mobile (iOS/Android):**

1.  Install WireGuard app from App Store/Play Store
2.  Scan the QR code displayed in terminal
3.  Activate the tunnel

### 5. Verify Connection

Once connected, verify your VPN is working:

```bash
# Check your public IP
curl ifconfig.me
```

Your IP should now show the AWS server's IP address.

### 6. Tear Down (Stop Billing)

**Crucial:** When finished, destroy resources to stop costs. This deletes the server and all configurations.

```bash
terraform destroy
```

Type `yes` to confirm.

**⚠️ Important:** You'll need to reconfigure your devices if you redeploy. Save your config files if you plan to use the same setup again.

## 🌐 Use Cases

  * **Public Wi-Fi protection:** Secure your connection at coffee shops, airports
  * **Privacy:** Hide your browsing from ISP
  * **Geo-spoofing:** Access region-locked content
  * **Remote work:** Secure connection to cloud resources
  * **Travel:** Maintain privacy on foreign networks