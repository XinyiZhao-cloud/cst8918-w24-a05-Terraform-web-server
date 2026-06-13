terraform {
  required_version = ">= 1.1.0"

  required_providers {

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }

    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "2.3.3"
    }

  }
}

provider "azurerm" {
  features {}
}

provider "cloudinit" {
}

variable "labelPrefix" {
  description = "Your college username"
}

variable "region" {
  default = "canadacentral"
}

variable "admin_username" {
  default = "azureadmin"
}

resource "azurerm_resource_group" "rg" {

  name     = "${var.labelPrefix}-A05-RG"
  location = var.region

}

resource "azurerm_public_ip" "public_ip" {
  name                = "${var.labelPrefix}-public-ip"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name

  allocation_method = "Static"

  sku = "Standard"
}

resource "azurerm_virtual_network" "vnet" {

  name                = "${var.labelPrefix}-vnet"
  address_space       = ["10.0.0.0/16"]

  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name

}

resource "azurerm_subnet" "subnet" {

  name                 = "${var.labelPrefix}-subnet"

  resource_group_name  = azurerm_resource_group.rg.name

  virtual_network_name = azurerm_virtual_network.vnet.name

  address_prefixes     = ["10.0.1.0/24"]

}

resource "azurerm_network_security_group" "nsg" {

  name                = "${var.labelPrefix}-nsg"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"

    source_port_range          = "*"
    destination_port_range     = "22"

    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"

    source_port_range          = "*"
    destination_port_range     = "80"

    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "nic" {

  name                = "${var.labelPrefix}-nic"
  location            = var.region
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {

    name                          = "internal"

    subnet_id                     = azurerm_subnet.subnet.id

    private_ip_address_allocation = "Dynamic"

    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc" {

  network_interface_id      = azurerm_network_interface.nic.id

  network_security_group_id = azurerm_network_security_group.nsg.id

}

data "cloudinit_config" "init" {
  gzip          = false
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = file("${path.module}/init.sh")
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "${var.labelPrefix}-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.region
  size                = "Standard_B1s"

  admin_username = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = data.cloudinit_config.init.rendered
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "public_ip_address" {
  value = azurerm_public_ip.public_ip.ip_address
}