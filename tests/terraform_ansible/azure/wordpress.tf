###################
# Credentials
###################

# variable "azure_subscription_id" {
#     type    = string
# }

# variable "azure_tenant_id" {
#     type    = string
# }

# variable "azure_client_id" {
#     type    = string
# }

# variable "azure_client_secret" {
#     type    = string
# }

###################
# Variables
###################

variable "region_name" {
    type    = string
    default = "westus2"
}

variable "availability_zone" {
    type    = string
    default = ""
}

variable "admin_username" {
    default = "manager"
}

variable "db_name" {
  type    = string
  default = "wordpress"
}

variable "db_user" {
  type    = string
  default = "wpuser"
}

variable "db_pass" {
  type    = string
  default = "w@rdpr3sS"
}

variable "public_key" {
  type    = string
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC0TiCJf98bz/0CDedyGS3Y8wC1Zn2L/xq3WguJL2A+rCl7wWOEDXzyyToHRrbjMARbmPfHxl0+JvmUgJv9H7Yml84bzyPhdXO0AfswcTS1HyVLAD5oH1cs38jUSqOupHnZtvOJ0RoG29SL0KJiDwDhUYSe0xnGNS1EP+oQZJU7X0RGc2c6ZqT70FEzizG9mSAxtw8W0HlrLA+EDEYSjIjEHrMs7G8i/bVJFRbF/jTG1oDzomL535VBzKbQgsgD4No4Mq0fnt5ZxpZF4Q3QYo2U7oO9vfLMTWBpsNAroQggz74/AH3E6qfzMOvawmKhM84astzcbSXFGhGXsKLYbTk1"
}

variable "private_key_path" {
  type    = string
  default = "../keys/wordpress.pem"
}

###################
# Provider
###################

provider "azurerm" {
  # subscription_id = "${var.azure_subscription_id}"
  # tenant_id       = "${var.azure_tenant_id}"
  # client_id       = "${var.azure_client_id}"
  # client_secret   = "${var.azure_client_secret}"
  features {}
}

resource "random_id" "bp_suffix" {
  byte_length = 4
}

resource "azurerm_availability_set" "wordpress-availability" {
  name                = "wordpress-availability-${random_id.bp_suffix.hex}"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
  managed             = true
}

resource "azurerm_resource_group" "main" {
  name     = "wordpress-${random_id.bp_suffix.hex}"
  location = "${var.region_name}"
}

###################
# Database layer
###################

resource "azurerm_virtual_machine" "wordpress-database" {
  name                  = "wordpress-database-${random_id.bp_suffix.hex}"
  location              = "${azurerm_resource_group.main.location}"
  resource_group_name   = "${azurerm_resource_group.main.name}"
  network_interface_ids = ["${azurerm_network_interface.database.id}"]
  vm_size               = "Standard_B1ls"
  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true
  availability_set_id = "${azurerm_availability_set.wordpress-availability.id}"

  os_profile_linux_config{
    disable_password_authentication = true
    ssh_keys{
      key_data = "${var.public_key}"
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
    }
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "14.04.5-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "wordpress-database-disc-${random_id.bp_suffix.hex}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "wordpress-database-${random_id.bp_suffix.hex}"
    admin_username = "${var.admin_username}"
  }

  provisioner "remote-exec" {
    inline = ["sudo apt update", "sudo apt install python3 -y", "echo Done!"]

    connection {
      host        = "${azurerm_public_ip.static-ip-database.ip_address}"
      type        = "ssh"
      user        = "${var.admin_username}"
      private_key = file(var.private_key_path)
    }
  }

  provisioner "local-exec" {

    # The private key is on another path due to permissions error
    # on the Azure Cloud Shell
    command = <<EOT
        ANSIBLE_HOST_KEY_CHECKING=False \
        ansible-playbook \
        -u ${var.admin_username} \
        -i '${azurerm_public_ip.static-ip-database.ip_address},' \
        --private-key '${var.private_key_path}' \
        --extra-vars "{ \
          "database_name": "${var.db_name}", \
          "database_user": "${var.db_user}", \
          "database_password": "${var.db_pass}", \
        }" \
        ../ansible/playbook_database.yaml
      EOT

  }
}


###################
# Apps layer
###################

resource "azurerm_virtual_machine" "wordpress-app1" {
  name                  = "wordpress-app1-${random_id.bp_suffix.hex}"
  location              = "${azurerm_resource_group.main.location}"
  resource_group_name   = "${azurerm_resource_group.main.name}"
  network_interface_ids = ["${azurerm_network_interface.app1.id}"]
  vm_size               = "Standard_B1ls"
  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true
  availability_set_id = "${azurerm_availability_set.wordpress-availability.id}"

  os_profile_linux_config{
    disable_password_authentication = true
    ssh_keys{
      key_data = "${var.public_key}"
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
    }
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "14.04.5-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "wordpress-app1-disc-${random_id.bp_suffix.hex}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "wordpress-app1-${random_id.bp_suffix.hex}"
    admin_username = "${var.admin_username}"
  }

  provisioner "remote-exec" {
    inline = ["sudo apt update", "sudo apt install python3 -y", "echo Done!"]

    connection {
      host        = "${azurerm_public_ip.static-ip1.ip_address}"
      type        = "ssh"
      user        = "${var.admin_username}"
      private_key = file(var.private_key_path)
    }
  }

  provisioner "local-exec" {

    # The private key is on another path due to permissions error
    # on the Azure Cloud Shell
    command = <<EOT
        ANSIBLE_HOST_KEY_CHECKING=False \
        ansible-playbook \
        -u ${var.admin_username} \
        -i '${azurerm_public_ip.static-ip1.ip_address},' \
        --private-key '${var.private_key_path}' \
        --extra-vars "{ \
          "database_host": "${azurerm_public_ip.static-ip-database.ip_address}", \
          "database_name": "${var.db_name}", \
          "database_user": "${var.db_user}", \
          "database_password": "${var.db_pass}", \
        }" \
        ../ansible/playbook.yaml
      EOT

  }
}

resource "azurerm_virtual_machine" "wordpress-app2" {
  name                  = "wordpress-app2-${random_id.bp_suffix.hex}"
  location              = "${azurerm_resource_group.main.location}"
  resource_group_name   = "${azurerm_resource_group.main.name}"
  network_interface_ids = ["${azurerm_network_interface.app2.id}"]
  vm_size               = "Standard_B1ls"
  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true
  availability_set_id = "${azurerm_availability_set.wordpress-availability.id}"

  os_profile_linux_config{
    disable_password_authentication = true
    ssh_keys{
      key_data = "${var.public_key}"
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
    }
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "14.04.5-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "wordpress-app2-disc-${random_id.bp_suffix.hex}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "wordpress-app2-${random_id.bp_suffix.hex}"
    admin_username = "${var.admin_username}"
  }

  provisioner "remote-exec" {
    inline = ["sudo apt update", "sudo apt install python3 -y", "echo Done!"]

    connection {
      host        = "${azurerm_public_ip.static-ip2.ip_address}"
      type        = "ssh"
      user        = "${var.admin_username}"
      private_key = file(var.private_key_path)
    }
  }

  provisioner "local-exec" {

    # The private key is on another path due to permissions error
    # on the Azure Cloud Shell
    command = <<EOT
        ANSIBLE_HOST_KEY_CHECKING=False \
        ansible-playbook \
        -u ${var.admin_username} \
        -i '${azurerm_public_ip.static-ip2.ip_address},' \
        --private-key '${var.private_key_path}' \
        --extra-vars "{ \
          "database_host": "${azurerm_public_ip.static-ip-database.ip_address}", \
          "database_name": "${var.db_name}", \
          "database_user": "${var.db_user}", \
          "database_password": "${var.db_pass}", \
        }" \
        ../ansible/playbook.yaml
      EOT

  }

}

###################
# Network layer
###################

resource "azurerm_public_ip" "static-ip1" {
  name                = "wordpress-static-ip1-${random_id.bp_suffix.hex}"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
  allocation_method   = "Static"
}

resource "azurerm_public_ip" "static-ip2" {
  name                = "wordpress-static-ip2-${random_id.bp_suffix.hex}"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
  allocation_method   = "Static"
}

resource "azurerm_public_ip" "static-ip-database" {
  name                = "wordpress-static-ipdatabase-${random_id.bp_suffix.hex}"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
  allocation_method   = "Static"
}

resource "azurerm_virtual_network" "main" {
  name                = "wordpress-network-${random_id.bp_suffix.hex}"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
}

resource "azurerm_subnet" "internal" {
  name                 = "wordpress-subnet-${random_id.bp_suffix.hex}"
  resource_group_name  = "${azurerm_resource_group.main.name}"
  virtual_network_name = "${azurerm_virtual_network.main.name}"
  address_prefixes     = [ "10.0.2.0/24" ]
}

resource "azurerm_network_interface" "app1" {
  name                = "wordpress-app1-nic-${random_id.bp_suffix.hex}"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"

  ip_configuration {
    name                          = "wordpress-ip1-config-${random_id.bp_suffix.hex}"
    subnet_id                     = "${azurerm_subnet.internal.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.static-ip1.id}"
  }
}

resource "azurerm_network_interface" "app2" {
  name                = "wordpress-app2-nic-${random_id.bp_suffix.hex}"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"

  ip_configuration {
    name                          = "wordpress-ip2-config-${random_id.bp_suffix.hex}"
    subnet_id                     = "${azurerm_subnet.internal.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.static-ip2.id}"
  }
}

resource "azurerm_network_interface" "database" {
  name                = "wordpress-database-nic-${random_id.bp_suffix.hex}"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"

  ip_configuration {
    name                          = "wordpress-database-config-${random_id.bp_suffix.hex}"
    subnet_id                     = "${azurerm_subnet.internal.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.static-ip-database.id}"
  }
}

###################
# Outputs
###################

output "App1-addres" {
  value = "${azurerm_public_ip.static-ip1.ip_address}"
}

output "App2-addres" {
  value = "${azurerm_public_ip.static-ip2.ip_address}"
}

output "Database-addres" {
  value = "${azurerm_public_ip.static-ip-database.ip_address}"
}

output "apply-finished-wp" {
  value = "true"
}
