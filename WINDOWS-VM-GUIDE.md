# Windows VM Guide - Browser-Based Confluent Cloud Access

## Overview

This guide explains how to deploy and use a Windows Server VM in your GCP VPC for browser-based access to Confluent Cloud. The Windows VM provides a graphical interface for managing your Kafka cluster through the Confluent Cloud web UI.

## Why Use a Windows VM?

- **GUI Access**: Full browser-based experience for Confluent Cloud UI
- **Easy Topic Management**: Create, configure, and manage topics through web interface
- **Visual Monitoring**: Access dashboards, metrics, and stream lineage diagrams
- **No SSH Required**: Use RDP (Remote Desktop) instead of SSH terminal
- **Same VPC Access**: Connected to the same private network as your Kafka cluster

## Prerequisites

- Terraform configuration from this directory
- A strong Windows admin password (see password requirements below)
- RDP client installed on your local machine:
  - **macOS**: Microsoft Remote Desktop (from App Store)
  - **Windows**: Built-in Remote Desktop Connection (mstsc.exe)
  - **Linux**: Remmina or rdesktop

## Deployment

### 1. Set Windows Admin Password

The Windows VM requires a strong admin password that meets Windows complexity requirements:

**Requirements:**
- Minimum 14 characters (20+ recommended)
- Contains uppercase letters (A-Z)
- Contains lowercase letters (a-z)
- Contains numbers (0-9)
- Contains special characters (!@#$%^&*()_+-=[]{}|;:,.<>?)
- Cannot contain the username

**Example:** `Confluent@Cloud2024!SecurePass`

Edit `env.sh`:
```bash
# Set to true to create the Windows VM
export TF_VAR_create_windows_vm=true

# Set your secure password
export TF_VAR_windows_admin_password="YourSecurePassword123!@#"
```

### 2. Optional: Customize Admin Username

By default, the admin username is `confluent_admin`. To change it:

```bash
export TF_VAR_windows_admin_username="myadmin"
```

### 3. Deploy the Windows VM

```bash
# Load environment variables
source env.sh

# Review the changes
terraform plan

# Deploy the Windows VM
terraform apply
```

**Note:** The initial deployment takes about 5-10 minutes as Windows needs to:
- Complete initial setup
- Run Windows Updates
- Install software via Chocolatey
- Configure browser settings

### 4. Get Connection Details

```bash
terraform output windows_vm_info
```

This displays:
- External IP address for RDP connection
- Username and password requirements
- Pre-installed software list
- Connection instructions for different operating systems

## Connecting via RDP

### From macOS

1. **Install Microsoft Remote Desktop**
   - Open App Store
   - Search for "Microsoft Remote Desktop"
   - Install the application

2. **Add the Windows VM**
   - Open Microsoft Remote Desktop
   - Click the `+` button
   - Select "Add PC"
   - Enter the External IP from terraform output
   - Set User account to the admin username
   - Save

3. **Connect**
   - Double-click the connection
   - Enter your password when prompted
   - Accept the certificate warning (first connection)

### From Windows

1. **Open Remote Desktop Connection**
   - Press `Win + R`
   - Type `mstsc.exe` and press Enter

2. **Connect**
   - Computer: Enter the External IP from terraform output
   - Username: Enter your admin username
   - Click "Connect"
   - Enter your password
   - Accept the certificate warning (first connection)

### From Linux

**Using rdesktop:**
```bash
rdesktop <EXTERNAL_IP> -u <USERNAME>
```

**Using Remmina (GUI):**
1. Open Remmina
2. Click "New connection profile"
3. Protocol: RDP
4. Server: External IP
5. Username: Your admin username
6. Password: Your password
7. Save and connect

## What's Pre-Installed

The Windows VM comes with the following software automatically installed:

### Browsers
- **Google Chrome** - Pre-configured to open Confluent Cloud
- **Mozilla Firefox** - Alternative browser

### Development Tools
- **Visual Studio Code** - For viewing/editing configuration files
- **7-Zip** - For file compression/extraction

### Package Manager
- **Chocolatey** - For installing additional software

### Desktop Shortcuts
- **Confluent-Welcome.html** - Quick reference guide with links
- **Google Chrome** - Opens directly to Confluent Cloud
- **Firefox** - Alternative browser

## Using Confluent Cloud UI

### 1. First Login

1. Open Google Chrome (use desktop shortcut)
2. Navigate to https://confluent.cloud
3. Log in with your Confluent Cloud credentials
4. Select your environment: **Take-alot-POC**
5. Select your cluster: **takealot-poc**

### 2. Creating Topics

**Via Web UI:**
1. In Confluent Cloud, go to your cluster
2. Click **Topics** in the left menu
3. Click **+ Add topic**
4. Configure:
   - Topic name: e.g., `orders`, `customers`, `events`
   - Partitions: Default 6 (or customize)
   - Retention: Default 7 days (or customize)
   - Cleanup policy: delete or compact
5. Click **Create with defaults** or **Customize settings**

**Topic Settings to Consider:**
- **Partitions**: More partitions = more parallelism
- **Retention**: How long to keep messages
- **Min In-Sync Replicas**: For durability (default 2)
- **Compression**: gzip, snappy, lz4, or zstd

### 3. Managing ACLs

1. Go to **Cluster settings** → **Access control**
2. Click **+ Add ACL**
3. Select principal (service account)
4. Choose resource type (Topic, Consumer Group, etc.)
5. Set permissions (Read, Write, Describe, etc.)
6. Save

### 4. Monitoring

**Available Metrics:**
- Throughput (bytes/sec, messages/sec)
- Consumer lag
- Partition distribution
- Broker health
- Topic size and growth

**Access Monitoring:**
1. Go to your cluster
2. Click **Metrics** tab
3. View dashboards for:
   - Production rate
   - Consumption rate
   - Latency
   - Storage

### 5. Schema Registry

1. Click **Schema Registry** in the left menu
2. View schemas for your topics
3. Click **+ Add schema** to create new ones
4. Choose format: Avro, JSON Schema, or Protobuf

### 6. Connectors

1. Go to **Connectors** tab
2. Click **+ Add connector**
3. Browse available connectors:
   - Source connectors (import data)
   - Sink connectors (export data)
4. Configure and deploy

## VM Specifications

- **Machine Type**: n2-standard-4
  - 4 vCPUs (ensures smooth browser performance)
  - 16 GB RAM (handles multiple browser tabs)
- **Operating System**: Windows Server 2022
- **Disk**: 100 GB Balanced Persistent Disk
- **Network**: Connected to confluent-vpc
- **Location**: europe-west1-b zone

## Performance Considerations

### Optimal Performance
The n2-standard-4 machine type provides:
- Smooth browser experience
- Fast page loads
- Ability to handle multiple tabs
- Good performance for large datasets in UI

### If You Need More Performance
Edit `main.tf` and change the `machine_type`:
```hcl
machine_type = "n2-standard-8"  # 8 vCPUs, 32 GB RAM
```

Then run:
```bash
terraform apply
```

## Security Best Practices

### 1. Restrict RDP Access

By default, RDP is open to all IPs (`0.0.0.0/0`). To restrict to your IP:

Edit `main.tf`:
```hcl
resource "google_compute_firewall" "allow_rdp" {
  # ...
  source_ranges = ["YOUR.PUBLIC.IP.ADDRESS/32"]  # Your IP only
  # ...
}
```

Apply changes:
```bash
terraform apply
```

### 2. Use Strong Password

- Use a password manager to generate a strong password
- Never reuse passwords
- Change password regularly
- Don't share the password

### 3. Monitor RDP Access

Check Windows Event Logs:
1. Open **Event Viewer**
2. Navigate to **Windows Logs** → **Security**
3. Look for Event ID 4624 (successful logon) and 4625 (failed logon)

### 4. Keep Windows Updated

The VM automatically checks for updates. To manually update:
1. Open **Settings**
2. Go to **Update & Security** → **Windows Update**
3. Click **Check for updates**

## Installing Additional Software

The VM uses Chocolatey package manager. To install additional software:

1. Open **PowerShell as Administrator**
2. Run chocolatey commands:

```powershell
# Install Notepad++
choco install notepadplusplus -y

# Install Postman (for API testing)
choco install postman -y

# Install Git
choco install git -y

# Install Python
choco install python -y

# Install Node.js
choco install nodejs -y

# Search for packages
choco search <package-name>
```

Browse available packages: https://community.chocolatey.org/packages

## Troubleshooting

### Can't Connect via RDP

**Check firewall rule:**
```bash
gcloud compute firewall-rules describe allow-rdp-windows --project=solutionsarchitect-01
```

**Check VM is running:**
```bash
gcloud compute instances describe confluent-windows-vm \
  --zone=europe-west1-b \
  --project=solutionsarchitect-01
```

**Check external IP:**
```bash
terraform output windows_vm_info
```

### Software Not Installed

During first boot, software installation can take 5-10 minutes.

**Check installation logs:**
1. RDP into the VM
2. Open File Explorer
3. Navigate to: `C:\ProgramData\chocolatey\logs`
4. Open `chocolatey.log`

**Manually install if needed:**
```powershell
# Open PowerShell as Administrator
choco install googlechrome -y
choco install firefox -y
choco install vscode -y
```

### Slow Performance

**Check VM resources:**
1. Open **Task Manager** (Ctrl+Shift+Esc)
2. Check CPU and Memory usage
3. Close unnecessary applications

**Upgrade VM size:**
```bash
# Stop the VM
gcloud compute instances stop confluent-windows-vm \
  --zone=europe-west1-b

# Change machine type
gcloud compute instances set-machine-type confluent-windows-vm \
  --machine-type=n2-standard-8 \
  --zone=europe-west1-b

# Start the VM
gcloud compute instances start confluent-windows-vm \
  --zone=europe-west1-b
```

### Certificate Warnings

The first RDP connection will show a certificate warning. This is normal for self-signed certificates.

**To accept:**
- macOS: Click "Continue"
- Windows: Click "Yes" or "Connect anyway"
- Linux: Check "Accept certificate" option

## Cost Considerations

### Windows VM Costs (approximate)

**VM Instance (n2-standard-4):**
- Per hour: ~$0.194 (standard pricing)
- Per month (24/7): ~$142

**External IP:**
- Per month: ~$3

**Persistent Disk (100 GB Balanced):**
- Per month: ~$17

**Total estimated cost: ~$162/month**

### Cost Optimization Tips

1. **Stop when not in use:**
   ```bash
   gcloud compute instances stop confluent-windows-vm --zone=europe-west1-b
   ```

2. **Use preemptible instance** (for non-production):
   - Up to 80% cheaper
   - Can be terminated by GCP with 30-second warning

3. **Use committed use discounts:**
   - 1-year commitment: 37% discount
   - 3-year commitment: 55% discount

4. **Downsize if possible:**
   - Use n2-standard-2 if performance is sufficient
   - Reduce disk size to 50 GB if not storing large files

## Destroying the Windows VM

When you no longer need the Windows VM:

```bash
# Set to false in env.sh
export TF_VAR_create_windows_vm=false

# Apply changes
source env.sh
terraform apply
```

This will remove:
- The Windows VM instance
- The external IP address
- The RDP firewall rule
- The service account

**Note:** Other infrastructure (Kafka cluster, VPC, bastion VM) remains untouched.

## Alternative: Use Bastion VM

If you prefer command-line access over GUI, use the bastion VM instead:

```bash
# SSH into bastion
ssh terraform@<BASTION_IP>

# Install Confluent CLI
curl -sL --http1.1 https://cnfl.io/cli | sh -s -- latest

# Log in to Confluent Cloud
confluent login --save

# Create topics via CLI
confluent kafka topic create orders \
  --partitions 6 \
  --cluster lkc-drmo3y
```

See `QUICK-START.md` for more bastion VM usage examples.

## Summary

The Windows VM provides a user-friendly, browser-based way to manage your Confluent Cloud Kafka cluster. It's ideal for:
- Users who prefer GUI over command line
- Visual exploration of data and metrics
- Quick topic creation and configuration
- Monitoring dashboards and stream lineage
- Learning and experimentation

For production automation and CI/CD, consider using the Confluent CLI or Terraform from the bastion VM instead.

## Next Steps

1. ✅ Deploy Windows VM with `terraform apply`
2. ✅ Connect via RDP
3. ✅ Open Chrome and log into Confluent Cloud
4. ✅ Create your first topics
5. ✅ Configure ACLs for your service accounts
6. ✅ Set up monitoring dashboards
7. ✅ Explore connectors and ksqlDB

Need help? See:
- `QUICK-START.md` - Quick reference guide
- `PRIVATE-LINK-SETUP.md` - Network connectivity details
- `DEPLOYMENT-COMPLETE.md` - Overall deployment status
