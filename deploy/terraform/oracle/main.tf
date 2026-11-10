# The whole Oracle Cloud setup as code (all inside the Always Free tier):
# a network, the cloud firewall, one ARM server (Ubuntu 24.04) and the
# bucket for off-site backups.
#   terraform init && terraform apply
terraform {
  required_version = ">= 1.6"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

data "oci_identity_availability_domains" "all" {
  compartment_id = var.tenancy_ocid
}

# The newest Ubuntu 24.04 image for ARM servers.
data "oci_core_images" "ubuntu" {
  compartment_id           = var.tenancy_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# ── Network ──
resource "oci_core_vcn" "main" {
  compartment_id = var.tenancy_ocid
  display_name   = "madrasa"
  cidr_blocks    = ["10.0.0.0/16"]
  dns_label      = "madrasa"
}

resource "oci_core_internet_gateway" "main" {
  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "madrasa"
}

resource "oci_core_route_table" "main" {
  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "madrasa"
  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.main.id
  }
}

# The cloud firewall: the web, Tailscale's direct connections, and SSH only
# while ssh_allowed_cidr isn't empty (empty it once Tailscale works).
resource "oci_core_security_list" "main" {
  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "madrasa"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  dynamic "ingress_security_rules" {
    for_each = [80, 443]
    content {
      protocol = "6" # TCP
      source   = "0.0.0.0/0"
      tcp_options {
        min = ingress_security_rules.value
        max = ingress_security_rules.value
      }
    }
  }

  ingress_security_rules {
    protocol = "17" # UDP: Tailscale's direct path (it works without, slower)
    source   = "0.0.0.0/0"
    udp_options {
      min = 41641
      max = 41641
    }
  }

  dynamic "ingress_security_rules" {
    for_each = var.ssh_allowed_cidr == "" ? [] : [var.ssh_allowed_cidr]
    content {
      protocol = "6"
      source   = ingress_security_rules.value
      tcp_options {
        min = 22
        max = 22
      }
    }
  }
}

resource "oci_core_subnet" "public" {
  compartment_id    = var.tenancy_ocid
  vcn_id            = oci_core_vcn.main.id
  display_name      = "madrasa-public"
  cidr_block        = "10.0.1.0/24"
  dns_label         = "public"
  route_table_id    = oci_core_route_table.main.id
  security_list_ids = [oci_core_security_list.main.id]
}

# ── The server ──
resource "oci_core_instance" "server" {
  compartment_id      = var.tenancy_ocid
  availability_domain = data.oci_identity_availability_domains.all.availability_domains[var.availability_domain_index].name
  display_name        = "madrasa"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_gb
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = var.disk_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    hostname_label   = "madrasa"
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
  }

  # A new Ubuntu image later must not rebuild the server.
  lifecycle {
    ignore_changes = [source_details]
  }
}

# ── Off-site backups (S3-compatible) ──
data "oci_objectstorage_namespace" "main" {
  compartment_id = var.tenancy_ocid
}

resource "oci_objectstorage_bucket" "backups" {
  compartment_id = var.tenancy_ocid
  namespace      = data.oci_objectstorage_namespace.main.namespace
  name           = "madrasa-backups"
  access_type    = "NoPublicAccess"
}
