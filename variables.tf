variable "aws_region" {
  description = "The AWS region to deploy the VPN server"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type for the VPN server"
  type        = string
  default     = "t3.micro"
  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium"], var.instance_type)
    error_message = "The instance_type must be t3.micro, t3.small, or t3.medium."
  }
}

variable "aws_access_key_id" {
  description = "AWS Access Key ID"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key"
  type        = string
  sensitive   = true
}

variable "vpn_port" {
  description = "WireGuard VPN port"
  type        = number
  default     = 51820
}

variable "max_clients" {
  description = "Maximum number of VPN clients"
  type        = number
  default     = 10
  validation {
    condition     = var.max_clients >= 1 && var.max_clients <= 50
    error_message = "The max_clients must be between 1 and 50."
  }
}