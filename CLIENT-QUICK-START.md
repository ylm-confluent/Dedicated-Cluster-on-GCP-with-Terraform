# Confluent Cloud GCP Dedicated Cluster - Quick Start

## What This Deploys

This Terraform configuration creates a **production-ready Confluent Cloud Dedicated Kafka cluster** on GCP with **private networking** (PrivateLink).

### Infrastructure Created

#### Confluent Cloud Resources
- ✅ Dedicated Kafka Cluster (2 CKUs, High Availability across 3 zones)
- ✅ Private Network with PrivateLink connectivity
- ✅ Schema Registry (Essentials)
- ✅ Service Accounts with RBAC permissions (admin, producer, consumer)
- ✅ API Keys for all service accounts

#### GCP Resources
- ✅ VPC Network with subnets
- ✅ Private Service Connect forwarding rules (3 zones)
- ✅ DNS managed zone for private resolution
- ✅ Firewall rules for Kafka traffic
- ✅ **[Optional]** Ubuntu Bastion VM for SSH access
- ✅ **[Optional]** Windows VM for RDP/browser access

## Prerequisites

Before starting, ensure you have:

- [ ] GCP project with billing enabled
- [ ] `gcloud` CLI installed and authenticated
- [ ] Confluent Cloud account with API credentials
- [ ] Terraform installed (>= 0.14.0)
- [ ] **For Bastion VM:** SSH key pair (can be generated with `./setup-ssh.sh`)
- [ ] **For Windows VM:** Strong admin password set

## Quick Start

### Step 1: Authenticate with GCP

```bash
# Login to GCP
gcloud auth application-default login

# Set your GCP project
gcloud config set project YOUR_PROJECT_ID
```

### Step 2: Get Confluent Cloud API Credentials

1. Log into [Confluent Cloud](https://confluent.cloud)
2. Go to **Administration** → **Access** → **Cloud API Keys**
3. Create a new API key with **Organization Admin** role
4. Save the API Key and API Secret

### Step 3: Configure Environment Variables

Choose your shell and edit the appropriate file:

**For Fish shell** - Edit `env.sh`:
```fish
set -x TF_VAR_confluent_cloud_api_key "YOUR_API_KEY"
set -x TF_VAR_confluent_cloud_api_secret "YOUR_API_SECRET"
set -x TF_VAR_customer_project_id "YOUR_GCP_PROJECT_ID"
set -x TF_VAR_region "europe-west1"
set -x TF_VAR_cku_count 2
```

**For Bash/Zsh** - Edit `env.sh.bash`:
```bash
export TF_VAR_confluent_cloud_api_key="YOUR_API_KEY"
export TF_VAR_confluent_cloud_api_secret="YOUR_API_SECRET"
export TF_VAR_customer_project_id="YOUR_GCP_PROJECT_ID"
export TF_VAR_region="europe-west1"
export TF_VAR_cku_count=2
```

**For PowerShell** - Edit `env.ps1`:
```powershell
$env:TF_VAR_confluent_cloud_api_key = "YOUR_API_KEY"
$env:TF_VAR_confluent_cloud_api_secret = "YOUR_API_SECRET"
$env:TF_VAR_customer_project_id = "YOUR_GCP_PROJECT_ID"
$env:TF_VAR_region = "europe-west1"
$env:TF_VAR_cku_count = "2"
```

### Step 4: Optional - Enable VMs

**Bastion VM (for SSH access):**
```bash
# Generate SSH key
./setup-ssh.sh

# Enable bastion VM
export TF_VAR_create_bastion_vm=true
```

**Windows VM (for RDP/browser access):**
```bash
export TF_VAR_create_windows_vm=true
export TF_VAR_windows_admin_password='YourSecurePassword123!@#'
```

### Step 5: Deploy Infrastructure

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

### Step 6: Wait for Completion

⏱️ **Expected time:** 20-30 minutes

Terraform will create approximately 30-40 resources:
- GCP infrastructure: ~5 minutes
- Confluent Dedicated cluster: ~15-20 minutes
- DNS and PrivateLink setup: ~5 minutes
- Optional VMs: ~5-10 minutes

### Step 7: Access Your Resources

After deployment completes:

```bash
# View all outputs
terraform output

# View specific outputs
terraform output bastion_vm_info
terraform output windows_vm_info
terraform output private_link_setup_complete
```

## Accessing the Cluster

### Option 1: SSH via Bastion VM

```bash
# SSH into bastion
ssh terraform@<BASTION_EXTERNAL_IP>

# From bastion, you can access private Kafka endpoints
# Upload your Terraform files to create topics/ACLs
scp -r ./* terraform@<BASTION_IP>:~/confluent-terraform/
```

### Option 2: RDP via Windows VM

1. Open Remote Desktop client
2. Connect to Windows VM external IP
3. Login with admin credentials
4. Access Confluent Cloud UI through pre-configured browser

### Option 3: Configure Local VPN

Set up Cloud VPN or Cloud Interconnect to access from your local machine.

## Cluster Configuration

### CKU (Confluent Kafka Units)

The cluster is deployed with **2 CKUs** by default:

- **2 CKUs** = ~200 MB/s throughput, dedicated resources
- Minimum for HIGH availability (multi-zone)
- Can be scaled up or down as needed

**To change CKU count:**
```bash
# Edit environment file
export TF_VAR_cku_count=4

# Reload and apply
source env.sh.bash
terraform apply
```

### Private Networking

The cluster uses **PrivateLink** for private connectivity:

- ✅ No public internet exposure
- ✅ Private DNS resolution within VPC
- ✅ Traffic stays on GCP backbone
- ✅ 3 availability zones for high availability

### Service Accounts Created

1. **env-admin** - CloudClusterAdmin role (full access)
2. **app-manager** - CloudClusterAdmin role (topic management)
3. **app-producer** - DeveloperWrite role (produce to topics)
4. **app-consumer** - DeveloperRead role (consume from topics)

## Cost Estimate

### Confluent Cloud
- **Dedicated Cluster (2 CKUs):** ~$1,500-2,200/month
- **Schema Registry (Essentials):** ~$200-300/month
- **Total Confluent:** ~$1,700-2,500/month

### GCP Resources
- **VPC & Networking:** ~$50-100/month
- **Bastion VM (e2-medium):** ~$25-30/month (if enabled)
- **Windows VM (n2-standard-4):** ~$150-200/month (if enabled)
- **Total GCP:** ~$75-330/month

**Grand Total:** ~$1,775-2,830/month

*Costs vary based on region, usage, and optional components.*

## Scaling Guidelines

### Horizontal Scaling (CKUs)

| Workload | CKUs | Throughput | When to Use |
|----------|------|------------|-------------|
| Development/Testing | 1-2 | 100-200 MB/s | Low traffic, non-critical |
| Production (Small) | 2-4 | 200-400 MB/s | Steady workload |
| Production (Medium) | 4-8 | 400-800 MB/s | Growing workload |
| Production (Large) | 8+ | 800+ MB/s | High throughput |

### Vertical Scaling

Dedicated clusters can scale CKUs dynamically:
```bash
terraform apply -var="cku_count=4"
```

## Troubleshooting

### Common Issues

**Error: "network is required for dedicated cluster"**
- This is handled automatically in the configuration

**Error: "cku must be at least 2"**
- Set `TF_VAR_cku_count=2` or higher for HIGH availability

**Cannot connect to Kafka cluster**
- Ensure you're connecting from within the VPC
- Use bastion VM or Windows VM for access
- Verify DNS resolution is working

**Terraform state lock**
- Use remote state backend (GCS, S3) for team collaboration
- Enable state locking to prevent concurrent modifications

## Next Steps

After successful deployment:

1. ✅ **Create Kafka Topics** - Use bastion VM or Windows VM to create topics
2. ✅ **Configure Producers/Consumers** - Use the service account API keys
3. ✅ **Set up Monitoring** - Enable Confluent Cloud metrics
4. ✅ **Configure Connectors** - Add data sources/sinks as needed
5. ✅ **Test Connectivity** - Verify private networking works

## Documentation

- 📖 **[DEDICATED-CLUSTER-CHANGES.md](DEDICATED-CLUSTER-CHANGES.md)** - Detailed migration guide
- 📖 **[SETUP.md](SETUP.md)** - Step-by-step setup instructions
- 📖 **[WINDOWS-VM-GUIDE.md](WINDOWS-VM-GUIDE.md)** - Windows VM access guide
- 📖 **[Confluent Dedicated Docs](https://docs.confluent.io/cloud/current/clusters/cluster-types.html#dedicated-cluster)**
- 📖 **[Terraform Provider](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs)**

## Support

For issues or questions:
1. Check Terraform output for error messages
2. Review CloudWatch/GCP Logs for deployment errors
3. Consult Confluent Cloud documentation
4. Contact Confluent Support with cluster ID

---

**Ready to deploy?** Start with Step 1 above! 🚀
