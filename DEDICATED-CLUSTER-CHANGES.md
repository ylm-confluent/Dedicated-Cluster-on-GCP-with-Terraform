# Migration from Enterprise to Dedicated Cluster

## Overview

This Terraform configuration has been updated to deploy a **Dedicated Confluent Cloud Kafka cluster** instead of an Enterprise cluster, while maintaining full private networking capabilities using **GCP PrivateLink**.

## Key Changes

### 1. Cluster Type: Enterprise → Dedicated

**Before (Enterprise):**
```hcl
resource "confluent_kafka_cluster" "enterprise" {
  display_name = var.cluster_name
  availability = "HIGH"
  cloud        = "GCP"
  region       = var.region
  enterprise {}
  environment {
    id = confluent_environment.staging.id
  }
}
```

**After (Dedicated):**
```hcl
resource "confluent_kafka_cluster" "dedicated" {
  display_name = var.cluster_name
  availability = "HIGH"
  cloud        = "GCP"
  region       = var.region
  dedicated {
    cku = var.cku_count  # Confluent Kafka Units (default: 2)
  }
  
  network {
    id = confluent_network.private-link.id
  }
  
  environment {
    id = confluent_environment.staging.id
  }
}
```

### 2. Private Networking: Private Service Connect → PrivateLink

**Before:** Used Private Link Attachment with Private Service Connect (Enterprise-only feature)

**After:** Uses Confluent Network with PrivateLink (standard for Dedicated clusters)

The new configuration creates:
- `confluent_network` resource with connection type `PRIVATELINK`
- `confluent_private_link_access` resource for GCP project access
- GCP forwarding rules that connect to the Confluent service attachment
- DNS configuration for private resolution

### 3. New Configuration Variable: CKU Count

A new variable `cku_count` has been added to specify cluster capacity:

```hcl
variable "cku_count" {
  description = "The number of Confluent Kafka Units (CKUs) for the Dedicated cluster"
  type        = number
  default     = 2  # Minimum for HIGH availability (multi-zone)
}
```

**CKU Guidelines:**
- **Minimum for single zone:** 1 CKU
- **Minimum for HIGH availability (multi-zone):** 2 CKUs
- **Recommended for production:** 2-4 CKUs initially
- **Scaling:** Can be increased as needed (each CKU adds capacity)

### 4. Updated Environment Files

All environment configuration files have been updated:

**env.sh (Fish):**
```fish
set -x TF_VAR_cku_count 2
```

**env.sh.bash (Bash/Zsh):**
```bash
export TF_VAR_cku_count=2
```

**env.ps1 (PowerShell):**
```powershell
$env:TF_VAR_cku_count = "2"
```

## Cost Comparison

### Enterprise Cluster
- **Billing:** Hourly based on throughput
- **Cost:** ~$1.50-2.00/hour (~$1,100-1,500/month)
- **Best for:** Unpredictable workloads, pay-as-you-go

### Dedicated Cluster (2 CKUs)
- **Billing:** Per CKU per hour
- **Cost:** ~$1.00-1.50/hour per CKU (~$1,500-2,200/month for 2 CKUs)
- **Best for:** Predictable workloads, dedicated resources
- **Benefits:** 
  - Dedicated resources (CPU, memory, storage)
  - More predictable performance
  - Better cost control for steady-state workloads
  - Can scale CKUs up/down based on needs

## What Stays the Same

✅ **Private networking** - Still uses private connectivity (PrivateLink instead of PSC)  
✅ **High Availability** - 3 availability zones in `europe-west1`  
✅ **Bastion VM** - For SSH access to private resources  
✅ **Windows VM** - For RDP/browser access  
✅ **Service Accounts** - All RBAC roles and permissions  
✅ **Schema Registry** - Essentials package  
✅ **VPC Configuration** - Same network setup  

## Deployment Instructions

### 1. Update Environment Variables

Edit your environment file (`env.sh`, `env.sh.bash`, or `env.ps1`):

```bash
# Set your CKU count (2 is minimum for HIGH availability)
export TF_VAR_cku_count=2

# Update your credentials
export TF_VAR_confluent_cloud_api_key="YOUR_API_KEY"
export TF_VAR_confluent_cloud_api_secret="YOUR_API_SECRET"
export TF_VAR_customer_project_id="YOUR_GCP_PROJECT"
```

### 2. Load Environment and Deploy

**Fish shell:**
```fish
source env.sh
terraform init
terraform plan
terraform apply
```

**Bash/Zsh:**
```bash
source env.sh.bash
terraform init
terraform plan
terraform apply
```

**PowerShell:**
```powershell
.\env.ps1
terraform init
terraform plan
terraform apply
```

### 3. Expected Deployment Time

- **Total time:** 20-30 minutes
- **Dedicated cluster creation:** 15-20 minutes
- **PrivateLink setup:** 5-10 minutes
- **Bastion/Windows VMs:** 5-10 minutes

## Verification

After deployment, verify the setup:

```bash
# Check outputs
terraform output

# Verify cluster type in Confluent Cloud UI
# Navigate to: Environments → Your Environment → Your Cluster
# You should see: "Dedicated" with "X CKUs" displayed
```

## Scaling CKUs

To scale your cluster, update the CKU count:

1. Edit your environment file:
   ```bash
   export TF_VAR_cku_count=4  # Scale to 4 CKUs
   ```

2. Reload and apply:
   ```bash
   source env.sh.bash
   terraform apply
   ```

3. Terraform will update the cluster (usually takes 5-10 minutes)

## Troubleshooting

### Issue: "network is required for dedicated cluster"
**Solution:** This is already handled in the new configuration with the `confluent_network` resource.

### Issue: "cku must be at least 2 for multi-zone deployment"
**Solution:** Increase `TF_VAR_cku_count` to 2 or higher in your environment file.

### Issue: DNS resolution not working
**Solution:** Ensure the DNS managed zone is created and pointing to the correct forwarding rule IPs.

## Migration from Existing Enterprise Cluster

⚠️ **Important:** This is a **NEW deployment**, not an in-place upgrade.

If you have an existing Enterprise cluster:
1. This will create a **NEW** Dedicated cluster
2. You'll need to migrate data from old to new cluster
3. Consider using Confluent's cluster linking or client-based migration
4. Destroy the old Enterprise cluster after migration to avoid double billing

## Support and Documentation

- [Confluent Dedicated Clusters](https://docs.confluent.io/cloud/current/clusters/cluster-types.html#dedicated-cluster)
- [CKU Sizing Guide](https://docs.confluent.io/cloud/current/clusters/cku-sizing.html)
- [GCP PrivateLink Setup](https://docs.confluent.io/cloud/current/networking/private-links/gcp-privatelink.html)
- [Terraform Provider Docs](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs)

## Questions?

- **Q: Can I change from 2 to 4 CKUs later?**
  - A: Yes, CKUs can be scaled up or down at any time.

- **Q: What's the minimum CKU count?**
  - A: 1 for single-zone, 2 for multi-zone (HIGH availability).

- **Q: Will this cost more than Enterprise?**
  - A: Depends on usage. Dedicated is better for steady workloads, Enterprise for variable/burst workloads.

- **Q: Can I still access the cluster privately?**
  - A: Yes! PrivateLink provides the same private connectivity as before.

- **Q: Do I need to update my Kafka clients?**
  - A: Only the bootstrap servers will change. Update your client configurations after deployment.
