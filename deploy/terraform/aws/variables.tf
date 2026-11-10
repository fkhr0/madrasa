# Frankfurt: close to Iraq, every server type.
variable "region" {
  type    = string
  default = "eu-central-1"
}

# The AWS CLI profile with your keys (aws configure).
variable "profile" {
  type    = string
  default = "default"
}

# t4g.small: 2 ARM CPUs, 2 GB (with swap), in the free plan.
variable "instance_type" {
  type    = string
  default = "t4g.small"
}

variable "disk_gb" {
  type    = number
  default = 30
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

# Who may SSH in from the internet. Your IP ("1.2.3.4/32") or "0.0.0.0/0"
# at first; "" once Tailscale works (SSH only over Tailscale).
variable "ssh_allowed_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

# The budget alert: an email when the month looks like going over this.
variable "monthly_budget_usd" {
  type    = string
  default = "25"
}

variable "alert_email" {
  type = string
}
