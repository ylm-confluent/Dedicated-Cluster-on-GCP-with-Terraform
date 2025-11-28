terraform {
  required_version = ">= 0.14.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    confluent = {
      source  = "confluentinc/confluent"
      version = "2.44.0"
    }
  }
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

# Set GOOGLE_APPLICATION_CREDENTIALS environment variable to a path to a key file
# for Google TF Provider to work: https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/getting_started#adding-credentials
provider "google" {
  project = var.customer_project_id
  region  = var.region
}

# Enable required GCP APIs
resource "google_project_service" "compute" {
  project = var.customer_project_id
  service = "compute.googleapis.com"
  
  disable_on_destroy = false
}

resource "google_project_service" "servicenetworking" {
  project = var.customer_project_id
  service = "servicenetworking.googleapis.com"
  
  disable_on_destroy = false
}

# Create VPC Network
resource "google_compute_network" "confluent_network" {
  name                    = var.customer_vpc_network
  auto_create_subnetworks = false
  
  depends_on = [
    google_project_service.compute
  ]
}

# Create main subnet
resource "google_compute_subnetwork" "confluent_subnetwork" {
  name          = var.customer_subnetwork_name
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.confluent_network.id
}

# Create Private Service Connect subnets for each zone
resource "google_compute_subnetwork" "psc_subnets" {
  for_each = var.subnet_name_by_zone
  
  name          = "${each.value}-v2"
  ip_cidr_range = "10.0.${index(keys(var.subnet_name_by_zone), each.key) + 1}.0/24"
  region        = var.region
  network       = google_compute_network.confluent_network.id
  purpose       = "PRIVATE_SERVICE_CONNECT"
  
  depends_on = [
    google_project_service.servicenetworking
  ]
}

# Create a service account for the bastion VM
resource "google_service_account" "bastion" {
  count        = var.create_bastion_vm ? 1 : 0
  account_id   = "bastion-vm-sa-v2"
  display_name = "Bastion VM Service Account V2"
  description  = "Service account for bastion VM to run Terraform"
}

# Grant necessary roles to the service account
resource "google_project_iam_member" "bastion_compute_admin" {
  count   = var.create_bastion_vm ? 1 : 0
  project = var.customer_project_id
  role    = "roles/compute.admin"
  member  = "serviceAccount:${google_service_account.bastion[0].email}"
}

resource "google_project_iam_member" "bastion_storage_admin" {
  count   = var.create_bastion_vm ? 1 : 0
  project = var.customer_project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.bastion[0].email}"
}

# Create a static external IP for the bastion VM
resource "google_compute_address" "bastion" {
  count = var.create_bastion_vm ? 1 : 0
  name  = "bastion-external-ip-v2"
}

# Create firewall rule to allow SSH
resource "google_compute_firewall" "allow_ssh" {
  count   = var.create_bastion_vm ? 1 : 0
  name    = "allow-ssh-bastion-v2"
  network = google_compute_network.confluent_network.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]  # Change this to your IP for better security
  target_tags   = ["bastion"]
}

# Create the bastion VM
resource "google_compute_instance" "bastion" {
  count        = var.create_bastion_vm ? 1 : 0
  name         = "confluent-bastion-vm"
  machine_type = "e2-medium"
  zone         = "${var.region}-b"

  tags = ["bastion"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 50
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.confluent_subnetwork.id

    access_config {
      nat_ip = google_compute_address.bastion[0].address
    }
  }

  service_account {
    email  = google_service_account.bastion[0].email
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-oslogin = "FALSE"
    ssh-keys       = var.ssh_public_key != "" ? "${var.ssh_username}:${var.ssh_public_key}" : ""
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    set -e
    
    # Update system
    apt-get update
    apt-get upgrade -y
    
    # Install required packages
    apt-get install -y wget unzip git curl
    
    # Install Terraform
    TERRAFORM_VERSION="1.5.7"
    wget https://releases.hashicorp.com/terraform/$${TERRAFORM_VERSION}/terraform_$${TERRAFORM_VERSION}_linux_amd64.zip
    unzip terraform_$${TERRAFORM_VERSION}_linux_amd64.zip
    mv terraform /usr/local/bin/
    rm terraform_$${TERRAFORM_VERSION}_linux_amd64.zip
    
    # Install Google Cloud SDK
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
    apt-get update
    apt-get install -y google-cloud-sdk
    
    # Install Confluent CLI
    curl -sL --http1.1 https://cnfl.io/cli | sh -s -- latest
    # Move confluent CLI to system path
    mv /root/.local/bin/confluent /usr/local/bin/
    
    # Create terraform user if using SSH keys
    if ! id "${var.ssh_username}" &>/dev/null; then
      useradd -m -s /bin/bash ${var.ssh_username}
      # Add to sudo group
      usermod -aG sudo ${var.ssh_username}
      # Allow sudo without password
      echo "${var.ssh_username} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${var.ssh_username}
    fi
    
    # Create workspace directory
    mkdir -p /home/${var.ssh_username}/confluent-terraform
    chown -R ${var.ssh_username}:${var.ssh_username} /home/${var.ssh_username}/confluent-terraform
    
    # Create helper script
    cat > /home/${var.ssh_username}/setup-terraform.sh << 'SCRIPT'
#!/bin/bash
echo "================================================"
echo "  Confluent Cloud Terraform Bastion VM"
echo "================================================"
echo ""
echo "This VM is configured to run Terraform with access to:"
echo "  - Private Service Connect endpoints"
echo "  - Confluent Cloud Kafka cluster"
echo ""
echo "Installed tools:"
echo "  - Terraform: $(terraform version | head -n1)"
echo "  - gcloud: $(gcloud version --format='value(version)' 2>/dev/null | head -n1)"
echo "  - Confluent CLI: $(confluent version 2>/dev/null || echo 'Not found in PATH')"
echo ""
echo "To deploy private resources (topics, ACLs):"
echo "  1. Upload your Terraform files to ~/confluent-terraform/"
echo "  2. cd ~/confluent-terraform"
echo "  3. Edit env.sh and set: export TF_VAR_create_private_resources=true"
echo "  4. source env.sh"
echo "  5. terraform apply"
echo ""
echo "To use Confluent CLI:"
echo "  1. confluent login --save"
echo "  2. confluent environment use <env-id>"
echo "  3. confluent kafka cluster use <cluster-id>"
echo "  4. confluent kafka topic create <topic-name>"
echo ""
echo "================================================"
SCRIPT
    
    chmod +x /home/${var.ssh_username}/setup-terraform.sh
    chown ${var.ssh_username}:${var.ssh_username} /home/${var.ssh_username}/setup-terraform.sh
    
    # Add to user's bashrc
    echo "" >> /home/${var.ssh_username}/.bashrc
    echo "# Welcome message" >> /home/${var.ssh_username}/.bashrc
    echo "~/setup-terraform.sh" >> /home/${var.ssh_username}/.bashrc
    
    echo "Bastion VM setup complete at $(date)" > /var/log/startup-script.log
  EOF

  depends_on = [
    google_compute_subnetwork.confluent_subnetwork,
    google_service_account.bastion
  ]
}

# ============================================================================
# Windows VM for Browser-Based Management
# ============================================================================

# Create a service account for the Windows VM
resource "google_service_account" "windows_vm" {
  count        = var.create_windows_vm ? 1 : 0
  account_id   = "windows-vm-sa-v2"
  display_name = "Windows VM Service Account V2"
  description  = "Service account for Windows VM for browser-based Confluent Cloud access"
}

# Grant necessary roles to the Windows VM service account
resource "google_project_iam_member" "windows_vm_compute_viewer" {
  count   = var.create_windows_vm ? 1 : 0
  project = var.customer_project_id
  role    = "roles/compute.viewer"
  member  = "serviceAccount:${google_service_account.windows_vm[0].email}"
}

# Create a static external IP for the Windows VM
resource "google_compute_address" "windows_vm" {
  count = var.create_windows_vm ? 1 : 0
  name  = "windows-vm-external-ip-v2"
}

# Create firewall rule to allow RDP
resource "google_compute_firewall" "allow_rdp" {
  count   = var.create_windows_vm ? 1 : 0
  name    = "allow-rdp-windows-v2"
  network = google_compute_network.confluent_network.id

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }

  source_ranges = ["0.0.0.0/0"]  # Change this to your IP for better security
  target_tags   = ["windows-rdp"]
}

# Create the Windows VM with good performance specs
resource "google_compute_instance" "windows_vm" {
  count        = var.create_windows_vm ? 1 : 0
  name         = "confluent-windows-vm"
  machine_type = "n2-standard-4"  # 4 vCPUs, 16 GB RAM for smooth browser performance
  zone         = "${var.region}-b"

  allow_stopping_for_update = true
  
  tags = ["windows-rdp"]

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2022"  # Windows Server 2022
      size  = 100  # 100 GB disk
      type  = "pd-balanced"  # Balanced persistent disk for good performance
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.confluent_subnetwork.id

    access_config {
      nat_ip = google_compute_address.windows_vm[0].address
    }
  }

  service_account {
    email  = google_service_account.windows_vm[0].email
    scopes = ["cloud-platform"]
  }

  metadata = {
    windows-startup-script-ps1 = <<-PWSH
      # Set timezone to UTC (change as needed)
      Set-TimeZone -Id "UTC"
      
      # Disable IE Enhanced Security Configuration for easier browsing
      Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}' -Name 'IsInstalled' -Value 0
      Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}' -Name 'IsInstalled' -Value 0
      
      # Install Chocolatey package manager
      Set-ExecutionPolicy Bypass -Scope Process -Force
      [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
      iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
      
      # Install Google Chrome
      choco install googlechrome -y
      
      # Install Firefox as alternative
      choco install firefox -y
      
      # Install Visual Studio Code (optional, for viewing configs)
      choco install vscode -y
      
      # Install 7-Zip (for any file extraction needs)
      choco install 7zip -y
      
      # Create shortcuts on desktop
      $WshShell = New-Object -comObject WScript.Shell
      
      # Chrome shortcut with Private Network Access enabled for Confluent Cloud
      # This allows Chrome to access the private Kafka cluster endpoints (10.0.0.x)
      $ChromeShortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\Chrome - Confluent Cloud.lnk")
      $ChromeShortcut.TargetPath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
      $ChromeShortcut.Arguments = "--disable-features=BlockInsecurePrivateNetworkRequests --new-window https://confluent.cloud"
      $ChromeShortcut.Description = "Chrome for Confluent Cloud (Private Network Access Enabled)"
      $ChromeShortcut.Save()
      
      # Edge shortcut with Private Network Access enabled
      $EdgeShortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\Edge - Confluent Cloud.lnk")
      $EdgeShortcut.TargetPath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
      $EdgeShortcut.Arguments = "--disable-features=BlockInsecurePrivateNetworkRequests --new-window https://confluent.cloud"
      $EdgeShortcut.Description = "Edge for Confluent Cloud (Private Network Access Enabled)"
      $EdgeShortcut.Save()
      
      # Create a welcome HTML file
      $welcomeHtml = @"
<!DOCTYPE html>
<html>
<head>
    <title>Confluent Cloud Access</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #0073e6; }
        .link-box { background: #f0f8ff; padding: 20px; margin: 20px 0; border-radius: 5px; border-left: 4px solid #0073e6; }
        a { color: #0073e6; text-decoration: none; font-size: 18px; }
        a:hover { text-decoration: underline; }
        .info { background: #fffbf0; padding: 15px; margin: 15px 0; border-radius: 5px; border-left: 4px solid #ffcc00; }
        code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Confluent Cloud Access VM</h1>
        <p>Welcome to your Windows VM with private access to Confluent Cloud!</p>
        
        <div class="link-box">
            <h2>Quick Links</h2>
            <p><a href="https://confluent.cloud" target="_blank">→ Confluent Cloud Console</a></p>
            <p><a href="https://docs.confluent.io/cloud/current/overview.html" target="_blank">→ Confluent Cloud Documentation</a></p>
        </div>
        
        <div class="info">
            <h3>ℹ️ About This VM</h3>
            <ul>
                <li><strong>Purpose:</strong> Browser-based access to Confluent Cloud</li>
                <li><strong>Network:</strong> Connected to VPC with Private Service Connect</li>
                <li><strong>Browsers:</strong> Chrome and Edge (pre-configured for private network access)</li>
                <li><strong>Editor:</strong> Visual Studio Code (for viewing configurations)</li>
            </ul>
            <p style="background: #fff3cd; padding: 10px; border-radius: 5px; margin-top: 10px;">
                <strong>⚠️ Important:</strong> Use the desktop shortcuts "Chrome - Confluent Cloud" or "Edge - Confluent Cloud" 
                to access Confluent Cloud. These shortcuts are configured to allow access to private cluster endpoints. 
                Regular browser windows will be blocked by browser security policies.
            </p>
        </div>
        
        <div class="info">
            <h3>📊 Your Confluent Cloud Environment</h3>
            <ul>
                <li><strong>Environment:</strong> Take-alot-POC</li>
                <li><strong>Cluster:</strong> takealot-poc</li>
                <li><strong>Region:</strong> europe-west1 (GCP)</li>
                <li><strong>Access:</strong> Private via PSC</li>
            </ul>
        </div>
        
        <div class="info">
            <h3>✅ What You Can Do</h3>
            <ul>
                <li>Create and manage Kafka topics via web UI</li>
                <li>Monitor cluster health and metrics</li>
                <li>Configure connectors and stream processing</li>
                <li>View and manage ACLs and service accounts</li>
                <li>Access Schema Registry</li>
            </ul>
        </div>
        
        <p><small>VM automatically configured for optimal browser performance</small></p>
    </div>
</body>
</html>
"@
      
      $welcomeHtml | Out-File -FilePath "C:\Users\Public\Desktop\Confluent-Welcome.html" -Encoding UTF8
      
      # Create Firefox shortcut
      $FirefoxShortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\Firefox.lnk")
      $FirefoxShortcut.TargetPath = "C:\Program Files\Mozilla Firefox\firefox.exe"
      $FirefoxShortcut.Save()
      
      Write-Host "Windows VM setup complete!"
    PWSH
  }

  # Allow time for Windows to initialize
  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  depends_on = [
    google_compute_subnetwork.confluent_subnetwork,
    google_service_account.windows_vm
  ]
}

resource "confluent_environment" "staging" {
  display_name = var.environment_name

  stream_governance {
    package = "ESSENTIALS"
  }
}

data "confluent_schema_registry_cluster" "essentials" {
  environment {
    id = confluent_environment.staging.id
  }

  depends_on = [
    confluent_kafka_cluster.dedicated
  ]
}

resource "confluent_kafka_cluster" "dedicated" {
  display_name = var.cluster_name
  availability = "HIGH"
  cloud        = "GCP"
  region       = var.region
  dedicated {
    cku = var.cku_count
  }
  
  network {
    id = confluent_network.private-link.id
  }
  
  environment {
    id = confluent_environment.staging.id
  }
}

# Network for Dedicated cluster with PrivateLink
resource "confluent_network" "private-link" {
  display_name     = "${var.cluster_name}-private-link-network"
  cloud            = "GCP"
  region           = var.region
  connection_types = ["PRIVATELINK"]
  zones            = keys(var.subnet_name_by_zone)
  environment {
    id = confluent_environment.staging.id
  }
  
  # Enable private DNS resolution - this auto-creates a gateway for egress endpoints
  dns_config {
    resolution = "PRIVATE"
  }
}

# Private Link Access for GCP
resource "confluent_private_link_access" "gcp" {
  display_name = "${var.cluster_name}-gcp-privatelink"
  gcp {
    project = var.customer_project_id
  }
  environment {
    id = confluent_environment.staging.id
  }
  network {
    id = confluent_network.private-link.id
  }
}

# ============================================================================
# Egress Private Service Connect Endpoint for Google Cloud APIs
# ============================================================================
# This allows Confluent Cloud to privately access Google Cloud APIs
# (Storage, BigQuery, Pub/Sub, etc.) without going over the public internet
#
# NOTE: As of Confluent Terraform Provider 2.32.0, GCP Egress Private Link 
# is not yet supported via Terraform. This feature is available via:
# 1. Confluent Cloud UI (recommended for now)
# 2. Confluent CLI
# 3. REST API
#
# To set up via Confluent Cloud UI:
# 1. Go to your environment in Confluent Cloud
# 2. Navigate to "Network" > "Gateways"
# 3. Create a new "GCP Egress Private Link Gateway" in europe-west1
# 4. Create an "Access Point" targeting "ALL_GOOGLE_APIS"
# 5. Note the PSC Service Attachment ID
# 6. Use the GCP resources below to accept the connection
#
# ============================================================================
# GCP Egress Private Service Connect Endpoint
# ============================================================================
# Gateway is automatically created by the network when dns_config.resolution = "PRIVATE"
# Reference: https://github.com/confluentinc/terraform-provider-confluent/blob/master/examples/configurations/network-access-point-gcp-private-service-connect/main.tf

# Data source to reference the auto-created gateway
data "confluent_gateway" "egress" {
  id = confluent_network.private-link.gateway[0].id
  environment {
    id = confluent_environment.staging.id
  }
  depends_on = [
    confluent_network.private-link
  ]
}

# Access Point for Google Cloud APIs private egress
resource "confluent_access_point" "gcp_apis" {
  display_name = "${var.cluster_name}-gcp-apis-access-point"
  
  environment {
    id = confluent_environment.staging.id
  }
  
  gateway {
    id = data.confluent_gateway.egress.id
  }
  
  gcp_egress_private_service_connect_endpoint {
    private_service_connect_endpoint_target = "all-google-apis"
  }
  
  depends_on = [
    confluent_network.private-link,
    data.confluent_gateway.egress
  ]
}

# ============================================================================
# GCP Private Service Connect endpoints for Dedicated cluster PrivateLink
# ============================================================================
resource "google_compute_address" "privatelink_ip" {
  for_each = var.subnet_name_by_zone

  name         = "confluent-privatelink-ip-${each.key}"
  subnetwork   = google_compute_subnetwork.confluent_subnetwork.id
  address_type = "INTERNAL"
  region       = var.region
}

resource "google_compute_forwarding_rule" "privatelink" {
  for_each = var.subnet_name_by_zone

  name                  = "confluent-privatelink-v2-${each.key}"
  target                = confluent_network.private-link.gcp[0].private_service_connect_service_attachments[each.key]
  load_balancing_scheme = ""
  network               = google_compute_network.confluent_network.id
  ip_address            = google_compute_address.privatelink_ip[each.key].id
  region                = var.region
  
  depends_on = [
    confluent_private_link_access.gcp
  ]
}

# DNS configuration for PrivateLink
resource "google_dns_managed_zone" "privatelink" {
  name     = "confluent-privatelink-zone"
  dns_name = "${confluent_network.private-link.dns_domain}."

  visibility = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.confluent_network.id
    }
  }
}

resource "google_dns_record_set" "privatelink" {
  name = "*.${google_dns_managed_zone.privatelink.dns_name}"
  type = "A"
  ttl  = 60

  managed_zone = google_dns_managed_zone.privatelink.name
  rrdatas = [
    for zone, _ in var.subnet_name_by_zone : google_compute_address.privatelink_ip[zone].address
  ]
}

resource "google_dns_record_set" "privatelink_zonal" {
  for_each = var.subnet_name_by_zone

  name = "*.${each.key}.${google_dns_managed_zone.privatelink.dns_name}"
  type = "A"
  ttl  = 60

  managed_zone = google_dns_managed_zone.privatelink.name
  rrdatas      = [google_compute_address.privatelink_ip[each.key].address]
}

resource "google_compute_firewall" "privatelink" {
  name    = "confluent-privatelink-firewall"
  network = google_compute_network.confluent_network.id

  allow {
    protocol = "tcp"
    ports    = ["443", "9092"]
  }

  direction          = "EGRESS"
  destination_ranges = [google_compute_subnetwork.confluent_subnetwork.ip_cidr_range]
}

# ============================================================================
# GCP Resources for Egress Private Service Connect Endpoint
# ============================================================================
# These resources allow Confluent Cloud to access Google Cloud APIs privately
# Set TF_VAR_enable_egress_endpoint=true and provide the PSC Service Attachment ID
# from Confluent Cloud UI in TF_VAR_egress_psc_service_attachment

# Subnet for egress PSC endpoint
resource "google_compute_subnetwork" "egress_psc" {
  count         = var.enable_egress_endpoint ? 1 : 0
  name          = "confluent-egress-psc-subnet"
  ip_cidr_range = "10.1.0.0/24"  # Separate range for egress endpoint
  region        = var.region
  network       = google_compute_network.confluent_network.id
  purpose       = "PRIVATE_SERVICE_CONNECT"
}

# Note: Cannot reserve specific IP address in PRIVATE_SERVICE_CONNECT subnet
# The IP will be automatically assigned by GCP when creating the forwarding rule


# Forwarding rule for egress PSC endpoint
# Note: The private_service_connect_endpoint_target becomes the service attachment URI
# after the access point is created. Comment this out initially, then uncomment after
# running first apply to create Confluent resources.
# 
# Alternatively, check Confluent Cloud Console for the service attachment URI and
# pass it via a variable.
#
# Note: No GCP forwarding rule is needed for egress endpoints!
# The Confluent access point handles the connection to Google APIs
# and provides the IP address (10.2.255.255) that we configure in DNS.
# Just point your DNS records to:
# confluent_access_point.gcp_apis.gcp_egress_private_service_connect_endpoint[0].private_service_connect_endpoint_ip_address

# DNS zone for Google APIs (googleapis.com)
resource "google_dns_managed_zone" "googleapis" {
  count    = var.enable_egress_endpoint ? 1 : 0
  name     = "googleapis-private-zone"
  dns_name = "googleapis.com."

  visibility = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.confluent_network.id
    }
  }
}

# DNS A record pointing *.googleapis.com to the egress PSC endpoint
# The Confluent access point provides the IP address directly
resource "google_dns_record_set" "googleapis" {
  count = var.enable_egress_endpoint ? 1 : 0
  name  = "*.googleapis.com."
  type  = "A"
  ttl   = 300

  managed_zone = google_dns_managed_zone.googleapis[0].name
  rrdatas      = [confluent_access_point.gcp_apis.gcp_egress_private_service_connect_endpoint[0].private_service_connect_endpoint_ip_address]
}

# Additional DNS zone for specific Google services if needed
resource "google_dns_managed_zone" "gcr" {
  count    = var.enable_egress_endpoint ? 1 : 0
  name     = "gcr-private-zone"
  dns_name = "gcr.io."

  visibility = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.confluent_network.id
    }
  }
}

# DNS A record for gcr.io - points to the same Confluent egress endpoint
resource "google_dns_record_set" "gcr" {
  count = var.enable_egress_endpoint ? 1 : 0
  name  = "*.gcr.io."
  type  = "A"
  ttl   = 300

  managed_zone = google_dns_managed_zone.gcr[0].name
  rrdatas      = [confluent_access_point.gcp_apis.gcp_egress_private_service_connect_endpoint[0].private_service_connect_endpoint_ip_address]
}


# Firewall rule to allow egress to Google APIs via PSC
resource "google_compute_firewall" "egress_psc" {
  count   = var.enable_egress_endpoint ? 1 : 0
  name    = "confluent-egress-psc-allow"
  network = google_compute_network.confluent_network.id

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  direction          = "EGRESS"
  destination_ranges = [google_compute_subnetwork.egress_psc[0].ip_cidr_range]
  
  target_tags = ["confluent-cluster"]
}

# ============================================================================
# Service Accounts and Permissions
# ============================================================================
resource "confluent_service_account" "env-admin" {
  display_name = "env-admin-v2"
  description  = "Service account with CloudClusterAdmin role for full cluster management"
}

resource "confluent_role_binding" "env-admin-kafka-cluster-admin" {
  principal   = "User:${confluent_service_account.env-admin.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.dedicated.rbac_crn
}

resource "confluent_api_key" "env-admin-kafka-api-key" {
  display_name           = "env-admin-kafka-api-key"
  description            = "Kafka API Key that is owned by 'env-admin' service account"
  disable_wait_for_ready = true
  owner {
    id          = confluent_service_account.env-admin.id
    api_version = confluent_service_account.env-admin.api_version
    kind        = confluent_service_account.env-admin.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.dedicated.id
    api_version = confluent_kafka_cluster.dedicated.api_version
    kind        = confluent_kafka_cluster.dedicated.kind

    environment {
      id = confluent_environment.staging.id
    }
  }

  # The goal is to ensure that
  # 1. confluent_role_binding.env-admin-kafka-cluster-admin is created before
  # confluent_api_key.env-admin-kafka-api-key is used.
  # 2. Kafka connectivity through GCP PrivateLink is setup.
  depends_on = [
    confluent_role_binding.env-admin-kafka-cluster-admin,
    google_compute_forwarding_rule.privatelink,
  ]
}

// 'app-manager' service account is required in this configuration to create 'orders' topic and grant ACLs
// to 'app-producer' and 'app-consumer' service accounts.
resource "confluent_service_account" "app-manager" {
  display_name = "app-manager-v2"
  description  = "Service account to manage 'inventory' Kafka cluster"
}

resource "confluent_role_binding" "app-manager-kafka-cluster-admin" {
  principal   = "User:${confluent_service_account.app-manager.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.dedicated.rbac_crn
}

resource "confluent_api_key" "app-manager-kafka-api-key" {
  count        = var.create_private_resources ? 1 : 0
  display_name = "app-manager-kafka-api-key"
  description  = "Kafka API Key that is owned by 'app-manager' service account"
  owner {
    id          = confluent_service_account.app-manager.id
    api_version = confluent_service_account.app-manager.api_version
    kind        = confluent_service_account.app-manager.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.dedicated.id
    api_version = confluent_kafka_cluster.dedicated.api_version
    kind        = confluent_kafka_cluster.dedicated.kind

    environment {
      id = confluent_environment.staging.id
    }
  }

  # The goal is to ensure that
  # 1. confluent_role_binding.app-manager-kafka-cluster-admin is created before
  # confluent_api_key.app-manager-kafka-api-key is used to create instances of
  # confluent_kafka_topic, confluent_kafka_acl resources.
  # 2. Kafka connectivity through GCP PrivateLink is setup.
  depends_on = [
    confluent_role_binding.app-manager-kafka-cluster-admin,
    google_compute_forwarding_rule.privatelink,
  ]
}

resource "confluent_kafka_topic" "orders" {
  count = var.create_private_resources ? 1 : 0
  kafka_cluster {
    id = confluent_kafka_cluster.dedicated.id
  }
  topic_name    = "orders"
  rest_endpoint = confluent_kafka_cluster.dedicated.rest_endpoint
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key[0].id
    secret = confluent_api_key.app-manager-kafka-api-key[0].secret
  }
}

resource "confluent_service_account" "app-consumer" {
  display_name = "app-consumer-v2"
  description  = "Service account to consume from 'orders' topic of 'inventory' Kafka cluster"
}

resource "confluent_api_key" "app-consumer-kafka-api-key" {
  display_name           = "app-consumer-kafka-api-key"
  description            = "Kafka API Key that is owned by 'app-consumer' service account"
  disable_wait_for_ready = true
  owner {
    id          = confluent_service_account.app-consumer.id
    api_version = confluent_service_account.app-consumer.api_version
    kind        = confluent_service_account.app-consumer.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.dedicated.id
    api_version = confluent_kafka_cluster.dedicated.api_version
    kind        = confluent_kafka_cluster.dedicated.kind

    environment {
      id = confluent_environment.staging.id
    }
  }

  # The goal is to ensure that Kafka connectivity through GCP PrivateLink is setup.
  depends_on = [
    google_compute_forwarding_rule.privatelink,
  ]
}

resource "confluent_service_account" "app-producer" {
  display_name = "app-producer-v2"
  description  = "Service account to produce to 'orders' topic of 'inventory' Kafka cluster"
}

// RBAC role binding for app-producer - grants write access to 'orders' topic
resource "confluent_role_binding" "app-producer-write-on-topic" {
  principal   = "User:${confluent_service_account.app-producer.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${confluent_kafka_cluster.dedicated.rbac_crn}/kafka=${confluent_kafka_cluster.dedicated.id}/topic=${var.create_private_resources ? confluent_kafka_topic.orders[0].topic_name : "orders"}"
}

resource "confluent_api_key" "app-producer-kafka-api-key" {
  display_name           = "app-producer-kafka-api-key"
  description            = "Kafka API Key that is owned by 'app-producer' service account"
  disable_wait_for_ready = true
  owner {
    id          = confluent_service_account.app-producer.id
    api_version = confluent_service_account.app-producer.api_version
    kind        = confluent_service_account.app-producer.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.dedicated.id
    api_version = confluent_kafka_cluster.dedicated.api_version
    kind        = confluent_kafka_cluster.dedicated.kind

    environment {
      id = confluent_environment.staging.id
    }
  }

  # The goal is to ensure that Kafka connectivity through GCP PrivateLink is setup.
  depends_on = [
    google_compute_forwarding_rule.privatelink,
  ]
}

// RBAC role bindings for app-consumer - grants read access to 'orders' topic and consumer groups
resource "confluent_role_binding" "app-consumer-read-on-topic" {
  principal   = "User:${confluent_service_account.app-consumer.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${confluent_kafka_cluster.dedicated.rbac_crn}/kafka=${confluent_kafka_cluster.dedicated.id}/topic=${var.create_private_resources ? confluent_kafka_topic.orders[0].topic_name : "orders"}"
}

resource "confluent_role_binding" "app-consumer-read-on-group" {
  principal   = "User:${confluent_service_account.app-consumer.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${confluent_kafka_cluster.dedicated.rbac_crn}/kafka=${confluent_kafka_cluster.dedicated.id}/group=*"
}
