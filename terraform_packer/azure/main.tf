terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  # 구독 ID 및 Tenant ID 입력해야 함 
  features {}
}

data "azurerm_resource_group" "gonigoni" {
  name = "gonigoni-rg"
}

data "azurerm_image" "rocky9_image" {
  name_regex          = "gonigoni-rocky9-*"
  resource_group_name = data.azurerm_resource_group.gonigoni.name
}

data "azurerm_virtual_network" "vnet" {
  name                = "vnet"
  resource_group_name = data.azurerm_resource_group.gonigoni.name
}

data "azurerm_subnet" "public_subnet" {
  name                 = "public-subnet"
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = data.azurerm_resource_group.gonigoni.name
}

data "azurerm_ssh_public_key" "my_ssh_key" {
  name                = "my-ssh-key"
  resource_group_name = data.azurerm_resource_group.gonigoni.name
}

# Public IP
resource "azurerm_public_ip" "vm_public_ip" {
  name                = "vm-public-ip"
  location            = data.azurerm_resource_group.gonigoni.location
  resource_group_name = data.azurerm_resource_group.gonigoni.name
  allocation_method   = "Static"
}

# Network Security Group
resource "azurerm_network_security_group" "vm_nsg" {
  name                = "vm-nsg"
  location            = data.azurerm_resource_group.gonigoni.location
  resource_group_name = data.azurerm_resource_group.gonigoni.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Network Interface
resource "azurerm_network_interface" "vm_nic" {
  name                = "vm-nic"
  location            = data.azurerm_resource_group.gonigoni.location
  resource_group_name = data.azurerm_resource_group.gonigoni.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.public_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_public_ip.id
  }
}

# Security Group to the Network Interface
resource "azurerm_network_interface_security_group_association" "vm_nic_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.vm_nic.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "gonigoni_vm" {
  name                  = "gonigoni-vm"
  resource_group_name   = data.azurerm_resource_group.gonigoni.name
  location              = data.azurerm_resource_group.gonigoni.location
  size                  = "Standard_D2s_v3"
  admin_username        = "gonigoni"
  network_interface_ids = [azurerm_network_interface.vm_nic.id]

  admin_ssh_key {
    username   = "gonigoni"
    public_key = data.azurerm_ssh_public_key.my_ssh_key.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_id = data.azurerm_image.rocky9_image.id

  # Marketplace에서 구독한 이미지로 만든 커스텀 이미지도 plan 정보가 필요함
  plan {
    publisher = "resf"
    product   = "rockylinux-x86_64"
    name      = "9-base"
  }
}
