#-----------------------------------------------------------------#
# Pull credentials from vars                                      #
#-----------------------------------------------------------------#

# Configure the Microsoft Azure Provider
provider "azurerm" {
  subscription_id = "${var.azure_subscription_id}"
  client_id       = "${var.azure_client_id}"
  client_secret   = "${var.azure_client_secret}"
  tenant_id       = "${var.azure_tenant_id}"
}
data "azurerm_client_config" "current" {}

#-----------------------------------------------------------------#
# Create a dedicated group                                        #
#-----------------------------------------------------------------#

# Create a resource group
resource "azurerm_resource_group" "ori_homework_rg" {
  name     = "ori_homework_rg"
  location = "${var.azure_location}"

  tags {
    environment = "test"
    purpose     = "ORI-S Homework"
    owner       = "BP"
  }
}

#-----------------------------------------------------------------#
# Set up secrets for RDP/RM                                       #
#-----------------------------------------------------------------#

# Create a vault for WinRM certificate
resource "azurerm_key_vault" "ori-homework-kvault" {
  name                   = "ori-homework-kvault"
  location               = "${azurerm_resource_group.ori_homework_rg.location}"
  resource_group_name    = "${azurerm_resource_group.ori_homework_rg.name}"
  tenant_id              = "${data.azurerm_client_config.current.tenant_id}"

  enabled_for_deployment = "true"

  sku {
    name = "standard"
  }

  access_policy {
    tenant_id = "${data.azurerm_client_config.current.tenant_id}"
    object_id = "${data.azurerm_client_config.current.service_principal_object_id}"

    certificate_permissions = [
      "create", "delete", "deleteissuers", "get", "getissuers", "import",
      "list", "listissuers", "managecontacts", "manageissuers", "setissuers",
      "update",
    ]

    key_permissions = [
      "backup", "create", "decrypt", "delete", "encrypt", "get", "import",
      "list", "purge", "recover", "restore", "sign", "unwrapKey", "update",
      "verify", "wrapKey"
    ]

    secret_permissions = [
      "backup", "delete", "get", "list", "purge", "recover", "restore", "set"
    ]
  }

  tags {
    nodegroup   = "ori-homework"
  }
}

# Create a secret/certificate used for WinRM
resource "azurerm_key_vault_secret" "ori-homework-kvault-winrmcert" {
  name      = "ori-homework-kvault-winrmcert"
  value     = "${base64encode(file("secrets/winrm_secret.json"))}"
  vault_uri = "${azurerm_key_vault.ori-homework-kvault.vault_uri}"

  tags {
    nodegroup   = "ori-homework"
  }
}

#-----------------------------------------------------------------#
# Prepare network infrastructure                                  #
#-----------------------------------------------------------------#

# Create a private virtual network for instances
resource "azurerm_virtual_network" "ori_homework_vnet" {
  name                = "ori_homework_vnet"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.ori_homework_rg.location}"
  resource_group_name = "${azurerm_resource_group.ori_homework_rg.name}"
}

# Create a subnet within the private network
resource "azurerm_subnet" "ori_homework_subnet" {
  name                 = "ori_homework_subnet"
  resource_group_name  = "${azurerm_resource_group.ori_homework_rg.name}"
  virtual_network_name = "${azurerm_virtual_network.ori_homework_vnet.name}"
  address_prefix       = "10.0.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "ori_homework_publicip" {
  name                         = "ori_homework_publicip"
  location                     = "${azurerm_resource_group.ori_homework_rg.location}"
  resource_group_name          = "${azurerm_resource_group.ori_homework_rg.name}"
  public_ip_address_allocation = "dynamic"

  tags {
    nodegroup   = "ori-homework"
  }
}

# Create Security Group
resource "azurerm_network_security_group" "ori_homework_sg" {
  name                = "ori_homework_sg"
  location            = "${azurerm_resource_group.ori_homework_rg.location}"
  resource_group_name = "${azurerm_resource_group.ori_homework_rg.name}"

  security_rule {
    name                       = "RDP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags {
    nodegroup   = "ori-homework"
  }
}

# Create a network interface for the only instance we need
resource "azurerm_network_interface" "ori_homework_vni" {
  name                      = "ori_homework_vni"
  location                  = "${azurerm_resource_group.ori_homework_rg.location}"
  resource_group_name       = "${azurerm_resource_group.ori_homework_rg.name}"
  network_security_group_id = "${azurerm_network_security_group.ori_homework_sg.id}"

  # IP configuration should be dynamic, within the newly created subnet
  ip_configuration {
    name                          = "ori_homework_vni_ipconfig1"
    subnet_id                     = "${azurerm_subnet.ori_homework_subnet.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.ori_homework_publicip.id}"
  }
}

#-----------------------------------------------------------------#
# Prepare storage infrastructure                                  #
#-----------------------------------------------------------------#

# Create a storage account for VM disks
resource "azurerm_storage_account" "ori1homework1stracct" {
  name                     = "ori1homework1stracct"
  resource_group_name      = "${azurerm_resource_group.ori_homework_rg.name}"
  location                 = "${azurerm_resource_group.ori_homework_rg.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create a storage container for VM disks, within the storage account defined above
resource "azurerm_storage_container" "ori-homework-strcont" {
  name                  = "ori-homework-strcont"
  resource_group_name   = "${azurerm_resource_group.ori_homework_rg.name}"
  storage_account_name  = "${azurerm_storage_account.ori1homework1stracct.name}"
  container_access_type = "private"
}

#-----------------------------------------------------------------#
# Start the actual instance                                       #
#-----------------------------------------------------------------#

# Create the only VM instance we need, connected to the network and storage container defined above
resource "azurerm_virtual_machine" "ori-hw-vm1" {
  name                  = "ori-hw-vm1"
  location              = "${azurerm_resource_group.ori_homework_rg.location}"
  resource_group_name   = "${azurerm_resource_group.ori_homework_rg.name}"
  network_interface_ids = ["${azurerm_network_interface.ori_homework_vni.id}"]
  vm_size               = "Standard_A0"

  # Delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2016-Datacenter-Server-Core-smalldisk"
    version   = "latest"
  }

  storage_os_disk {
    name          = "ori-hw-vm1_osdisk"
    vhd_uri       = "${azurerm_storage_account.ori1homework1stracct.primary_blob_endpoint}${azurerm_storage_container.ori-homework-strcont.name}/ori-hw-vm1_osdisk.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  os_profile {
    computer_name  = "ori-hw-vm1"
    admin_username = "ori-hw-vm1"
    admin_password = "${var.azure_vm_admin_password}"
  }

  os_profile_secrets {
    source_vault_id = "${azurerm_key_vault.ori-homework-kvault.id}"

    vault_certificates {
      certificate_url   = "${azurerm_key_vault_secret.ori-homework-kvault-winrmcert.id}"
      certificate_store = "My"
    }
  }

  os_profile_windows_config {
    provision_vm_agent        = true
    enable_automatic_upgrades = true

    winrm {
      protocol        = "https"
      certificate_url = "${azurerm_key_vault_secret.ori-homework-kvault-winrmcert.id}"
    }
  }

  boot_diagnostics {
    enabled     = "true"
    storage_uri = "${azurerm_storage_account.ori1homework1stracct.primary_blob_endpoint}"
  }

  tags {
    nodegroup   = "ori-homework"
    designation = "vm1"
  }
}

#-----------------------------------------------------------------#
# Use an extension to pull in and exec scripts                    #
#-----------------------------------------------------------------#

resource "azurerm_virtual_machine_extension" "ori-hw-vm1" {
  name                 = "ori-hw-vm1"
  location             = "${azurerm_resource_group.ori_homework_rg.location}"
  resource_group_name  = "${azurerm_resource_group.ori_homework_rg.name}"
  virtual_machine_name = "${azurerm_virtual_machine.ori-hw-vm1.name}"
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.8"

   settings = <<SETTINGS
    {
      "fileUris": [
        "https://raw.githubusercontent.com/arax/ori.homework/master/scripts/ExampleScript.ps1",
        "https://raw.githubusercontent.com/arax/ori.homework/master/scripts/Ori.LocalServerCmdlets.psm1"
      ],
      "commandToExecute": "powershell.exe -ExecutionPolicy unrestricted -NoProfile -NonInteractive -File ExampleScript.ps1"
    }
SETTINGS

  tags {
    nodegroup   = "ori-homework"
    designation = "vm1"
  }
}

#-----------------------------------------------------------------#
# Output useful information                                       #
#-----------------------------------------------------------------#

data "azurerm_public_ip" "ori_homework_publicip" {
  name                = "${azurerm_public_ip.ori_homework_publicip.name}"
  resource_group_name = "${azurerm_resource_group.ori_homework_rg.name}"
  depends_on          = ["azurerm_virtual_machine.ori-hw-vm1"]
}

output "instance_public_ip" {
  value = "${data.azurerm_public_ip.ori_homework_publicip.ip_address}"
}

output "instance_rdp_access" {
  value = "ori-hw-vm1:${var.azure_vm_admin_password}"
}
