# Data sources for OCI resources

# Get availability domains
data "oci_identity_availability_domains" "all" {
  compartment_id = var.tenancy_ocid
}

# Get latest Ubuntu 24.04 aarch64 image (for ARM instances)
data "oci_core_images" "ubuntu_24_04" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}
