# Data sources for OCI resources

# Get availability domains
data "oci_identity_availability_domains" "all" {
  compartment_id = var.tenancy_ocid
}

# Pin the Ubuntu 24.04 aarch64 image so normal applies do not reimage nodes
# whenever OCI publishes a newer image.
locals {
  ubuntu_image_id = "ocid1.image.oc1.ca-toronto-1.aaaaaaaagbwu54enkqqowv7qzxxnxk5xpk4j2gztlfjmeqdksrsvtixxqnqa"
}
