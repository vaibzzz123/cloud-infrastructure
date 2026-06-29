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

variable "trusted_cidrs" {
  description = "Public CIDRs allowed to access the k3s API"
  type        = set(string)
  default     = []

  validation {
    condition     = length(var.trusted_cidrs) > 0
    error_message = "Set at least one trusted CIDR so public k3s API access is restricted but available."
  }

  validation {
    condition     = alltrue([for cidr in var.trusted_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Each trusted CIDR must be a valid CIDR block, for example 203.0.113.10/32."
  }
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
