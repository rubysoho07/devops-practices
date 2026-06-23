terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "resource_group_name" {
  description = "기존 리소스 그룹 이름"
}

variable "vnet_name" {
  description = "기존 VNet 이름"
}

variable "subnet_name" {
  description = "기존 서브넷 이름 (NAT 인스턴스가 위치할 Public 서브넷)"
}

variable "private_subnet_name" {
  description = "라우팅 설정 대상 Private 서브넷 이름"
}

variable "admin_username" {
  default = "azureuser"
}

variable "ssh_public_key_name" {
  description = "Azure에 등록된 SSH 공개키 리소스 이름"
}

data "azurerm_ssh_public_key" "nat" {
  name                = var.ssh_public_key_name
  resource_group_name = var.resource_group_name
}

locals {
  user_data = base64encode(file("${path.module}/user_data.sh"))
}

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

data "azurerm_subnet" "main" {
  name                 = var.subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.resource_group_name
}

resource "azurerm_public_ip" "nat" {
  name                = "pip-nat-instance"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "nat" {
  name                = "nsg-nat-instance"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  security_rule {
    name                       = "allow-ssh"
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
    name                       = "allow-forwarded"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "nat" {
  name                 = "nic-nat-instance"
  location             = data.azurerm_resource_group.main.location
  resource_group_name  = data.azurerm_resource_group.main.name
  ip_forwarding_enabled = true

  ip_configuration {
    name                          = "ipconfig-nat"
    subnet_id                     = data.azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.nat.id
  }
}

resource "azurerm_network_interface_security_group_association" "nat" {
  network_interface_id      = azurerm_network_interface.nat.id
  network_security_group_id = azurerm_network_security_group.nat.id
}

resource "azurerm_linux_virtual_machine" "nat" {
  name                = "vm-nat-instance"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  size                = "Standard_B2as_v2"
  admin_username      = var.admin_username
  user_data           = local.user_data

  network_interface_ids = [azurerm_network_interface.nat.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = data.azurerm_ssh_public_key.nat.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  plan {
    name      = "9-base"
    product   = "rockylinux-x86_64"
    publisher = "resf"
  }

  source_image_reference {
    publisher = "resf"
    offer     = "rockylinux-x86_64"
    sku       = "9-base"
    version   = "latest"
  }
}

data "azurerm_subnet" "private" {
  name                 = var.private_subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.resource_group_name
}

resource "azurerm_route_table" "private" {
  name                = "rt-private"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  route {
    name                   = "default-via-nat"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_network_interface.nat.private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "private" {
  subnet_id      = data.azurerm_subnet.private.id
  route_table_id = azurerm_route_table.private.id
}

resource "azurerm_network_security_group" "private" {
  name                = "nsg-private"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
}

resource "azurerm_subnet_network_security_group_association" "private" {
  subnet_id                 = data.azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.private.id
}

output "nat_instance_public_ip" {
  value = azurerm_public_ip.nat.ip_address
}

output "nat_instance_private_ip" {
  value = azurerm_network_interface.nat.private_ip_address
}
