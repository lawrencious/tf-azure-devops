variable prefix {
  default = "tf-ado"
}

# Address space in use is BU-MT-vnet-TF
# Subnets
variable vm_subnet {
  default = "10.1.1.0/24"
}

variable aks_subnet {
  default = "10.1.2.0/24"
}

variable inner_lb_subnet {
  default = "10.1.3.0/24"
}

# Definition of (aks.network_profile.) service_cidr, dns_service_ip,
#   docker_bridge_cidr.
# To avoid conflicts between Service CIDR and other nets/vnets - the following
#   must be either empty or defined altogether 
variable service_cidr {
  default = "10.255.0.0/16"
}

variable dns_service_ip {
  default = "10.255.0.254"
}

variable docker_bridge_cidr {
  default = "172.17.0.0/16"
}

# Azure reserves the first four and last IP address of a subnet
# Using the second last one for each subnet
variable private_ip_vm_ni {
  default = "10.1.1.254"
}

variable private_ip_inner_lb {
  default = "10.1.3.254"
}

variable username {
  default = "lorenzo"
  sensitive = true
}

variable public_key_path {
  default = "~/.ssh/id_rsa.pub"
  sensitive = true
}
