terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 7.0"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# =============================================================================
# NETWORKING
# =============================================================================

# Virtual Cloud Network
resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "main-vcn"
  dns_label      = "main"
}

# Internet Gateway
resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "internet-gateway"
  enabled        = true
}

# Route Table
resource "oci_core_route_table" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main.id
  }
}

# Security List
resource "oci_core_security_list" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "security-list"

  # Allow all egress
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # SSH from anywhere
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }

  # HTTP from anywhere
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }

  # HTTPS from anywhere
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }

  # Kubernetes API server, only from trusted CIDRs
  dynamic "ingress_security_rules" {
    for_each = var.trusted_cidrs
    iterator = cidr

    content {
      protocol = "6"
      source   = cidr.value

      tcp_options {
        min = 6443
        max = 6443
      }
    }
  }

  # Allow all traffic within VCN (for internal node communication)
  ingress_security_rules {
    protocol = "all"
    source   = var.vcn_cidr
  }

  # ICMP for path discovery
  ingress_security_rules {
    protocol = "1" # ICMP
    source   = "0.0.0.0/0"
    icmp_options {
      type = 3
      code = 4
    }
  }
}

# Public Subnet
resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = var.subnet_cidr
  display_name               = "public-subnet"
  dns_label                  = "public"
  route_table_id             = oci_core_route_table.main.id
  security_list_ids          = [oci_core_security_list.main.id]
  prohibit_public_ip_on_vnic = false
}

# =============================================================================
# COMPUTE INSTANCES
# =============================================================================

locals {
  availability_domain = data.oci_identity_availability_domains.all.availability_domains[0].name
  ubuntu_image_id     = data.oci_core_images.ubuntu_24_04.images[0].id
  ssh_public_key      = file(pathexpand(var.ssh_public_key_path))
}

# k3s Server Node
resource "oci_core_instance" "k3s_server" {
  compartment_id      = var.compartment_ocid
  availability_domain = local.availability_domain
  display_name        = "k3s-server"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.k3s_server_ocpus
    memory_in_gbs = var.k3s_server_memory_gb
  }

  source_details {
    source_type             = "image"
    source_id               = local.ubuntu_image_id
    boot_volume_size_in_gbs = var.boot_volume_size_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    display_name     = "k3s-server-vnic"
    hostname_label   = "k3s-server"
  }

  metadata = {
    ssh_authorized_keys = local.ssh_public_key
  }
}

# k3s Agent Nodes
resource "oci_core_instance" "k3s_agent" {
  count               = var.k3s_agent_count
  compartment_id      = var.compartment_ocid
  availability_domain = local.availability_domain
  display_name        = "k3s-agent-${count.index + 1}"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.k3s_agent_ocpus
    memory_in_gbs = var.k3s_agent_memory_gb
  }

  source_details {
    source_type             = "image"
    source_id               = local.ubuntu_image_id
    boot_volume_size_in_gbs = var.boot_volume_size_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    display_name     = "k3s-agent-${count.index + 1}-vnic"
    hostname_label   = "k3s-agent-${count.index + 1}"
  }

  metadata = {
    ssh_authorized_keys = local.ssh_public_key
  }
}
