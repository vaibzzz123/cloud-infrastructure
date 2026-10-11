# Cloud Infrastructure

A reproducible three-node k3s platform and standalone uptime monitor on OCI free tier. Provisioned with Terraform, configured and hardened with Ansible, then exposes specific homelab services via a VPN gateway. This repo contains all the manifest files, scripts, and more required for this.

![Network Architecture](docs/architecture%20diagram.png)

This repo has three main parts:

`terraform/`: The Terraform manifest files for provisioning the network infrastructure on Oracle Cloud (OCI). This includes providers for OCI, compute instances, virtual cloud network, security lists, subnets, and more. On top of that it has various useful Terraform outputs like IP addresses for nodes, trusted CIDRs, and more.

`ansible/`: The Ansible playbook files for configuring the VMs once provisioned. This includes setting up important dependencies, backup/restore, installing/configuring k3s, and more. There is also an Ansible vault with encrypted data, some scripts to copy to the machines, Ansible inventory, and a few helper scripts to encrypt/decrypt the vault.

`kubernetes/`: Kubernetes manifest files for the various things I want to run on the k3s cluster, including important dependencies like SealedSecret, cert-manager, Longhorn, and more. The main thing running on this right now is the Caddy reverse proxy exposing services on my homelab via a WireGuard VPN container running in the same Pod. Will eventually add ArgoCD for the full GitOps setup, and deploy my personal website, observability stack and more on this cluster.

On top of that, I have some helper scripts in `scripts/` that gets the important credentials, information, etc. on top of running the commands to apply the TF manifests, playbooks, etc.

The k3s cluster is running on 3 separate VMs, with two nodes being worker nodes and one being the control plane.

## Architecture

This is a triple node k3s cluster, where I have one node `k3s-server` where the server/control plane lives on, and two nodes, `k3s-agent-1` and `k3s-agent-2` that are agent/worker nodes.

`k3s-server`: 2 Ampere A1 (ARM) OCPU cores, 8gb RAM

`k3s-agent-1`, `k3s-agent-2`: 1 Ampere A1 (ARM) OCPU core, 8gb RAM

They were chosen with these specs to remain with Oracle Cloud Infrastructure's free tier of 4 OCPU cores/24gb RAM spread across the nodes, while meeting the minimum requirements for k3s server/agents. The terms server/control plane node and agent/worker node are used interchangeably for k3s/Kubernetes terminology.

`uptime-monitor`: `VM.Standard.E2.1.Micro` AMD VM with 1 GB RAM and a 50 GB boot volume. It uses the separate Always Free AMD micro allowance. Together, the four 50 GB boot volumes consume the full 200 GB Always Free block storage allowance.

The following OCI required network resources were also created:

- Virtual Cloud Network (VCN): Private virtual network where everything else lives (Equivalent to VPC in AWS/GCP, and VNet in Azure)
- Internet Gateway: Allows traffic between public IPs in the VCN and the internet (Equivalent to the Internet Gateway in AWS)
- Route Table: Table that rules to decide where subnet traffic goes (Equivalent to Route Table in AWS, VPC Routes in GCP, and Route Table in Azure)
- Security List: Ingress/egress firewall rules for a subnet (Roughly equivalent to Security Groups/Network ACL in AWS, Network Security Group in Azure, and VPC Firewall Rules in GCP)
- Subnet: CIDR-range subdivision in the VCN, route table and security list associated with it (Equivalent to Subnet in AWS/Azure/GCP)

## Security

### Security List

At the Security List level, I've chosen to deliberately expose ports 22, 80, and 443 to the entire internet. The latter two are so outsiders can access the web servers, and the former to allow SSHing in from anywhere. I chose to deliberately expose SSH so that it's easy to SSH into the servers no matter where I might be in the world. I add some other security hardening steps later on to account for this increased risk. I decided to expose port 6443 for the Kubernetes API Server, but only to a trusted group of IP addresses/CIDRs which can be configured, so there isn't a chance that the cluster can be compromised via that from anywhere on the internet. Besides that I also allow all egress traffic so the servers can fully access the internet as needed, as well as allowing all traffic between nodes in the VCN.

### Firewall

Using iptables, I configured the firewall carefully to only expose what's needed. Kubelet metrics (TCP port 10250) is exposed to cluster CIDRs, Flannel VXLAN (UDP port 8472) exposed to cluster CIDRs, and the Kubernetes API (TCP port 6443) exposed to cluster CIDRs as well as trusted public CIDRs. Then ports 22, 80, and 443 are open publicly.

## Setup Instructions

### 1. Prerequisites

To set this all up, you'll need to install a few dependencies: The OCI CLI with your OCI credentials configured, ArgoCD CLI, Terraform, Ansible and Python/pip to install it, kubectl, kubeseal, jq, and openssl. Follow the officials guides to install the [OCI CLI](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm), [ArgoCD CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/), [Terraform](https://developer.hashicorp.com/terraform/install), [Ansible](https://docs.ansible.com/projects/ansible/latest/getting_started/get_started_ansible.html#get-started-ansible), [kubectl](https://kubernetes.io/docs/tasks/tools/), and [kubeseal](https://kubeseal.com/#Installation). jq and openssl are CLI tools used in the setup scripts that should be preinstalled on most Linux OSes, but if not, go to the [jq setup guide](https://jqlang.org/download/) and [openssl download page](https://www.openssl-library.org/source/). Once this is done, clone the repo locally via `git clone https://github.com/vaibzzz123/cloud-infrastructure`.

### 2. Keys and Credentials

Then once those are installed, [generate an SSH key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent), and create the `terraform/terraform.tfvars` file based off of the example. Fill in the OCI credentials and details, as well as the path to the generated SSH key. This will be the SSH key to access every node in the cluster. Also add the list of trusted public CIDRs that can access the cluster through kubectl without needing to use the NetBird VPN. The standalone uptime monitor uses `~/.ssh/oci_uptime_monitor.pub`; create that key pair before applying Terraform.

### 3. Provisioning the Infrastructure

Now that the tfvars file is setup, you can run the `scripts/00-terraform-apply-and-output.sh` script. This is a thin wrapper around the Terraform CLI, that checks for dependencies, makes sure the tfvars file is filled, provisions the nodes and the network infrastructure on OCI, and creates an intermediary file based off of the TF output for use in later steps. Confirm that the resources being provisioned look good, and it will create those, and then move intermediary values into `.local/terraform-outputs.env`. The console output of the script will also contain commands to SSH into the nodes, their ip addresses and more. The generated `.local/terraform-otuputs.env` file will contain information like the IP addresses of the nodes, private SSH key path and more.

If the trusted public CIDRs change, update `terraform/terraform.tfvars` with the new CIDRs, then run `tf apply` to update the Security List. Follow further steps in part 4 below for changing the CIDRs for the Ansible playbook.

### 4. Configuring the Nodes

Now that the nodes are running, ssh into each of them, typing yes on the dialogue about unknown fingerprint and if you're sure you want to connect. **This is a vital step for Ansible to work correctly**, otherwise it will hang when trying to connect to the nodes. I'd also recommend modifying your `~/.ssh/config` file and adding this to have host aliases to get convenient access to the nodes:

```
host k3s-server
  HostName <k3s-server ip>
  User ubuntu
  IdentityFile <path to private ssh key>
  ConnectTimeout 60
  ServerAliveInterval 60
  ServerAliveCountMax 10

host k3s-agent-1
  HostName <k3s-agent-1 ip>
  User ubuntu
  IdentityFile <path to private ssh key>
  ConnectTimeout 60
  ServerAliveInterval 60
  ServerAliveCountMax 10

host k3s-agent-2
  HostName <k3s-agent-2 ip>
  User ubuntu
  IdentityFile <path to private ssh key>
  ConnectTimeout 60
  ServerAliveInterval 60
  ServerAliveCountMax 10

host uptime-monitor
  HostName <uptime-monitor ip>
  User ubuntu
  IdentityFile ~/.ssh/oci_uptime_monitor
  ConnectTimeout 60
  ServerAliveInterval 60
  ServerAliveCountMax 10
```

This will allow you to use commands like `ssh k3s-server` to make things easier for yourself, but isn't explicitly necessary.

Once you've confirmed you're able to SSH into the nodes, run the `scripts/01-ansible-prepare-and-apply.sh` script. This script does many different things: It will get the intermediary values from the previous script, check dependencies, create an Ansible Vault password file if it doesn't exist, encrypt/decrypt the Ansible Vault and secret files, load them with values, and finally run the Ansible Playbook. It's interactive and will ask your permissions for steps along the way.

This will take a couple minutes, but if successful, the k3s cluster will be up, NetBird will be installed and running, firewall will be configured and hardened, fail2ban installed, and more. Try running `k get node -o wide` to check the status of the nodes.

If the trusted public CIDRs change later, update `k3s_api_trusted_cidrs` in
`ansible/group_vars/all/secrets.yml`, apply the matching Terraform change first,
then replace the host firewall rule from the `ansible/` directory:

```bash
ansible-playbook -i inventory.yml --vault-password-file group_vars/.vault_password playbooks/05-trusted-cidr-updates.yml
```

The update playbook discovers previously managed firewall rules by their
comments, adds every current trusted CIDR, and then removes obsolete rules,
preserving API access during the change. It also replaces Fail2Ban's SSH
`ignoreip` list on every k3s node with the current trusted CIDRs.

### 5. Applying Kubernetes Manifests

Now that the cluster is up, all that's left is to apply the manifests for the various parts of the cluster. Run `cd kubernetes`, then run `kubectl apply -k 00-argocd`. This will use Kustomize to create the argocd namespace, and download the ArgoCD install manifest to apply. Then run `kubectl apply -f <numbered folders>/` for the remaining folders. This will apply the manifests in each folder to the cluster. For cert-manager, you may have to run that folder twice due to certain resources in that manifest being dependant on other resources in the same manifest being online. Wait a minute or two so things are fully loaded before doing this. Do this until you get to `04-caddy`.

Now you want to run the `kubernetes/bootstrap_wireguard_secrets_and_config.sh` file. This will guide you through the process of creating Wireguard keypairs, Wireguard configs, and encrypting them with SealedSecrets so they're ready for the cluster. Once that is done, you can do `kubectl apply -f 04-caddy/` and the final piece of the cluster will be ready!