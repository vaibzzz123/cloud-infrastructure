variable "tenancy_ocid" {
  description = "OCID of your OCI tenancy"
  type        = string
}

variable "user_ocid" {
  description = "OCID of the user calling the API"
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint of the API signing key"
  type        = string
}

variable "private_key_path" {
  description = "Path to the private key file for API signing"
  type        = string
}

variable "region" {
  description = "OCI region identifier (e.g., us-ashburn-1, eu-frankfurt-1)"
  type        = string
}

variable "compartment_ocid" {
  description = "OCID of the compartment to create resources in"
  type        = string
}
