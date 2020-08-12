# Configure the terrafom for Openstack
provider "openstack" {
  user_name   = "admin"
  password    = "openstack"
  auth_url    = "http://192.168.10.20:5000/v3"
  region      = "RegionOne"
  domain_name = "Default"
}

variable "network_id" {
  type        = string
  description = "op netwrok id"
  default     = "31cd60a6-07d7-4567-adc1-3aff17562fc7"
}
variable "network_name" {
  type        = string
  description = "op networ name"
  default     = "int-1"
}
locals {
  compute_instance = ["application", "database"]
}
variable "external_network" {
  default = "594b4134-f61d-4586-8e13-00943b85e8ef"
  type = string
}

resource "openstack_networking_network_v2" "terraform-network" {
  name           = "terraform-net1"
  admin_state_up = "true"

}
resource "openstack_networking_subnet_v2" "terra_subnet_1" {
  name       = "terra_subnet_1"
  network_id = "${openstack_networking_network_v2.terraform-network.id}"
  cidr       = "192.168.51.0/24"
  ip_version = 4
  enable_dhcp = true
}
resource "openstack_networking_router_v2" "terraform-R1" {
  name                = "terrafom-R1"
  admin_state_up      = true
  external_network_id = var.external_network
}
resource "openstack_networking_router_interface_v2" "int_1" {
  router_id = "${openstack_networking_router_v2.terraform-R1.id}"
  subnet_id = "${openstack_networking_subnet_v2.terra_subnet_1.id}"
}
resource "openstack_compute_secgroup_v2" "secgroup_1" {
  name        = "secgroup_1"
  description = "a security group"

  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }
}
resource "openstack_compute_keypair_v2" "my-lap" {
  name       = "my-lap"
  public_key = "${file("/Users/salimelattuparembil/.ssh/id_rsa.pub")}"
}
resource "openstack_compute_instance_v2" "OpenStack_instances" {
  for_each = toset(local.compute_instance)
  name = "${each.key}"
  region    = "RegionOne"
  image_id  = "331ae731-53f2-4ed1-9601-1da7891bb76d"
  flavor_id = "1908734a-ca07-4221-8a65-bc4888c4183f"
  key_pair  = "${openstack_compute_keypair_v2.my-lap.name}"
  security_groups = ["${openstack_compute_secgroup_v2.secgroup_1.name}"]

  network {
    uuid = "${openstack_networking_network_v2.terraform-network.id}"
    name = "${openstack_networking_network_v2.terraform-network.name}"
  }
}
resource "openstack_networking_floatingip_v2" "ip-pool" {
  for_each = toset(local.compute_instance)
  pool = "external"
}
resource "openstack_compute_floatingip_associate_v2" "vm_public" {
 for_each = toset(local.compute_instance)
  floating_ip = openstack_networking_floatingip_v2.ip-pool[each.key].address
  instance_id = openstack_compute_instance_v2.OpenStack_instances[each.key].id
}


output "ip" {
  value = "${openstack_networking_floatingip_v2.ip-pool}"
}
output "instance" {
  value = "${openstack_compute_instance_v2.OpenStack_instances}"
}