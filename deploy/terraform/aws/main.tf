# The AWS setup as code (sized for the free plan's credits): one ARM server
# (Ubuntu 24.04) with a fixed IP, the cloud firewall, the bucket for off-site
# backups, and a budget alert by email.
#   tofu init && tofu apply        (or terraform)
terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Keys come from the AWS CLI's profile (aws configure), never from here.
provider "aws" {
  region  = var.region
  profile = var.profile
  default_tags {
    tags = { Project = "madrasa" }
  }
}

# The newest Ubuntu 24.04 for ARM, from Canonical's public list.
data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/arm64/hvm/ebs-gp3/ami-id"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_caller_identity" "me" {}

resource "aws_key_pair" "admin" {
  key_name   = "madrasa"
  public_key = file(var.ssh_public_key_path)
}

# The cloud firewall: the web, Tailscale's direct connections, and SSH only
# while ssh_allowed_cidr isn't empty (empty it once Tailscale works).
resource "aws_security_group" "server" {
  name        = "madrasa"
  description = "madrasa server"
  vpc_id      = data.aws_vpc.default.id

  dynamic "ingress" {
    for_each = [80, 443]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # Tailscale's direct path (it works without, slower).
  ingress {
    from_port   = 41641
    to_port     = 41641
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = var.ssh_allowed_cidr == "" ? [] : [var.ssh_allowed_cidr]
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── The server ──
resource "aws_instance" "server" {
  ami                    = data.aws_ssm_parameter.ubuntu.value
  instance_type          = var.instance_type
  key_name               = aws_key_pair.admin.key_name
  vpc_security_group_ids = [aws_security_group.server.id]
  iam_instance_profile   = aws_iam_instance_profile.server.name

  root_block_device {
    volume_type = "gp3"
    volume_size = var.disk_gb
    encrypted   = true
  }

  # IMDSv2 only; 2 hops so the containers can reach it (backup credentials).
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # Credits run out instead of a bill: no "unlimited" CPU bursting.
  credit_specification {
    cpu_credits = "standard"
  }

  tags = { Name = "madrasa" }

  # A new Ubuntu image later must not rebuild the server.
  lifecycle {
    ignore_changes = [ami]
  }
}

# A fixed address: stays the same through stops and restarts (DuckDNS).
resource "aws_eip" "server" {
  instance = aws_instance.server.id
  domain   = "vpc"
}

# ── Off-site backups ──
resource "aws_s3_bucket" "backups" {
  bucket = "madrasa-backups-${data.aws_caller_identity.me.account_id}"
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket                  = aws_s3_bucket.backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# The server reaches the bucket with a role: no keys stored anywhere.
resource "aws_iam_role" "server" {
  name = "madrasa-server"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "backups" {
  name = "backups"
  role = aws_iam_role.server.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.backups.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.backups.arn}/*"
      },
    ]
  })
}

resource "aws_iam_instance_profile" "server" {
  name = "madrasa-server"
  role = aws_iam_role.server.name
}

# ── An email before money runs out ──
resource "aws_budgets_budget" "monthly" {
  name         = "madrasa"
  budget_type  = "COST"
  limit_amount = var.monthly_budget_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}
