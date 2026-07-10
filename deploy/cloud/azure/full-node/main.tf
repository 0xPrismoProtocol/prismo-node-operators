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

# Standard_D16s_v5 = 16 vCPU / 64 GB — full node + L1 geth + L1 lighthouse on one box.
variable "vm_size" {
  type    = string
  default = "Standard_D16s_v5"
}

variable "data_disk_gb" {
  type    = number
  default = 2048
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

resource "azurerm_resource_group" "node" {
  name     = "prismo-full-node-${var.network}"
  location = var.location
  tags     = { Network = var.network }
}

resource "azurerm_virtual_network" "node" {
  name                = "prismo-full-node-vnet-${var.network}"
  address_space       = ["10.43.0.0/16"]
  location            = azurerm_resource_group.node.location
  resource_group_name = azurerm_resource_group.node.name
}

resource "azurerm_subnet" "node" {
  name                 = "node"
  resource_group_name  = azurerm_resource_group.node.name
  virtual_network_name = azurerm_virtual_network.node.name
  address_prefixes     = ["10.43.1.0/24"]
}

resource "azurerm_network_security_group" "node" {
  name                = "prismo-full-node-nsg-${var.network}"
  location            = azurerm_resource_group.node.location
  resource_group_name = azurerm_resource_group.node.name

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

  # L1 execution (geth) P2P — inbound peers improve sync health.
  security_rule {
    name                       = "L1-EL-P2P"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "30303"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # L1 consensus (lighthouse) P2P.
  security_rule {
    name                       = "L1-CL-P2P"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "9000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "node" {
  subnet_id                 = azurerm_subnet.node.id
  network_security_group_id = azurerm_network_security_group.node.id
}

resource "azurerm_public_ip" "node" {
  name                = "prismo-full-node-ip-${var.network}"
  location            = azurerm_resource_group.node.location
  resource_group_name = azurerm_resource_group.node.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "node" {
  name                = "prismo-full-node-nic-${var.network}"
  location            = azurerm_resource_group.node.location
  resource_group_name = azurerm_resource_group.node.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.node.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.node.id
  }
}

resource "azurerm_linux_virtual_machine" "node" {
  name                  = "prismo-full-node-${var.network}"
  resource_group_name   = azurerm_resource_group.node.name
  location              = azurerm_resource_group.node.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.node.id]

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
  name                 = "prismo-full-node-data-${var.network}"
  location             = azurerm_resource_group.node.location
  resource_group_name  = azurerm_resource_group.node.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_gb
}

resource "azurerm_virtual_machine_data_disk_attachment" "data" {
  managed_disk_id    = azurerm_managed_disk.data.id
  virtual_machine_id = azurerm_linux_virtual_machine.node.id
  lun                = 10
  caching            = "ReadWrite"
}

output "public_ip" {
  value = azurerm_public_ip.node.ip_address
}

output "ssh_cmd" {
  value = "ssh ${var.admin_username}@${azurerm_public_ip.node.ip_address}"
}

output "network" {
  value = var.network
}
