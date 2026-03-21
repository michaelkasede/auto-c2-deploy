terraform {
  required_version = ">= 1.0"
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

# Resource Group
resource "azurerm_resource_group" "redteam" {
  name     = "${var.environment}-redteam-rg"
  location = var.azure_region

  tags = {
    Environment = var.environment
    Provider    = "azure"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "redteam" {
  name                = "${var.environment}-redteam-vnet"
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.redteam.location
  resource_group_name = azurerm_resource_group.redteam.name

  tags = {
    Environment = var.environment
    Provider    = "azure"
  }
}

# Subnets
resource "azurerm_subnet" "public" {
  count                = length(var.subnet_names)
  name                 = "${var.environment}-public-subnet-${count.index + 1}"
  resource_group_name  = azurerm_resource_group.redteam.name
  virtual_network_name = azurerm_virtual_network.redteam.name
  address_prefixes     = [var.subnet_address_prefixes[count.index]]
}

# Network Security Group
resource "azurerm_network_security_group" "redteam" {
  name                = "${var.environment}-redteam-nsg"
  location            = azurerm_resource_group.redteam.location
  resource_group_name = azurerm_resource_group.redteam.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_ip
    destination_address_prefix = "*"
  }

  # Allow SSH within the VNet so the redirector can reach private services
  # (and so Ansible can ProxyJump via the redirector).
  security_rule {
    name                       = "SSH-VNET"
    priority                   = 105
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.vnet_address_space
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = var.environment
    Provider    = "azure"
  }
}

# Apply NSG to the subnet used by all VMs.
resource "azurerm_subnet_network_security_group_association" "public_nsg" {
  subnet_id                 = azurerm_subnet.public[0].id
  network_security_group_id = azurerm_network_security_group.redteam.id
}

# Public IP only for the redirector (single exposed entry point).
resource "azurerm_public_ip" "redirector_pip" {
  name                = "${var.environment}-redirector-pip"
  location            = azurerm_resource_group.redteam.location
  resource_group_name = azurerm_resource_group.redteam.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic" {
  for_each            = var.vm_sizes
  name                = "${var.environment}-${each.key}-nic"
  location            = azurerm_resource_group.redteam.location
  resource_group_name = azurerm_resource_group.redteam.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public[0].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = each.key == "redirector" ? azurerm_public_ip.redirector_pip.id : null
  }
}

resource "azurerm_linux_virtual_machine" "service" {
  for_each              = var.vm_sizes
  name                  = "${var.environment}-${each.key}-vm"
  location              = azurerm_resource_group.redteam.location
  resource_group_name   = azurerm_resource_group.redteam.name
  network_interface_ids = [azurerm_network_interface.nic[each.key].id]
  size                  = each.value

  admin_username = "ubuntu"
  admin_ssh_key {
    username   = "ubuntu"
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    # NOTE: In some subscriptions/regions (e.g., Azure for Students in centralus),
    # Canonical's 20.04-LTS isn't available under the "UbuntuServer" offer.
    # Jammy (22.04) is available under the Jammy offer.
    offer   = "0001-com-ubuntu-server-jammy"
    sku     = "22_04-lts-gen2"
    version = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/templates/cloud-init-base.sh", {
    hostname = "${each.key}-${var.environment}"
  }))

  tags = {
    Environment = var.environment
    Service     = each.key
    Provider    = "azure"
  }
}

# Outputs
output "redirector_public_ip" {
  value = azurerm_public_ip.redirector_pip.ip_address
}
output "mythic_private_ip" {
  value = azurerm_network_interface.nic["mythic"].private_ip_address
}
output "gophish_private_ip" {
  value = azurerm_network_interface.nic["gophish"].private_ip_address
}
output "evilginx_private_ip" {
  value = azurerm_network_interface.nic["evilginx"].private_ip_address
}
output "pwndrop_private_ip" {
  value = azurerm_network_interface.nic["pwndrop"].private_ip_address
}
