# Oracle Cloud account (Profile → API keys → Add API key shows these).
variable "tenancy_ocid" { type = string }
variable "user_ocid" { type = string }
variable "fingerprint" { type = string }
variable "private_key_path" { type = string }

variable "region" {
  type    = string
  default = "eu-frankfurt-1"
}

# Free ARM capacity is sometimes full in one zone: try 1 or 2.
variable "availability_domain_index" {
  type    = number
  default = 0
}

# Always Free allows up to 4 OCPUs, 24 GB and 200 GB of disk in total.
variable "ocpus" {
  type    = number
  default = 4
}
variable "memory_gb" {
  type    = number
  default = 24
}
variable "disk_gb" {
  type    = number
  default = 100
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
