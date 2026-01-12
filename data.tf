# Query existing OCI resources

# Compute
data "oci_core_instances" "all" {
  compartment_id = var.compartment_ocid
}

data "oci_core_boot_volumes" "all" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.all.availability_domains[0].name
}

data "oci_core_volumes" "all" {
  compartment_id = var.compartment_ocid
}

# Networking
data "oci_core_vcns" "all" {
  compartment_id = var.compartment_ocid
}

data "oci_core_subnets" "all" {
  compartment_id = var.compartment_ocid
}

data "oci_core_internet_gateways" "all" {
  compartment_id = var.compartment_ocid
}

data "oci_core_nat_gateways" "all" {
  compartment_id = var.compartment_ocid
}

data "oci_core_route_tables" "all" {
  compartment_id = var.compartment_ocid
}

data "oci_core_security_lists" "all" {
  compartment_id = var.compartment_ocid
}

data "oci_core_network_security_groups" "all" {
  compartment_id = var.compartment_ocid
}

data "oci_core_public_ips" "all" {
  compartment_id = var.compartment_ocid
  scope          = "REGION"
}

# Identity
data "oci_identity_availability_domains" "all" {
  compartment_id = var.tenancy_ocid
}
