variable "tenancy_ocid" { type = string }
variable "user_ocid" { type = string }
variable "fingerprint" { type = string }
variable "private_key_path" { type = string }

variable "region" {
  type    = string
  default = "eu-frankfurt-1"
}

variable "availability_domain_index" {
  type    = number
  default = 0
}

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

variable "ssh_allowed_cidr" {
  type    = string
  default = "0.0.0.0/0"
}
