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

resource "azurerm_subnet" "agic_subnet" {
  name = "${var.prefix}-agic-subnet"
  resource_group_name = data.azurerm_resource_group.rg.name
  virtual_network_name = data.azurerm_virtual_network.vn.name
  address_prefixes = [var.agic_subnet]
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

resource "azurerm_public_ip" "vm_pub_ip" {
  name = "${var.prefix}-vm-ip"
  resource_group_name = data.azurerm_resource_group.rg.name
  location = data.azurerm_resource_group.rg.location
  allocation_method = "Static"
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
    public_ip_address_id = azurerm_public_ip.vm_pub_ip.id
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

  security_rule = [ 
    {
      name = "SSH"
      priority = 100
      access = "Allow"
      direction = "Inbound"
      protocol = "Tcp"
      source_port_range = "*"
      destination_port_range = "22"
      source_address_prefix = "*"
      destination_address_prefix = "*"
      description = ""
      destination_address_prefixes = []
      destination_application_security_group_ids = []
      destination_port_ranges = []
      source_address_prefixes = []
      source_application_security_group_ids = []
      source_port_ranges = []
    }, 
    {
    name = "Port8082"
    priority = 110
    access = "Allow"
    direction = "Inbound"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "8082"
    source_address_prefix = "*"
    destination_address_prefix = azurerm_public_ip.vm_pub_ip.ip_address
    description = ""
    destination_address_prefixes = []
    destination_application_security_group_ids = []
    destination_port_ranges = []
    source_address_prefixes = []
    source_application_security_group_ids = []
    source_port_ranges = []
  },
  {
    name = "HTTPIn"
    priority = 120
    access = "Allow"
    direction = "Inbound"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "80"
    source_address_prefix = "*"
    destination_address_prefix = azurerm_public_ip.vm_pub_ip.ip_address
    description = ""
    destination_address_prefixes = []
    destination_application_security_group_ids = []
    destination_port_ranges = []
    source_address_prefixes = []
    source_application_security_group_ids = []
    source_port_ranges = []
  }, 
  {
    name = "HTTPOut"
    priority = 120
    access = "Allow"
    direction = "Outbound"
    protocol = "Tcp"
    source_port_range = "80"
    destination_port_range = "*"
    source_address_prefix = azurerm_public_ip.vm_pub_ip.ip_address
    destination_address_prefix = "*"
    description = ""
    destination_address_prefixes = []
    destination_application_security_group_ids = []
    destination_port_ranges = []
    source_address_prefixes = []
    source_application_security_group_ids = []
    source_port_ranges = []
  }, 
  {
    name = "HTTPSIn"
    priority = 130
    access = "Allow"
    direction = "Inbound"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "443"
    source_address_prefix = "*"
    destination_address_prefix = azurerm_public_ip.vm_pub_ip.ip_address
    description = ""
    destination_address_prefixes = []
    destination_application_security_group_ids = []
    destination_port_ranges = []
    source_address_prefixes = []
    source_application_security_group_ids = []
    source_port_ranges = []
  }, 
  {
    name = "HTTPSOut"
    priority = 130
    access = "Allow"
    direction = "Outbound"
    protocol = "Tcp"
    source_port_range = "443"
    destination_port_range = "*"
    source_address_prefix = azurerm_public_ip.vm_pub_ip.ip_address
    destination_address_prefix = "*"
    description = ""
    destination_address_prefixes = []
    destination_application_security_group_ids = []
    destination_port_ranges = []
    source_address_prefixes = []
    source_application_security_group_ids = []
    source_port_ranges = []
  } ]
}

resource "azurerm_linux_virtual_machine" "vm" {
  name = "${var.prefix}-ImgRepo"
  resource_group_name = data.azurerm_resource_group.rg.name
  location = data.azurerm_resource_group.rg.location
  size = "Standard_B2s"
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
    sku = "18.04-LTS"
    version = "latest"
  }
}

resource "azurerm_public_ip" "agic-ip" {
  name                = "${var.prefix}-agic-ip"
  resource_group_name = data.azurerm_resource_group.rg.name
  location = data.azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku = "Standard"
}

resource "azurerm_application_gateway" "agic" {
  name                = "${var.prefix}-agic"
  resource_group_name = data.azurerm_resource_group.rg.name
  location = data.azurerm_resource_group.rg.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.agic_subnet.id
  }

  frontend_port {
    name = "agic-fe-port-name"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "agic-fe-ip-conf-name"
    public_ip_address_id = azurerm_public_ip.agic-ip.id
  }

  backend_address_pool {
    name = "agic-be-pool-name"
  }

  backend_http_settings {
    name                  = "agic-http-settings-name"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = "agic-http-listener-name"
    frontend_ip_configuration_name = "agic-fe-ip-conf-name"
    frontend_port_name             = "agic-fe-port-name"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "agic-routing-rule-name"
    rule_type                  = "Basic"
    http_listener_name         = "agic-http-listener-name"
    backend_address_pool_name  = "agic-be-pool-name"
    backend_http_settings_name = "agic-http-settings-name"
    priority = 1
  }
}

resource "azurerm_kubernetes_cluster" "aks" {
  name = "${var.prefix}-aks"
  location = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  dns_prefix = "aks-prefix"

  default_node_pool {
    name = "default"
    node_count = 2
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

  ingress_application_gateway {
    gateway_id = azurerm_application_gateway.agic.id
  }
}

# ERROR: resulting list is empty with AKS node RG
data "azurerm_resources" "aks-vnet" {
  resource_group_name = azurerm_kubernetes_cluster.aks.node_resource_group
  type = "Microsoft.Network/virtualNetworks"
}

output "value" {
  value = azurerm_kubernetes_cluster.aks.node_resource_group
}

output "value2" {
  value = data.azurerm_resources.aks-vnet
}

resource "azurerm_virtual_network_peering" "peerAGICtoAKS" {
  name                      = "${var.prefix}-peer-agic2aks"
  resource_group_name       = data.azurerm_resource_group.rg.name
  virtual_network_name      = data.azurerm_virtual_network.vn.name
  remote_virtual_network_id = data.azurerm_resources.aks-vnet.resources[0].id
}

resource "azurerm_virtual_network_peering" "peerAKStoAGIC" {
  name                      = "${var.prefix}-peer-aks2agic"
  resource_group_name       = data.azurerm_resource_group.rg.name
  virtual_network_name      = data.azurerm_resources.aks-vnet.resources[0].name
  remote_virtual_network_id = data.azurerm_virtual_network.vn.id
}