variable address_space {
  default = "10.1.0.0/16"
}

variable vm_subnet {
  default = "10.1.0.0/24"
}

variable aks_subnet {
  default = "10.1.1.0/24"
}

# Azure reserves the first four and last IP address of a subnet
# Using the second last one for each subnet
variable private_ip_vm_ni {
  default = "10.1.0.254"
}

variable private_ip_aks_ni {
  default = "10.1.1.254"
}

variable username {
  default = "lorenzo"
  sensitive = true
}

variable public_key_path {
  default = "~/.ssh/id_rsa.pub"
  sensitive = true
}