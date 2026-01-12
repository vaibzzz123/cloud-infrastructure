# Compute Resources
output "instances" {
  description = "Existing compute instances"
  value = [for i in data.oci_core_instances.all.instances : {
    name  = i.display_name
    state = i.state
    shape = i.shape
  }]
}

output "boot_volumes" {
  description = "Existing boot volumes"
  value = [for v in data.oci_core_boot_volumes.all.boot_volumes : {
    name    = v.display_name
    size_gb = v.size_in_gbs
    state   = v.state
  }]
}

output "block_volumes" {
  description = "Existing block volumes"
  value = [for v in data.oci_core_volumes.all.volumes : {
    name    = v.display_name
    size_gb = v.size_in_gbs
    state   = v.state
  }]
}

# Networking Resources
output "vcns" {
  description = "Existing VCNs"
  value = [for v in data.oci_core_vcns.all.virtual_networks : {
    name = v.display_name
    cidr = v.cidr_block
  }]
}

output "subnets" {
  description = "Existing subnets"
  value = [for s in data.oci_core_subnets.all.subnets : {
    name   = s.display_name
    cidr   = s.cidr_block
    public = s.prohibit_public_ip_on_vnic ? "private" : "public"
  }]
}

output "internet_gateways" {
  description = "Existing internet gateways"
  value = [for g in data.oci_core_internet_gateways.all.gateways : {
    name    = g.display_name
    enabled = g.enabled
  }]
}

output "nat_gateways" {
  description = "Existing NAT gateways"
  value = [for g in data.oci_core_nat_gateways.all.nat_gateways : {
    name  = g.display_name
    state = g.state
  }]
}

output "route_tables" {
  description = "Existing route tables"
  value = [for r in data.oci_core_route_tables.all.route_tables : {
    name        = r.display_name
    route_count = length(r.route_rules)
  }]
}

output "security_lists" {
  description = "Existing security lists"
  value = [for s in data.oci_core_security_lists.all.security_lists : {
    name          = s.display_name
    ingress_rules = length(s.ingress_security_rules)
    egress_rules  = length(s.egress_security_rules)
  }]
}

output "network_security_groups" {
  description = "Existing network security groups"
  value = [for n in data.oci_core_network_security_groups.all.network_security_groups : {
    name  = n.display_name
    state = n.state
  }]
}

output "public_ips" {
  description = "Existing reserved public IPs"
  value = [for p in data.oci_core_public_ips.all.public_ips : {
    name       = p.display_name
    ip_address = p.ip_address
    lifetime   = p.lifetime
  }]
}

output "availability_domains" {
  description = "Available availability domains"
  value       = [for ad in data.oci_identity_availability_domains.all.availability_domains : ad.name]
}
