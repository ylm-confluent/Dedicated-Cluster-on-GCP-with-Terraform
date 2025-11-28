# Confluent Cloud on GCP with Private Service Connect

This Terraform configuration creates a complete Confluent Cloud Kafka cluster on GCP with Private Service Connect networking, including all necessary GCP infrastructure resources.

## 🚀 First-Time User Checklist

**Before you start, make sure you have:**
- [ ] GCP project with billing enabled
- [ ] `gcloud` CLI installed and authenticated
- [ ] Confluent Cloud account (sign up at [confluent.cloud](https://confluent.cloud))
- [ ] Terraform installed (>= 0.14.0)

**Then follow these steps in order:**
1. Get your Confluent Cloud API credentials, need to create service account with org admin, create keys off that
2. Edit `env.sh` with your credentials and project ID
3. Generate SSH keys (if using bastion VM): `./setup-ssh.sh`
4. Run: `source env.sh && terraform init && terraform apply`
5. Wait ~10-15 minutes for deployment
6. Access via bastion VM (SSH) or Windows VM (RDP)

**📖 Detailed instructions below** ⬇️

---

## What This Terraform Creates

### GCP Resources:
- VPC Network (`confluent-vpc`)
- Main subnet (`confluent-subnet`) - 10.0.0.0/24
- Private Service Connect subnets for 3 zones (automatically numbered)
- Enables required GCP APIs (Compute Engine, Service Networking)
- **(Optional)** Bastion VM for SSH access and private resource management
- **(Optional)** Windows VM for browser-based Confluent Cloud UI access

### Confluent Cloud Resources:
- Confluent Environment (Staging)
- Enterprise Kafka Cluster
- Schema Registry (Essentials package)
- Private Link Attachment
- Service Accounts (env-admin, app-manager, app-producer, app-consumer)
- RBAC Role Bindings for producer and consumer access
- Kafka Topic (`orders`)
- API Keys for all service accounts

## Prerequisites

1. **GCP Project**: An existing GCP project with billing enabled
2. **gcloud CLI**: Installed and configured
3. **Confluent Cloud Account**: With API credentials
4. **Terraform**: Version >= 0.14.0

## Quick Start - First Time Setup

Follow these steps **in order** for first-time deployment:

### Step 1: Configure GCP Authentication
```bash
# Login to GCP
gcloud auth application-default login

# Set your GCP project
gcloud config set project YOUR_PROJECT_ID
```

### Step 2: Get Confluent Cloud API Credentials
1. Log into [Confluent Cloud](https://confluent.cloud)
2. Go to **Administration** → **Access** → **Cloud API Keys**
3. Click **"Add key"** and create a new API key
4. Save the **API Key** and **API Secret** (you'll need these next)

### Step 3: Configure Environment Variables
Edit the `env.sh` file and update these values:

```bash
# Confluent Cloud credentials (from Step 2)
export TF_VAR_confluent_cloud_api_key="YOUR_API_KEY"
export TF_VAR_confluent_cloud_api_secret="YOUR_API_SECRET"

# Your GCP project ID
export TF_VAR_customer_project_id="YOUR_GCP_PROJECT_ID"

# Customize your environment and cluster names (optional)
export TF_VAR_environment_name="Your-Environment-Name"
export TF_VAR_cluster_name="your-cluster-name"

# Optional: Enable bastion VM for private resource management
export TF_VAR_create_bastion_vm=true

# Optional: Enable Windows VM for browser-based access
export TF_VAR_create_windows_vm=true
export TF_VAR_windows_admin_password='YourSecurePassword123!'
```

### Step 4: Generate SSH Keys (if using Bastion VM)
```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/confluent_bastion -C "confluent-bastion"

# Add the public key to env.sh (this is done automatically by the script below)
./setup-ssh.sh
```

Or manually add to `env.sh`:
```bash
export TF_VAR_ssh_public_key="$(cat ~/.ssh/confluent_bastion.pub)"
```

### Step 5: Load Environment Variables
```bash
source env.sh
```

### Step 6: Initialize and Deploy
```bash
# Initialize Terraform (downloads required providers)
terraform init

# Preview what will be created
terraform plan

# Deploy the infrastructure (creates ~40 resources)
terraform apply
```

**⏱️ Deployment Time:** 10-15 minutes

### Step 7: Verify Deployment
After successful deployment, Terraform will output:
- ✅ Kafka cluster details (ID, bootstrap servers, REST endpoint)
- ✅ Private Link Attachment connection IDs
- ✅ Bastion VM SSH connection info (if enabled)
- ✅ Windows VM RDP connection info (if enabled)
- ✅ Service account credentials (use `terraform output -json resource-ids`)

### Step 8: Access Your Cluster

**From Bastion VM (for CLI/Terraform operations):**
```bash
# SSH into bastion VM
ssh -i ~/.ssh/confluent_bastion terraform@<BASTION_EXTERNAL_IP>

# On bastion VM - use Confluent CLI
confluent login
confluent kafka topic list --cluster <CLUSTER_ID>
```

**From Windows VM (for browser-based UI):**
1. RDP to Windows VM IP (shown in output)
2. Use the **"Chrome - Confluent Cloud"** or **"Edge - Confluent Cloud"** desktop shortcuts
3. Login to Confluent Cloud web UI
4. Navigate to your environment and cluster

### Step 9: Create Topics (Optional)
If you want to create the example `orders` topic:

```bash
# On your local machine or bastion VM
# Edit env.sh and set:
export TF_VAR_create_private_resources=true

# Re-apply
source env.sh
terraform apply
```

This will create:
- ✅ Kafka topic `orders`
- ✅ RBAC role bindings are already created (work from anywhere!)

## What Gets Created

After running `terraform apply`, you'll have:
- Service account API keys
- Schema Registry details

## Access Options

This configuration provides two options for managing your Confluent Cloud Kafka cluster:

### Option 1: Bastion VM (SSH Access)
- **For**: Command-line users, automation, CI/CD
- **Access**: SSH into Linux VM
- **Use Cases**: Run Terraform, Confluent CLI, scripts
- **Setup**: Set `TF_VAR_create_bastion_vm=true` in `env.sh`
- **Guide**: See `QUICK-START.md`

### Option 2: Windows VM (Browser Access)  
- **For**: GUI users, visual management
- **Access**: RDP into Windows Server VM
- **Use Cases**: Use Confluent Cloud web UI for topics, RBAC roles, monitoring
- **Setup**: Set `TF_VAR_create_windows_vm=true` in `env.sh`
- **Guide**: See `WINDOWS-VM-GUIDE.md`

Both VMs are optional and can be used independently or together.

## What You Can Do Now

After successful deployment, you can access and manage your Confluent Cloud infrastructure:

### View Service Account Credentials

The deployment creates an `env-admin` service account with **CloudClusterAdmin** role and full cluster access:

```bash
# View all service account credentials (including env-admin)
terraform output -json resource-ids | jq -r
```

This will display:
- Service Account IDs
- Kafka API Keys
- Kafka API Secrets

### SSH into Bastion VM

```bash
# Connect using your SSH key
ssh -i ~/.ssh/confluent_bastion terraform@35.205.158.78

# Or using gcloud
gcloud compute ssh terraform@confluent-bastion-vm \
  --zone=europe-west1-b \
  --project=solutionsarchitect-01
```

### Use Confluent CLI on Bastion VM

Once connected to the bastion VM:

```bash
# Login to Confluent Cloud
confluent login --save

# Use your environment (found in outputs)
confluent environment use env-1dg275

# Use your cluster
confluent kafka cluster use lkc-drmo3y

# Create topics
confluent kafka topic create my-topic --partitions 6

# List topics
confluent kafka topic list

# Produce messages
confluent kafka topic produce my-topic

# Consume messages
confluent kafka topic consume my-topic --from-beginning
```

### Connect via Windows RDP (if enabled)

```bash
# Get Windows VM connection info
terraform output windows_vm_info
```

Then use:
- **macOS**: Microsoft Remote Desktop app
- **Windows**: Remote Desktop Connection (mstsc.exe)
- **Linux**: Remmina or rdesktop

Username: `confluent_admin`  
Password: (use `gcloud compute reset-windows-password` to set/reset password)

**Important for Private Link Access:**  
The Windows VM has special browser shortcuts on the desktop:
- **"Chrome - Confluent Cloud"** - Chrome configured for private network access
- **"Edge - Confluent Cloud"** - Edge configured for private network access

⚠️ **You MUST use these special shortcuts** to access Confluent Cloud UI. Regular browser windows will be blocked by browser security policies that prevent public websites from accessing private network endpoints (CORS Private Network Access).

If you see CORS errors or can't see topics, make sure you're using the pre-configured shortcuts!

### Access Confluent Cloud Resources

Your deployed resources:
- **Environment**: Take-alot-POC (`env-1dg275`)
- **Cluster**: takealot-poc (`lkc-drmo3y`)
- **Region**: europe-west1 (GCP)
- **Private Link Connections**: 3 zones (b, c, d)

### Copy Terraform Files to Bastion

To create private resources (topics) from the bastion VM:

```bash
# Copy your Terraform files
scp -r ./* terraform@35.205.158.78:~/confluent-terraform/

# SSH into bastion
ssh -i ~/.ssh/confluent_bastion terraform@35.205.158.78

# On the bastion VM:
cd ~/confluent-terraform
vim env.sh  # Set create_private_resources=true
source env.sh
terraform apply
```

## Configuration Details

### Region
All resources are deployed in **europe-west1** region with subnets across three zones:
- europe-west1-b
- europe-west1-c  
- europe-west1-d

### Network Architecture
- VPC Network: `confluent-vpc`
- Main Subnet: `confluent-subnet` (10.0.0.0/24)
- PSC Subnets: 
  - subnet-b (10.0.1.0/24)
  - subnet-c (10.0.2.0/24)
  - subnet-d (10.0.3.0/24)

## Customization

To change the region or network configuration, update the variables in `env.sh` and adjust the subnet CIDR ranges in `main.tf` if needed.

---

### Notes

1. See [Sample Project for Confluent Terraform Provider](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/guides/sample-project) that provides step-by-step instructions of running this example.

2. This example assumes that Terraform is run from a host in the private network (you could also leverage the ["Agent" Execution Mode](https://developer.hashicorp.com/terraform/cloud-docs/agents) if you are using Terraform Enterprise), where it will have connectivity to the [Kafka REST API](https://docs.confluent.io/cloud/current/api.html#tag/Topic-(v3)) in other words, to the [REST endpoint](https://docs.confluent.io/cloud/current/clusters/broker-config.html#access-cluster-settings-in-the-ccloud-console) on the provisioned Kafka cluster. If it is not, you must make these changes:

   * Update the `confluent_api_key` resources by setting their `disable_wait_for_ready` flag to `true`. Otherwise, Terraform will attempt to validate API key creation by listing topics, which will fail without access to the Kafka REST API. Otherwise, you might see errors like:

       ```
       Error: error waiting for Kafka API Key "[REDACTED]" to sync: error listing Kafka Topics using Kafka API Key "[REDACTED]": Get "[https://[REDACTED]/kafka/v3/clusters/[REDACTED]/topics](https://[REDACTED]/kafka/v3/clusters/[REDACTED]/topics)": GET [https://[REDACTED]/kafka/v3/clusters/[REDACTED]/topics](https://[REDACTED]/kafka/v3/clusters/[REDACTED]/topics) giving up after 5 attempt(s): Get "[https://[REDACTED]/kafka/v3/clusters/[REDACTED]/topics](https://[REDACTED]/kafka/v3/clusters/[REDACTED/topics)": dial tcp [REDACTED]:443: i/o timeout
       ```

   * Remove the `confluent_kafka_topic` resource. This resource is provisioned using the Kafka REST API, which is only accessible from the private network.

   * Note: RBAC role bindings can be provisioned from anywhere as they use the [Confluent Cloud API](https://docs.confluent.io/cloud/current/api.html), not the [Kafka REST API](https://docs.confluent.io/cloud/current/api.html#tag/Topic-(v3))

3. One common deployment workflow for environments with private networking is as follows:

   * A initial (centrally-run) Terraform deployment provisions infrastructure: network, Kafka cluster, RBAC role bindings, and other resources on cloud provider of your choice to setup private network connectivity (like DNS records)

   * A secondary Terraform deployment (run from within the private network) provisions data-plane resources (Kafka Topics only)

   * RBAC role bindings can be provisioned in the first step since they use the Confluent Cloud API and don't require private network access


4. See [Use GCP Private Service Connect](https://docs.confluent.io/cloud/current/networking/private-links/gcp-private-service-connect.html) for more details.
