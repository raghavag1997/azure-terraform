#Creating Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = "Japan East"
  tags = {
    "Created By" = "Raghav Agarwal"
  }
}

#Getting Current Details of User/App Service to Give access
data "azurerm_client_config" "current" {}

#Create Azure Key Vault
resource "azurerm_key_vault" "example" {
  name                        = "examplekeyvault-aim"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get","Set"
    ]
  }
}

#Creating Secret
resource "azurerm_key_vault_secret" "example" {
  name         = "vmpassword"
  value        = "Ragh@azure31"
  key_vault_id = azurerm_key_vault.example.id
}

#Creating Vnet with Subent
resource "azurerm_virtual_network" "vnet" {
  name                = var.virtual_network_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "Dev",
    "Created By" = "Raghav Agarwal"
  }
}

#Creating Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "subnet-a"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

#Getting Data of subnet so that we can pass it over network interface
# data "azurerm_subnet" "example" {
#   name                 = "subnet1"
#   virtual_network_name = var.virtual_network_name
#   resource_group_name  = var.resource_group_name
# }

#Creating Network Security Group
resource "azurerm_network_security_group" "example" {
  name                = "acceptanceTestSecurityGroup1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "test123"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Dev"
  }
}

#Creatig Public IP
resource "azurerm_public_ip" "example" {
  name                = "mypublicip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"

  tags = {
    environment = "Dev"
  }
}

#Create NIC card for VM
resource "azurerm_network_interface" "example" {
  name                = "myvm-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.example.id
  }
  depends_on = [
    azurerm_virtual_network.vnet
  ]
}

#Assoction of NSG with NIC
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.example.id
  network_security_group_id = azurerm_network_security_group.example.id
}

#Creating Data Disk
resource "azurerm_managed_disk" "example" {
  name                 = "acctestmd"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1"

  tags = {
    environment = "staging"
  }
}

#Creating Availibilty Set
resource "azurerm_availability_set" "example" {
  name                = "example-aset"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = {
    environment = "Dev"
  }
}

#Creating Windows Virtual Machine
resource "azurerm_windows_virtual_machine" "example" {
  name                = "example-machine"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D2s_v3"
  admin_username      = "adminuser"
  admin_password      = azurerm_key_vault_secret.example.value
  network_interface_ids = [
    azurerm_network_interface.example.id,
  ]
  availability_set_id = azurerm_availability_set.example.id
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  #Getting This information use this link - https://gmusumeci.medium.com/how-to-find-azure-windows-vm-images-for-terraform-or-packer-deployments-f3edaeb42466
  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-22h2-pro"
    version   = "latest"
  }
  depends_on = [
    azurerm_network_interface.example
  ]
}

#Adding Data Disk to VM
resource "azurerm_virtual_machine_data_disk_attachment" "example" {
  managed_disk_id    = azurerm_managed_disk.example.id
  virtual_machine_id = azurerm_windows_virtual_machine.example.id
  lun                = "0"
  caching            = "ReadWrite"
}
