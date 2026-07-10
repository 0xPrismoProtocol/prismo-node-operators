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

# Standard_B2s = 2 vCPU / 4 GB — watchtower just follows heads and cross-checks.
variable "vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "ssh_public_key" {
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

# Where the watchtower reads L2 state from — typically your own full node's RPC.
variable "l2_rpc_url" {
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

resource "azurerm_resource_group" "wt" {
  name     = "prismo-watchtower-${var.network}"
  location = var.location
  tags     = { Network = var.network }
}

resource "azurerm_virtual_network" "wt" {
  name                = "prismo-watchtower-vnet-${var.network}"
  address_space       = ["10.44.0.0/16"]
  location            = azurerm_resource_group.wt.location
  resource_group_name = azurerm_resource_group.wt.name
}

resource "azurerm_subnet" "wt" {
  name                 = "watchtower"
  resource_group_name  = azurerm_resource_group.wt.name
  virtual_network_name = azurerm_virtual_network.wt.name
  address_prefixes     = ["10.44.1.0/24"]
}

resource "azurerm_network_security_group" "wt" {
  name                = "prismo-watchtower-nsg-${var.network}"
  location            = azurerm_resource_group.wt.location
  resource_group_name = azurerm_resource_group.wt.name

  # Outbound-only workload — SSH is the only inbound rule.
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
}

resource "azurerm_subnet_network_security_group_association" "wt" {
  subnet_id                 = azurerm_subnet.wt.id
  network_security_group_id = azurerm_network_security_group.wt.id
}

resource "azurerm_public_ip" "wt" {
  name                = "prismo-watchtower-ip-${var.network}"
  location            = azurerm_resource_group.wt.location
  resource_group_name = azurerm_resource_group.wt.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "wt" {
  name                = "prismo-watchtower-nic-${var.network}"
  location            = azurerm_resource_group.wt.location
  resource_group_name = azurerm_resource_group.wt.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.wt.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.wt.id
  }
}

resource "azurerm_linux_virtual_machine" "wt" {
  name                  = "prismo-watchtower-${var.network}"
  resource_group_name   = azurerm_resource_group.wt.name
  location              = azurerm_resource_group.wt.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.wt.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 50
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    network    = var.network
    l1_rpc_url = var.l1_rpc_url
    l2_rpc_url = var.l2_rpc_url
  }))

  tags = { Network = var.network }
}

output "public_ip" {
  value = azurerm_public_ip.wt.ip_address
}

output "ssh_cmd" {
  value = "ssh ${var.admin_username}@${azurerm_public_ip.wt.ip_address}"
}

output "network" {
  value = var.network
}
