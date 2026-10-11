# Data sources for OCI resources

# Get availability domains
data "oci_identity_availability_domains" "all" {
  compartment_id = var.tenancy_ocid
}

# Pin platform images so normal applies do not reimage instances whenever OCI
# publishes a newer image.
locals {
  # Ubuntu 24.04 aarch64 image
  ubuntu_image_id         = "ocid1.image.oc1.ca-toronto-1.aaaaaaaagbwu54enkqqowv7qzxxnxk5xpk4j2gztlfjmeqdksrsvtixxqnqa"
  # Ubuntu 24.04 x86_64 minimal image
  uptime_monitor_image_id = "ocid1.image.oc1.ca-toronto-1.aaaaaaaajviq6nbdoksf5bhp5q2hifsl7wangst2espqxzmdzhg7visgameq"
}
