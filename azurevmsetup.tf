provider "azurerm" 
{
}


variable "location" {
  default = "Southeast Asia"
}

variable "username" {
  default = "mytuser1"
}

variable "password" {
  default = "test1234$"
}

resource "azurerm_resource_group" "resourceGroup" {
  name     = "mytdubaiResourceGroup"
  location = "${var.location}"
}

resource "azurerm_public_ip" "publicip" {
  name                         = "mytdubaipublicip"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.resourceGroup.name}"
  public_ip_address_allocation = "Dynamic"
  idle_timeout_in_minutes      = 30
  domain_name_label            = "mytdubaivm"

  tags {
    environment = "test"
  }
}

resource "azurerm_virtual_network" "vnet" {
  name                = "mytdubainetwork"
  address_space       = ["10.0.0.0/16"]
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.resourceGroup.name}"
}

resource "azurerm_network_security_group" "nsg" {
  name                = "mytdubainsg"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.resourceGroup.name}"

  security_rule {
    name                       = "HTTPS"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "winrm"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5985"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "winrm-out"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "5985"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "RDP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  tags {
    environment = "test"
  }
}

resource "azurerm_subnet" "subnet" {
  name                 = "mytdubaisubnet"
  resource_group_name  = "${azurerm_resource_group.resourceGroup.name}"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_network_interface" "nic" {
  name                      = "mytdubainic"
  location                  = "${var.location}"
  resource_group_name       = "${azurerm_resource_group.resourceGroup.name}"
  network_security_group_id = "${azurerm_network_security_group.nsg.id}"

  ip_configuration {
    name                          = "mytdubaiconfiguration"
    subnet_id                     = "${azurerm_subnet.subnet.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.publicip.id}"
  }
}

resource "azurerm_storage_account" "storageacc" {
  name                     = "mytdubaistoacc"
  resource_group_name      = "${azurerm_resource_group.resourceGroup.name}"
  location                 = "${var.location}"
  account_tier             = "Standard"
  account_replication_type = "GRS"
}

resource "azurerm_storage_container" "storagecont" {
  name                  = "mytdubaistoragecont"
  resource_group_name   = "${azurerm_resource_group.resourceGroup.name}"
  storage_account_name  = "${azurerm_storage_account.storageacc.name}"
  container_access_type = "private"
}

resource "azurerm_managed_disk" "datadisk" {
  name                 = "mytdubaidatadisk"
  location             = "${var.location}"
  resource_group_name  = "${azurerm_resource_group.resourceGroup.name}"
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1023"
}

resource "azurerm_virtual_machine" "vm" {
  name                  = "mywindubaivm"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.resourceGroup.name}"
  network_interface_ids = ["${azurerm_network_interface.nic.id}"]
  vm_size               = "Standard_A2"

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "mytdubaiosdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_data_disk {
    name            = "${azurerm_managed_disk.datadisk.name}"
    managed_disk_id = "${azurerm_managed_disk.datadisk.id}"
    create_option   = "Attach"
    lun             = 1
    disk_size_gb    = "${azurerm_managed_disk.datadisk.disk_size_gb}"
  }

  os_profile {
    computer_name  = "mytdubaihost"
    admin_username = "${var.username}"
    admin_password = "${var.password}"
  }

  os_profile_windows_config {
    enable_automatic_upgrades = true
    provision_vm_agent        = true

    winrm = {
      protocol = "http"
    }
  }
}


