# PowerShell environment configuration for Terraform
# Usage: .\env.ps1 or . .\env.ps1

# Confluent Cloud credentials
$env:TF_VAR_confluent_cloud_api_key = ""
$env:TF_VAR_confluent_cloud_api_secret = ""

# Confluent Cloud Environment and Cluster names
$env:TF_VAR_environment_name = "Take-alot-POC"
$env:TF_VAR_cluster_name = "takealot-poc"

# Dedicated Cluster Configuration
# Number of CKUs (Confluent Kafka Units) for the Dedicated cluster
# Minimum: 1 for single zone, 2 for multi-zone (HIGH availability)
$env:TF_VAR_cku_count = "2"

# Set to true only if running Terraform from within the VPC with PrivateLink access
$env:TF_VAR_create_private_resources = "false"

# Set to true to create a bastion VM in the VPC for running Terraform
$env:TF_VAR_create_bastion_vm = "true"

# SSH Configuration for Bastion VM
# Generate an SSH key if you don't have one: ssh-keygen -t rsa -b 4096 -f ~/.ssh/confluent_bastion -C "confluent-bastion"
# SSH key for bastion VM
# Run .\setup-ssh.ps1 to generate and configure SSH keys (or use setup-ssh.sh in bash)
$env:TF_VAR_ssh_public_key = "*******"
$env:TF_VAR_ssh_username = "terraform"

# Set to true to create a Windows VM in the VPC for browser-based Confluent Cloud access
$env:TF_VAR_create_windows_vm = "true"

# Windows VM Configuration
# Admin username for Windows VM (default: confluent_admin)
$env:TF_VAR_windows_admin_username = "confluent_admin"

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
$env:TF_VAR_windows_admin_password = '*******'

# GCP configuration
$env:TF_VAR_customer_project_id = "solutionsarchitect-01"
$env:TF_VAR_region = "europe-west1"

# GCP VPC network configuration (these will be created by Terraform)
$env:TF_VAR_customer_vpc_network = "confluent-vpc"
$env:TF_VAR_customer_subnetwork_name = "confluent-subnet"

# Subnet name by zone mapping (JSON format)
$env:TF_VAR_subnet_name_by_zone = '{"europe-west1-b":"subnet-b","europe-west1-c":"subnet-c","europe-west1-d":"subnet-d"}'

# Google Cloud credentials path (required for GCP provider)
# Option 1: Use gcloud Application Default Credentials (recommended for local development)
#   Run: gcloud auth application-default login
#   Then comment out or remove the GOOGLE_APPLICATION_CREDENTIALS line below
#
# Option 2: Use a service account key file
#   Uncomment and set the path to your service account JSON key file
# $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\your\service-account-key.json"

Write-Host "✓ Terraform environment variables loaded (PowerShell)" -ForegroundColor Green
Write-Host "  Project: $env:TF_VAR_customer_project_id"
Write-Host "  Region: $env:TF_VAR_region"
Write-Host "  Cluster: $env:TF_VAR_cluster_name"
Write-Host ""
Write-Host "To apply: terraform init; terraform plan; terraform apply"
