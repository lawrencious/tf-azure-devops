resource "azurerm_resource_group" "rg" {
  name = "rg"
  location = "UK South"
}

resource "azurerm_virtual_network" "vn" {
  name = "vn"
  resource_group_name = azurerm_resource_group.rg.name
  address_space = [var.address_space]
  location = azurerm_resource_group.rg.location
}

resource "azurerm_subnet" "vm_subnet" {
  name = "vm_subnet"
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vn.name
  address_prefixes = [var.vm_subnet]
}

resource "azurerm_subnet" "aks_subnet" {
  name = "aks_subnet"
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vn.name
  address_prefixes = [var.aks_subnet]
}

resource "azurerm_subnet" "inner_lb_subnet" {
  name = "inner_lb_subnet"
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vn.name
  address_prefixes = [var.inner_lb_subnet]
}

resource "azurerm_public_ip" "vm_ip" {
  name = "vm_ip"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method = "Static"
}

#load balancer between AKS and VM
resource "azurerm_lb" "inner_lb" {
  name = "inner_lb"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku = "Basic"

  frontend_ip_configuration {
    name = "img_repo"
    subnet_id = azurerm_subnet.inner_lb_subnet.id
    private_ip_address = var.private_ip_inner_lb
    private_ip_address_allocation = "Static"
  }
}

resource "azurerm_lb_nat_rule" "vm_nat_rule" {
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id = azurerm_lb.inner_lb.id
  name = "ImgRepoAccess"
  protocol = "Tcp"
  frontend_port = 443
  backend_port = 443
  frontend_ip_configuration_name = "img_repo"
}

resource "azurerm_network_interface" "vm_ni" {
  name = "vm_ni"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

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

resource "azurerm_network_security_rule" "img_req" { # AKS HTTPS requesting img to ImgRepo
  name = "ImgReq"
  priority = 102
  direction = "Outbound"
  access = "Allow"
  protocol = "Tcp"
  source_port_range = "*"
  destination_port_range = "443"
  source_address_prefix = var.aks_subnet
  destination_address_prefixes = [azurerm_lb.inner_lb.private_ip_address]
  resource_group_name = azurerm_kubernetes_cluster.aks.node_resource_group # reference the auto-generated RG containing the resources for this cluster
  network_security_group_name = data.azurerm_resources.aks_nsg_name.resources.0.name
}

resource "azurerm_network_security_rule" "img_req_acc" { # accepts HTTPS traffic from ImgRepo to AKS
  name = "ImgReqAccept"
  priority = 103
  direction = "Inbound"
  access = "Allow"
  protocol = "Tcp"
  source_port_range = "443"
  destination_port_range = "*"
  source_address_prefixes = [azurerm_lb.inner_lb.private_ip_address]
  destination_address_prefix = var.aks_subnet
  resource_group_name = azurerm_kubernetes_cluster.aks.node_resource_group # reference the auto-generated RG containing the resources for this cluster
  network_security_group_name = data.azurerm_resources.aks_nsg_name.resources.0.name
}

resource "azurerm_linux_virtual_machine" "vm" {
  name = "ImgRepo"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
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
  name = "aks"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
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
  }
}
