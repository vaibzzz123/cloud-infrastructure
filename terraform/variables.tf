# OCI Authentication
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
  description = "OCI region identifier (e.g., ca-toronto-1)"
  type        = string
}

variable "compartment_ocid" {
  description = "OCID of the compartment to create resources in"
  type        = string
}

# SSH Key
variable "ssh_public_key_path" {
  description = "Path to SSH public key for instance access"
  type        = string
  default     = "~/.ssh/oci_k3s.pub"
}

# Network Configuration
variable "vcn_cidr" {
  description = "CIDR block for the VCN"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

# Instance Configuration
variable "k3s_server_ocpus" {
  description = "Number of OCPUs for k3s server node"
  type        = number
  default     = 2
}

variable "k3s_server_memory_gb" {
  description = "Memory in GB for k3s server node"
  type        = number
  default     = 8
}

variable "k3s_agent_ocpus" {
  description = "Number of OCPUs for k3s agent nodes"
  type        = number
  default     = 1
}

variable "k3s_agent_memory_gb" {
  description = "Memory in GB for k3s agent nodes"
  type        = number
  default     = 8
}

variable "k3s_agent_count" {
  description = "Number of k3s agent nodes"
  type        = number
  default     = 2
}

variable "boot_volume_size_gb" {
  description = "Boot volume size in GB for all instances"
  type        = number
  default     = 50
}
