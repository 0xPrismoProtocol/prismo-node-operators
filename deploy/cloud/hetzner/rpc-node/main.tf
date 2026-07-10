terraform {
  required_version = ">= 1.6"
  required_providers {
    hcloud = { source = "hetznercloud/hcloud", version = "~> 1.48" }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

variable "hcloud_token" {
  type      = string
  sensitive = true
}

variable "location" {
  type    = string
  default = "fsn1"
}

variable "server_type" {
  type    = string
  default = "ccx23"
}

variable "ssh_key_name" {
  type = string
}

variable "data_volume_gb" {
  type    = number
  default = 1024
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

variable "datastream_host_override" {
  type    = string
  default = ""
}

data "hcloud_ssh_key" "user" {
  name = var.ssh_key_name
}

resource "hcloud_server" "rpc" {
  name        = "prismo-rpc-node-${var.network}"
  image       = "ubuntu-24.04"
  server_type = var.server_type
  location    = var.location
  ssh_keys    = [data.hcloud_ssh_key.user.id]
  labels      = { network = var.network }

  user_data = templatefile("${path.module}/cloud-init.yaml", {
    network                  = var.network
    l1_rpc_url               = var.l1_rpc_url
    datastream_host_override = var.datastream_host_override
  })

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  firewall_ids = [hcloud_firewall.rpc.id]
}

resource "hcloud_volume" "data" {
  name      = "prismo-rpc-data-${var.network}"
  size      = var.data_volume_gb
  location  = var.location
  format    = "ext4"
  automount = true
  server_id = hcloud_server.rpc.id
}

resource "hcloud_firewall" "rpc" {
  name = "prismo-rpc-${var.network}"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
  rule {
    # certbot's HTTP-01 challenge needs port 80 reachable; nginx serves only
    # the challenge response + a redirect to 443 on this port, nothing else.
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

output "public_ipv4" {
  value = hcloud_server.rpc.ipv4_address
}

output "ssh_cmd" {
  value = "ssh root@${hcloud_server.rpc.ipv4_address}"
}

output "network" {
  value = var.network
}
