terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.60" }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "m6i.2xlarge"
}

variable "data_disk_gb" {
  type    = number
  default = 1024
}

variable "key_name" {
  type = string
}

variable "allowed_ssh_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "l1_rpc_url" {
  type      = string
  sensitive = true
}

variable "network" {
  type    = string
  default = "testnet"
  validation {
    condition     = contains(["testnet", "mainnet"], var.network)
    error_message = "network must be testnet or mainnet."
  }
}

# Optional: override the default datastream host for the chosen network. Empty = use the
# canonical value from configs/networks/<network>.env on the instance.
variable "datastream_host_override" {
  type    = string
  default = ""
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_security_group" "rpc" {
  name        = "prismo-rpc-node-${var.network}"
  description = "Prismo RPC node ingress (${var.network})"
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }
  ingress {
    description = "HTTPS RPC (via local nginx)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    # certbot's HTTP-01 challenge needs port 80 reachable; nginx serves only
    # the challenge response + a redirect to 443 on this port, nothing else.
    description = "HTTP (ACME challenge + redirect to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "rpc" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.rpc.id]

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  ebs_block_device {
    device_name = "/dev/sdf"
    volume_size = var.data_disk_gb
    volume_type = "gp3"
    iops        = 6000
    throughput  = 250
  }

  user_data = templatefile("${path.module}/cloud-init.yaml", {
    network                  = var.network
    l1_rpc_url               = var.l1_rpc_url
    datastream_host_override = var.datastream_host_override
  })

  tags = {
    Name    = "prismo-rpc-node-${var.network}"
    Network = var.network
  }
}

output "public_ip" {
  value = aws_instance.rpc.public_ip
}

output "ssh_cmd" {
  value = "ssh ubuntu@${aws_instance.rpc.public_ip}"
}

output "network" {
  value = var.network
}
