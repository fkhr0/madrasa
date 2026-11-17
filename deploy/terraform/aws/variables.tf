variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "profile" {
  type    = string
  default = "default"
}

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

variable "ssh_allowed_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

variable "monthly_budget_usd" {
  type    = string
  default = "25"
}

variable "alert_email" {
  type = string
}
