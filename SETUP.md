# Quick Setup Guide

## Overview
This Terraform configuration will automatically create all GCP infrastructure and Confluent Cloud resources needed for a production-ready Kafka cluster with Private Service Connect.

## What Gets Created Automatically

### GCP Infrastructure (by Terraform):
- ✅ VPC Network
- ✅ Subnets (main + 3 Private Service Connect subnets)
- ✅ Required API enablement

### Confluent Cloud Resources (by Terraform):
- ✅ Kafka Cluster (Enterprise, High Availability)
- ✅ Schema Registry
- ✅ Private Link Attachment
- ✅ Service Accounts and API Keys
- ✅ Kafka Topic and ACLs

## Step-by-Step Instructions

### 1. Prerequisites Check
```bash
# Verify gcloud is installed
gcloud --version

# Verify terraform is installed
terraform --version

# List your GCP projects
gcloud projects list
```

### 2. Authenticate with GCP
```bash
# Login with your Google account
gcloud auth application-default login

# Set your project (replace with your actual project ID)
gcloud config set project YOUR_PROJECT_ID
```

### 3. Configure Environment Variables
Edit the `env.sh` file and update:
```bash
export TF_VAR_customer_project_id="your-actual-project-id"
```

All other variables have sensible defaults that will work out of the box.

### 4. Load Environment Variables
```bash
source env.sh
```

### 5. Initialize and Apply Terraform
```bash
# Download required providers
terraform init

# Preview what will be created
terraform plan

# Create all resources (will prompt for confirmation)
terraform apply

# Or auto-approve to skip confirmation
terraform apply -auto-approve
```

### 6. Wait for Completion
The deployment typically takes 15-30 minutes. Terraform will:
1. Enable GCP APIs (~2 min)
2. Create VPC and subnets (~2 min)
3. Create Confluent Cloud resources (~10-25 min)

### 7. View Outputs
After successful deployment:
```bash
terraform output
```

This will show:
- Kafka bootstrap servers
- REST endpoints
- Service account credentials
- Resource IDs

## Important Notes

### Network Connectivity
This configuration sets up Private Service Connect, which means:
- Kafka cluster is only accessible from within your VPC
- If you need to access from your local machine, you'll need a VPN or bastion host
- Consider running Terraform from a VM within the VPC for full functionality

### Cost Considerations
This creates:
- **Confluent Cloud Enterprise Cluster**: ~$1.50-2.00/hour
- **GCP Networking**: Minimal cost for VPC/subnets
- **Data Transfer**: Additional costs based on usage

### Security Best Practices
- ✅ API credentials are stored in environment variables (not in code)
- ✅ Don't commit `env.sh` with real credentials to git
- ✅ Use `.gitignore` to exclude sensitive files
- ✅ Consider using a secrets manager for production

## Cleanup

To destroy all resources and stop charges:
```bash
terraform destroy
```

**Warning**: This will delete:
- All Kafka data
- All configurations
- All service accounts
- The VPC and subnets

## Troubleshooting

### "Billing not enabled" error
```bash
# Enable billing for your project in GCP Console
# Or link a billing account:
gcloud billing projects link YOUR_PROJECT_ID \
  --billing-account=YOUR_BILLING_ACCOUNT_ID
```

### "API not enabled" error
The Terraform configuration automatically enables required APIs, but if you see errors:
```bash
gcloud services enable compute.googleapis.com
gcloud services enable servicenetworking.googleapis.com
```

### "Insufficient IAM permissions"
Your GCP user account needs these roles:
- Compute Admin (or Compute Network Admin)
- Service Usage Admin
- Project IAM Admin (if creating service accounts)

### Terraform state issues
If you encounter state file issues:
```bash
# Refresh state
terraform refresh

# If state is corrupted, you may need to re-import resources
# (Advanced - consult Terraform documentation)
```

## Next Steps

After deployment:
1. Access Kafka from within your VPC
2. Create additional topics using the Kafka REST API or Confluent Cloud Console
3. Configure producers and consumers with the generated API keys
4. Set up monitoring and alerting
5. Configure backup and disaster recovery

## Support Resources

- [Confluent Cloud Documentation](https://docs.confluent.io/cloud/current/)
- [GCP Private Service Connect Guide](https://docs.confluent.io/cloud/current/networking/private-links/gcp-private-service-connect.html)
- [Terraform Provider Documentation](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs)
