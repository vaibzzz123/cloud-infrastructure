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

# Uptime Monitor
output "uptime_monitor_public_ip" {
  description = "Public IP of the uptime monitor"
  value       = oci_core_instance.uptime_monitor.public_ip
}

output "uptime_monitor_private_ip" {
  description = "Private IP of the uptime monitor"
  value       = oci_core_instance.uptime_monitor.private_ip
}

output "ssh_commands" {
  description = "SSH commands to connect to each node"
  value = concat(
    ["ssh -i ${trimsuffix(var.ssh_public_key_path, ".pub")} ubuntu@${oci_core_instance.k3s_server.public_ip}  # k3s-server"],
    [for i, agent in oci_core_instance.k3s_agent : "ssh -i ${trimsuffix(var.ssh_public_key_path, ".pub")} ubuntu@${agent.public_ip}  # k3s-agent-${i + 1}"],
    ["ssh -i ${trimsuffix(var.uptime_monitor_ssh_public_key_path, ".pub")} ubuntu@${oci_core_instance.uptime_monitor.public_ip}  # uptime-monitor"]
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

output "trusted_cidrs" {
  description = "Trusted CIDRs for k3s API access"
  value       = var.trusted_cidrs
}