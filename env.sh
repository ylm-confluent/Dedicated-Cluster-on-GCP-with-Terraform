# Confluent Cloud credentials
export TF_VAR_confluent_cloud_api_key=""
export TF_VAR_confluent_cloud_api_secret=""

# Confluent Cloud Environment and Cluster names
export TF_VAR_environment_name="Take-alot-POC-dedicated"
export TF_VAR_cluster_name="takealot-poc-dedicated"

# Dedicated Cluster Configuration
# Number of CKUs (Confluent Kafka Units) for the Dedicated cluster
# Minimum: 1 for single zone, 2 for multi-zone (HIGH availability)
export TF_VAR_cku_count=2

# Set to true only if running Terraform from within the VPC with PrivateLink access
export TF_VAR_create_private_resources=false

# Set to true to create a bastion VM in the VPC for running Terraform
export TF_VAR_create_bastion_vm=true

# SSH Configuration for Bastion VM
# Generate an SSH key if you don't have one: ssh-keygen -t rsa -b 4096 -f ~/.ssh/confluent_bastion -C "confluent-bastion"
# SSH key for bastion VM
# Run ./setup-ssh.sh to generate and configure SSH keys
export TF_VAR_ssh_public_key="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCfyZAjXQh15egBGG3nQthcd8NyHnLPisrxC1EAkxpqoaJFeW6IsFB30vw2DSUu92h690uaLss1ac2ITwHzwwAFHeCUAEFuZqiHNqOzRwI4AYQ3L66bGMnvMXautPI7zYkXlnsz/mVQrJ0ZC9j9sv7aXudLZXZ13+4+0Z1yaiy/VWkcT8T7c2SLCsIgYnkL1iOtWlzDPSgcVgRXOfxn3uTXNAy2G7LXvfTRhVhkkxAE2C5qfKXFEYW/ArUe9045Yv/Crcf2OuAFZlfsX1Em7SD+UWbfqdfK0H3NGvIlSSK6TKZa5dBDtiarUuEo2FyBgf1OKdP9cJg4DZCuOqmmoF4f2VD7njzBtws/mL8VHrZSP+31oeAv+DKjkjSK3GvjV5/GNQqhGxFlm4yslIxulEwjaqdR8+h5JYjLsG0S+Znh4DYnvetBlkPXR+BDvX9vdGwEVeFWE1jsjE3/I3cnjCyuM1NN4MW+uD+rjUM4z5ZtI77UY55YyY6UxgS163wk7E6DaJz/Ka9vxMRcZdn81akQn/b4E8gG6H97C/JfqZLw+M4EVqumeVq9JplEi7CFnl7GOX9hlbs0TcPgq9qoP9tek01Ok0neo4ANGO2SVK/1TWVL4LDqcJg15hq2qQrb2M8JjG7GgdKGm9/UET74WEfTUdT8XgDLkVTvKIDZnybhxw== confluent-bastion-dedicated"
export TF_VAR_ssh_username="terraform"

# Set to true to create a Windows VM in the VPC for browser-based Confluent Cloud access
export TF_VAR_create_windows_vm=true

# Windows VM Configuration
# Admin username for Windows VM (default: confluent_admin)
export TF_VAR_windows_admin_username="confluent_admin"

# Admin password for Windows VM
# IMPORTANT: Password must meet Windows complexity requirements:
# - At least 14 characters long (recommended: 20+)
# - Contains uppercase letters (A-Z)
# - Contains lowercase letters (a-z)
# - Contains numbers (0-9)
# - Contains special characters (!@#$%^&*()_+-=[]{}|;:,.<>?)
# - Cannot contain the username
# Example: Confluent@Cloud2024!SecurePass
# CHANGE THIS BEFORE DEPLOYING:
export TF_VAR_windows_admin_password='DK$^.]}yW^}HA;-'

# GCP configuration change this to your project and preferred region
export TF_VAR_customer_project_id="solutionsarchitect-01"
export TF_VAR_region="europe-west1"

# GCP VPC network configuration (these will be created by Terraform) - change if required
export TF_VAR_customer_vpc_network="confluent-vpc-dedicated"
export TF_VAR_customer_subnetwork_name="confluent-subnet-dedicated"

# Subnet name by zone mapping (JSON format)
export TF_VAR_subnet_name_by_zone='{"europe-west1-b":"subnet-b","europe-west1-c":"subnet-c","europe-west1-d":"subnet-d"}'
