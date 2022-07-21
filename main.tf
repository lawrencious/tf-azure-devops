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
  sku = "Standard"

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

resource "azurerm_lb_backend_address_pool" "be_pool" {
  name = "inner_lb_be_pool"
  loadbalancer_id = azurerm_lb.inner_lb.id
}

resource "azurerm_lb_backend_address_pool_address" "be_pool_vm_address" {
  name = "be_pool_vm_address"
  backend_address_pool_id = azurerm_lb_backend_address_pool.be_pool.id
  virtual_network_id = azurerm_virtual_network.vn.id
  ip_address = azurerm_public_ip.vm_ip.ip_address
}

resource "azurerm_network_interface" "aks_ni" {
  name = "aks_ni"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name = "aks_ni_configuration"
    subnet_id = azurerm_subnet.aks_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address = var.private_ip_aks_ni
  }
}

resource "azurerm_network_interface_nat_rule_association" "vm_nat_rule" {
  network_interface_id = azurerm_network_interface.vm_ni.id
  ip_configuration_name = azurerm_network_interface.vm_ni.ip_configuration[0].name
  nat_rule_id = azurerm_lb_nat_rule.vm_nat_rule.id
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name = "HTTPS-In"
    priority = 100
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "443"
    source_address_prefixes = [azurerm_lb.inner_lb.private_ip_address]
    destination_address_prefix = var.vm_subnet
  }

  security_rule {
    name = "HTTPS-Out"
    priority = 101
    direction = "Outbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "443"
    destination_port_range = "*"
    source_address_prefix = var.vm_subnet
    destination_address_prefixes = [azurerm_lb.inner_lb.private_ip_address]
  }
}

resource "azurerm_network_interface_security_group_association" "ni_nsg_association" {
  network_interface_id      = azurerm_network_interface.vm_ni.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

/*resource "azurerm_route_table" "rt" {
  name = "rt"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_route" "route" {
  name = "route"
  resource_group_name = azurerm_resource_group.rg.name
  route_table_name = azurerm_route_table.rt.name
  address_prefix = azurerm_subnet.aks_subnet.address_prefixes[0]
  next_hop_type = "VnetLocal"
}*/

resource "azurerm_linux_virtual_machine" "vm" {
  name = "NexusRepo"
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