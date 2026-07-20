terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
}

provider "azurerm" {
  features {}
}

variable "location" {
  type    = string
  default = "eastus"
}

# Standard_D8s_v5 = 8 vCPU / 32 GB, the closest peer to the AWS m6i.2xlarge reference.
variable "vm_size" {
  type    = string
  default = "Standard_D8s_v5"
}

variable "data_disk_gb" {
  type    = number
  default = 1024
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

# SSH public key material (the contents of e.g. ~/.ssh/id_ed25519.pub).
variable "ssh_public_key" {
  type = string
}

variable "allowed_ssh_cidrs" {
  type        = list(string)
  description = "CIDR ranges allowed to reach SSH (port 22). No default: you must pass this explicitly. Do not use 0.0.0.0/0 in production."
  validation {
    condition     = !contains(var.allowed_ssh_cidrs, "0.0.0.0/0") && !contains(var.allowed_ssh_cidrs, "::/0")
    error_message = "allowed_ssh_cidrs must not be world-open (0.0.0.0/0 or ::/0). Pass your own IP, e.g. [\"203.0.113.4/32\"]."
  }
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

resource "azurerm_resource_group" "rpc" {
  name     = "prismo-rpc-node-${var.network}"
  location = var.location
  tags     = { Network = var.network }
}

resource "azurerm_virtual_network" "rpc" {
  name                = "prismo-rpc-vnet-${var.network}"
  address_space       = ["10.42.0.0/16"]
  location            = azurerm_resource_group.rpc.location
  resource_group_name = azurerm_resource_group.rpc.name
}

resource "azurerm_subnet" "rpc" {
  name                 = "rpc"
  resource_group_name  = azurerm_resource_group.rpc.name
  virtual_network_name = azurerm_virtual_network.rpc.name
  address_prefixes     = ["10.42.1.0/24"]
}

resource "azurerm_network_security_group" "rpc" {
  name                = "prismo-rpc-nsg-${var.network}"
  location            = azurerm_resource_group.rpc.location
  resource_group_name = azurerm_resource_group.rpc.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.allowed_ssh_cidrs
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # certbot's HTTP-01 challenge needs port 80 reachable; nginx serves only
  # the challenge response + a redirect to 443 on this port, nothing else.
  security_rule {
    name                       = "HTTP"
    priority                   = 111
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "rpc" {
  subnet_id                 = azurerm_subnet.rpc.id
  network_security_group_id = azurerm_network_security_group.rpc.id
}

resource "azurerm_public_ip" "rpc" {
  name                = "prismo-rpc-ip-${var.network}"
  location            = azurerm_resource_group.rpc.location
  resource_group_name = azurerm_resource_group.rpc.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "rpc" {
  name                = "prismo-rpc-nic-${var.network}"
  location            = azurerm_resource_group.rpc.location
  resource_group_name = azurerm_resource_group.rpc.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.rpc.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.rpc.id
  }
}

resource "azurerm_linux_virtual_machine" "rpc" {
  name                  = "prismo-rpc-node-${var.network}"
  resource_group_name   = azurerm_resource_group.rpc.name
  location              = azurerm_resource_group.rpc.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.rpc.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 50
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    network                  = var.network
    l1_rpc_url               = var.l1_rpc_url
    datastream_host_override = var.datastream_host_override
  }))

  tags = { Network = var.network }
}

resource "azurerm_managed_disk" "data" {
  name                 = "prismo-rpc-data-${var.network}"
  location             = azurerm_resource_group.rpc.location
  resource_group_name  = azurerm_resource_group.rpc.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_gb
}

resource "azurerm_virtual_machine_data_disk_attachment" "data" {
  managed_disk_id    = azurerm_managed_disk.data.id
  virtual_machine_id = azurerm_linux_virtual_machine.rpc.id
  lun                = 10
  caching            = "ReadWrite"
}

output "public_ip" {
  value = azurerm_public_ip.rpc.ip_address
}

output "ssh_cmd" {
  value = "ssh ${var.admin_username}@${azurerm_public_ip.rpc.ip_address}"
}

output "network" {
  value = var.network
}
