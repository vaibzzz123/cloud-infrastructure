# k3s Server
output "k3s_server_public_ip" {
  description = "Public IP of the k3s server node"
  value       = oci_core_instance.k3s_server.public_ip
}

output "k3s_server_private_ip" {
  description = "Private IP of the k3s server node"
  value       = oci_core_instance.k3s_server.private_ip
}

# k3s Agents
output "k3s_agent_public_ips" {
  description = "Public IPs of the k3s agent nodes"
  value       = [for agent in oci_core_instance.k3s_agent : agent.public_ip]
}

output "k3s_agent_private_ips" {
  description = "Private IPs of the k3s agent nodes"
  value       = [for agent in oci_core_instance.k3s_agent : agent.private_ip]
}

# SSH Commands
locals {
  # Derive private key path from public key path (strip .pub extension)
  ssh_private_key_path = trimsuffix(var.ssh_public_key_path, ".pub")
}

output "ssh_commands" {
  description = "SSH commands to connect to each node"
  value = concat(
    ["ssh -i ${local.ssh_private_key_path} ubuntu@${oci_core_instance.k3s_server.public_ip}  # k3s-server"],
    [for i, agent in oci_core_instance.k3s_agent : "ssh -i ${local.ssh_private_key_path} ubuntu@${agent.public_ip}  # k3s-agent-${i + 1}"]
  )
}

# Network Info
output "vcn_id" {
  description = "OCID of the VCN"
  value       = oci_core_vcn.main.id
}

output "subnet_id" {
  description = "OCID of the public subnet"
  value       = oci_core_subnet.public.id
}
