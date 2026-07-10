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

# Standard_B2ms = 2 vCPU / 8 GB for the bridge service on testnet.
variable "vm_size" {
  type    = string
  default = "Standard_B2ms"
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

# The bridge indexer's Etherman.L2URLs — point at your own RPC/full node on
# the same network.
variable "l2_rpc_url" {
  type      = string
  sensitive = true
}

variable "db_password" {
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

resource "azurerm_resource_group" "bridge" {
  name     = "prismo-bridge-${var.network}"
  location = var.location
  tags     = { Network = var.network }
}

resource "azurerm_virtual_network" "bridge" {
  name                = "prismo-bridge-vnet-${var.network}"
  address_space       = ["10.45.0.0/16"]
  location            = azurerm_resource_group.bridge.location
  resource_group_name = azurerm_resource_group.bridge.name
}

resource "azurerm_subnet" "app" {
  name                 = "app"
  resource_group_name  = azurerm_resource_group.bridge.name
  virtual_network_name = azurerm_virtual_network.bridge.name
  address_prefixes     = ["10.45.1.0/24"]
}

# Delegated subnet — Flexible Server requires its own subnet delegated to the DB service.
resource "azurerm_subnet" "db" {
  name                 = "db"
  resource_group_name  = azurerm_resource_group.bridge.name
  virtual_network_name = azurerm_virtual_network.bridge.name
  address_prefixes     = ["10.45.2.0/24"]

  delegation {
    name = "fs"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_network_security_group" "app" {
  name                = "prismo-bridge-nsg-${var.network}"
  location            = azurerm_resource_group.bridge.location
  resource_group_name = azurerm_resource_group.bridge.name

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

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

# Private DNS for the Flexible Server FQDN — keeps the DB off the public internet.
resource "azurerm_private_dns_zone" "db" {
  name                = "prismo-bridge-${var.network}.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.bridge.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "db" {
  name                  = "prismo-bridge-${var.network}"
  resource_group_name   = azurerm_resource_group.bridge.name
  private_dns_zone_name = azurerm_private_dns_zone.db.name
  virtual_network_id    = azurerm_virtual_network.bridge.id
}

resource "azurerm_postgresql_flexible_server" "bridge" {
  name                          = "prismo-bridge-${var.network}"
  resource_group_name           = azurerm_resource_group.bridge.name
  location                      = azurerm_resource_group.bridge.location
  version                       = "16"
  sku_name                      = var.network == "mainnet" ? "GP_Standard_D2ds_v5" : "B_Standard_B2ms"
  storage_mb                    = var.network == "mainnet" ? 524288 : 131072
  administrator_login           = "bridge"
  administrator_password        = var.db_password
  backup_retention_days         = var.network == "mainnet" ? 30 : 7
  zone                          = "1"
  delegated_subnet_id           = azurerm_subnet.db.id
  private_dns_zone_id           = azurerm_private_dns_zone.db.id
  public_network_access_enabled = false

  dynamic "high_availability" {
    for_each = var.network == "mainnet" ? [1] : []
    content {
      mode = "ZoneRedundant"
    }
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.db]
}

resource "azurerm_postgresql_flexible_server_database" "bridge" {
  name      = "bridge"
  server_id = azurerm_postgresql_flexible_server.bridge.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_public_ip" "app" {
  name                = "prismo-bridge-ip-${var.network}"
  location            = azurerm_resource_group.bridge.location
  resource_group_name = azurerm_resource_group.bridge.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "app" {
  name                = "prismo-bridge-nic-${var.network}"
  location            = azurerm_resource_group.bridge.location
  resource_group_name = azurerm_resource_group.bridge.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.app.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.app.id
  }
}

resource "azurerm_linux_virtual_machine" "app" {
  name                  = "prismo-bridge-${var.network}"
  resource_group_name   = azurerm_resource_group.bridge.name
  location              = azurerm_resource_group.bridge.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.app.id]

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
    network                  = var.network
    l1_rpc_url               = var.l1_rpc_url
    l2_rpc_url               = var.l2_rpc_url
    db_password              = var.db_password
    datastream_host_override = var.datastream_host_override
  }))

  tags = { Network = var.network }
}

output "public_ip" {
  value = azurerm_public_ip.app.ip_address
}

output "ssh_cmd" {
  value = "ssh ${var.admin_username}@${azurerm_public_ip.app.ip_address}"
}

output "db_fqdn" {
  value = azurerm_postgresql_flexible_server.bridge.fqdn
}

output "network" {
  value = var.network
}
