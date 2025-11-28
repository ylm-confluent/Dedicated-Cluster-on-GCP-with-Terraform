#!/bin/bash
# Bash/Zsh compatible environment configuration

# Confluent Cloud credentials
export TF_VAR_confluent_cloud_api_key=""
export TF_VAR_confluent_cloud_api_secret=""

# Confluent Cloud Environment and Cluster names
export TF_VAR_environment_name="Take-alot-POC"
export TF_VAR_cluster_name="takealot-poc"

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
export TF_VAR_ssh_public_key="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDFbj2E6z1e1IRQxhmVmqryxo+lWp4msXkgHoMdW1DhZ3j/iRjiS3mwZVmvm0lPkP5ogQXvF2V1vKW57PCMZq9rk2aCbCPHD/FaNxIKioVFXnkSKe1ZLpT5Alku7Jl6rNj/BV6zQEhOlyS/lirMz/mg94IoqJVCDYaAJoMOIcPrAzTVr2zg+8xXqtPQiaXRTm85fH0NGGzs7Y37eyqiyfrQMFC6m20dGvVHD4sGHbqoY2G+yCulsInNFxbSehW7nqg/qjOkisPIIJy0oy/pKEygBh9dmTauyBuZay5jirKY0wT1V1k8XrD2vG66DWGr6V+MjSj9c/nWMntehUL1quOrO/4qPk5cfSRIKryjRHf5KVJNe18IytmHgWL9vtZ2+c18YCfp6Ghl5aGEpMTYtH8r0GUWW7fUtSIqpRFisMURzgg01PL0upYw/3Q4b7OO4qLHUPWZynMOFGhCQukM2FHjJGGbr9dUjeT4dwkSiUpKimK2ePEg0E31ZgOqKwyGYN9GrpDzG8HisvdwxA81k1SCdfIa2Y+SCcYECW/xE0DKo2T3a8xGRfn/1LytsfWAhmhm2HcvnlRZp9IjllyMH8ldZehXQqSZnNcL4eb2kfGmqJhCukl015bPbyBbxXVSDo1BN/cekkKEllhfI0J4VxKSjrV3W52e9UYXDFvBhaFKXQ== confluent-bastion"
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

# GCP configuration
export TF_VAR_customer_project_id="solutionsarchitect-01"
export TF_VAR_region="europe-west1"

# GCP VPC network configuration (these will be created by Terraform)
export TF_VAR_customer_vpc_network="confluent-vpc"
export TF_VAR_customer_subnetwork_name="confluent-subnet"

# Subnet name by zone mapping (JSON format)
export TF_VAR_subnet_name_by_zone='{"europe-west1-b":"subnet-b","europe-west1-c":"subnet-c","europe-west1-d":"subnet-d"}'

# Google Cloud credentials path (required for GCP provider)
# Option 1: Use gcloud Application Default Credentials (recommended for local development)
#   Run: gcloud auth application-default login
#   Then comment out or remove the GOOGLE_APPLICATION_CREDENTIALS line below
#
# Option 2: Use a service account key file
#   Uncomment and set the path to your service account JSON key file
# export GOOGLE_APPLICATION_CREDENTIALS="/path/to/your/service-account-key.json"

echo "✓ Terraform environment variables loaded (Bash/Zsh)"
echo "  Project: $TF_VAR_customer_project_id"
echo "  Region: $TF_VAR_region"
echo "  Cluster: $TF_VAR_cluster_name"
echo ""
echo "To apply: terraform init && terraform plan && terraform apply"
