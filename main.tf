data "azurerm_resource_group" "rg" {
  name = "BU-MT"
}

data "azurerm_virtual_network" "vn" {
  name = "BU-MT-vnet-TF"
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "vm_subnet" {
  name = "${var.prefix}-vm-subnet"
  resource_group_name = data.azurerm_resource_group.rg.name
  virtual_network_name = data.azurerm_virtual_network.vn.name
  address_prefixes = [var.vm_subnet]
}

resource "azurerm_subnet" "aks_subnet" {
  name = "${var.prefix}-aks-subnet"
  resource_group_name = data.azurerm_resource_group.rg.name
  virtual_network_name = data.azurerm_virtual_network.vn.name
  address_prefixes = [var.aks_subnet]
}

resource "azurerm_subnet" "inner_lb_subnet" {
  name = "${var.prefix}-inner-lb-subnet"
  resource_group_name = data.azurerm_resource_group.rg.name
  virtual_network_name = data.azurerm_virtual_network.vn.name
  address_prefixes = [var.inner_lb_subnet]
}

#load balancer between AKS and VM
resource "azurerm_lb" "inner_lb" {
  name = "${var.prefix}-inner-lb"
  location = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku = "Basic"

  frontend_ip_configuration {
    name = "img_repo"
    subnet_id = azurerm_subnet.inner_lb_subnet.id
    private_ip_address = var.private_ip_inner_lb
    private_ip_address_allocation = "Static"
  }
}

resource "azurerm_lb_nat_rule" "vm_nat_rule" {
  resource_group_name = data.azurerm_resource_group.rg.name
  loadbalancer_id = azurerm_lb.inner_lb.id
  name = "ImgRepoAccess"
  protocol = "Tcp"
  frontend_port = 443
  backend_port = 443
  frontend_ip_configuration_name = "img_repo"
}

resource "azurerm_network_interface" "vm_ni" {
  name = "${var.prefix}-vm-ni"
  location = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name = "vm_ni_configuration"
    subnet_id = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address = var.private_ip_vm_ni
  }
}

resource "azurerm_network_interface_nat_rule_association" "vm_nat_rule" {
  network_interface_id = azurerm_network_interface.vm_ni.id
  ip_configuration_name = azurerm_network_interface.vm_ni.ip_configuration[0].name
  nat_rule_id = azurerm_lb_nat_rule.vm_nat_rule.id
}

resource "azurerm_network_security_group" "nsg" {
  name = "${var.prefix}-vm-nsg"
  location = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "ssh-nsg" {
  resource_group_name = data.azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
  name = "SSH"
  priority = 100
  access = "Allow"
  direction = "Inbound"
  protocol = "Tcp"
  source_port_range = "*"
  destination_port_range = "22"
  source_address_prefix = "*"
  destination_address_prefix = var.vm_subnet
}

resource "azurerm_subnet_network_security_group_association" "vm_subnet_nsg" {
  subnet_id = azurerm_subnet.vm_subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_linux_virtual_machine" "vm" {
  name = "${var.prefix}-ImgRepo"
  resource_group_name = data.azurerm_resource_group.rg.name
  location = data.azurerm_resource_group.rg.location
  size = "Standard_B1s"
  admin_username = "lorenzo"
  network_interface_ids = [azurerm_network_interface.vm_ni.id]

  admin_ssh_key {
    username = var.username
    public_key = file(var.public_key_path)
  }

  os_disk {
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer = "UbuntuServer"
    sku = "16.04-LTS"
    version = "latest"
  }
}

resource "azurerm_kubernetes_cluster" "aks" {
  name = "${var.prefix}-aks"
  location = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  dns_prefix = "aks-prefix"

  default_node_pool {
    name = "default"
    node_count = 1
    vm_size = "Standard_D2_v2"
    vnet_subnet_id = azurerm_subnet.aks_subnet.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    service_cidr = var.service_cidr # if not specified, defaults to 10.0.0.0/16 => leads to CIDR overlapping
    dns_service_ip = var.dns_service_ip
    docker_bridge_cidr = var.docker_bridge_cidr
  }
}
