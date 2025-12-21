# AWS VPN Lab

This repository contains **Infrastructure as Code (Terraform)** to spin up a personal, on-demand WireGuard VPN server on AWS. Deploy your own private VPN in minutes and pay only when you use it.

## Project Goal

To create a **"dispose-on-demand"** VPN solution. We use Terraform to automate the creation and destruction of infrastructure, ensuring you only pay for resources while they are in use.

## Capabilities & Limitations

Before deploying, understand what this VPN is (and isn't) good for:

| The Good (Capabilities) | The Bad (Limitations) |
| --- | --- |
| **Public Wi-Fi Security:** Encrypts all traffic. Perfect for airports, hotels, and coffee shops. | **Streaming Blocks:** Netflix, Hulu, and Disney+ usually **block** AWS IP addresses. This is **not** good for watching region-locked movies. |
| **Total Privacy:** You own the server. No third-party VPN provider logging your data. | **Data Costs:** AWS charges for outgoing data (~$0.09/GB). Heavy 4K streaming will get expensive quickly. |
| **Dispose-on-Demand:** Spin it up for a trip, destroy it when home. No monthly subscriptions. | **Not "Anonymous":** While your ISP can't see your traffic, AWS has your billing details. Not for illegal activities. |
| **WireGuard Speed:** Uses modern, lightweight protocols for fast connections. | **Technical Setup:** Requires basic terminal knowledge; not a "one-click" app store experience. |

---

## Step 1: AWS Account Setup

### 1.1 Create an IAM User

**Important:** Do NOT use root user access keys.

1. Log into AWS Console and search for **IAM**.
2. Click **Users** -> **Create user**.
3. Set username: `terraform-deployer`.
4. Select **Attach policies directly**.
5. Search and check: **AdministratorAccess**.
6. Click **Next** -> **Create user**.

### 1.2 Create Access Keys

1. Click your new user (`terraform-deployer`).
2. Go to **Security credentials** -> **Access keys** -> **Create access key**.
3. Select **Command Line Interface (CLI)**.
4. Check the confirmation box and click **Next**.
5. Click **Create access key**.
6. **Download the CSV** or copy the **Access Key ID** and **Secret Access Key**.

### 1.3 Configure Credentials

Create a file named `terraform.tfvars` in the project root.

```bash
cat > terraform.tfvars << 'EOF'
aws_access_key_id      = "AKIA..."  # Replace with your Access Key ID
aws_secret_access_key = "your-secret-access-key-here"
EOF

```

*Note: `terraform.tfvars` is ignored by Git to prevent accidental commits.*

## Server Selection

### VPN Server Options

All VPN traffic runs on lightweight instances - no GPU needed.

| Instance Type | vCPUs | RAM | Cost/Hour | Est. Cost/Month (24/7) | Best For |
| --- | --- | --- | --- | --- | --- |
| `t3.micro` (Default) | 2 | 1GB | ~$0.01 | ~$7.20 | Personal use, 1-2 devices |
| `t3.small` | 2 | 2GB | ~$0.02 | ~$14.40 | Family use, 3-5 devices |
| `t3.medium` | 2 | 4GB | ~$0.04 | ~$28.80 | Heavy usage, 6-10 devices |

**Default Configuration:** `t3.micro` is perfect for most personal VPN needs.

## Region Selection

Choose a region close to you for best performance, or far from you for geo-spoofing. The default is **N. Virginia (us-east-1)**.

## Prerequisites (Debian/Ubuntu)

Before deploying, ensure you have WireGuard installed on your local machine:

```bash
# Install WireGuard
sudo apt update
sudo apt install wireguard wireguard-tools

# Verify installation
wg --version

```

## Usage

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

After deployment, Terraform will generate configuration files for all your devices in the `./vpn-configs/` directory.

### 3. Connect to VPN (Desktop/Laptop - Linux Only)

The VPN server is configured to support **up to 10 devices simultaneously**. Each device gets its own unique configuration file for security.

Use the provided connection script for quick, terminal-based access:

```bash
# Connect to VPN (runs in foreground)
sudo ./connect-vpn.sh

# Press Ctrl+C to disconnect

```

**What the script does:**

* Automatically loads the correct WireGuard configuration
* Establishes the VPN tunnel
* Shows connection status
* Disconnects cleanly when you press Ctrl+C

### 4. Connect Mobile Devices (Android)

Transfer the configuration file to your Android device:

1. Install WireGuard from the Play Store
2. Transfer `vpn-configs/client2.conf` to your phone (via email, cloud, USB)
3. In the WireGuard app: **+** -> **Import from file or archive**
4. Select the config file
5. Toggle the VPN on

**Security Note:** Do NOT share config files between devices. Each device should use its own unique configuration.

**Available configs after deployment:**

* `vpn-configs/client1.conf` - Desktop/laptop primary
* `vpn-configs/client2.conf` - Phone
* `vpn-configs/client3.conf` - Tablet
* `vpn-configs/client4.conf` through `client10.conf` - Additional devices

### 5. Tear Down (Stop Billing)

**Crucial:** When finished, destroy resources to stop costs. This deletes the server and all configurations.

**Important:** Use the same parameters you used with `terraform apply`:

```bash
# If you deployed with default settings
terraform destroy

# If you deployed with custom region or instance type
terraform destroy -var="aws_region=eu-west-2" -var="instance_type=t3.small"

```

Type `yes` to confirm.

---

### Security Best Practices

* **Never share config files** - Each device should have its own
* **Keep `vpn-configs/` directory private** - Treat like SSH keys
* **Use `terraform destroy**` when not needed - Don't leave VPN running unnecessarily
