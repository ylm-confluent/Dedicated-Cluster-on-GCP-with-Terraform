output "resource-ids" {
  value = var.create_private_resources ? format(
    <<-EOT
  Environment ID:   %s
  Kafka Cluster ID: %s
  Kafka topic name: %s

  Service Accounts and their Kafka API Keys (API Keys inherit the permissions granted to the owner):
  %s: %s
  %s's Kafka API Key:     "%s"
  %s's Kafka API Secret:  "%s"

  %s: %s
  %s's Kafka API Key:     "%s"
  %s's Kafka API Secret:  "%s"

  %s: %s
  %s's Kafka API Key:    "%s"
  %s's Kafka API Secret: "%s"

  %s: %s
  %s's Kafka API Key:    "%s"
  %s's Kafka API Secret: "%s"

  NOTE: To produce and consume messages, run Terraform from within the VPC with Private Service Connect access.
  EOT
    ,
    confluent_environment.staging.id,
    confluent_kafka_cluster.dedicated.id,
    confluent_kafka_topic.orders[0].topic_name,
    confluent_service_account.env-admin.display_name, confluent_service_account.env-admin.id,
    confluent_service_account.env-admin.display_name, confluent_api_key.env-admin-kafka-api-key.id,
    confluent_service_account.env-admin.display_name, confluent_api_key.env-admin-kafka-api-key.secret,
    confluent_service_account.app-manager.display_name, confluent_service_account.app-manager.id,
    confluent_service_account.app-manager.display_name, confluent_api_key.app-manager-kafka-api-key[0].id,
    confluent_service_account.app-manager.display_name, confluent_api_key.app-manager-kafka-api-key[0].secret,
    confluent_service_account.app-producer.display_name, confluent_service_account.app-producer.id,
    confluent_service_account.app-producer.display_name, confluent_api_key.app-producer-kafka-api-key.id,
    confluent_service_account.app-producer.display_name, confluent_api_key.app-producer-kafka-api-key.secret,
    confluent_service_account.app-consumer.display_name, confluent_service_account.app-consumer.id,
    confluent_service_account.app-consumer.display_name, confluent_api_key.app-consumer-kafka-api-key.id,
    confluent_service_account.app-consumer.display_name, confluent_api_key.app-consumer-kafka-api-key.secret
  ) : format(
    <<-EOT
  Environment ID:   %s
  Kafka Cluster ID: %s
  
  Service Accounts (API Keys and Topics need to be created separately):
  %s: %s
  %s: %s
  %s: %s
  %s: %s

  NOTE: Private resources (Topics and ACLs) were not created because create_private_resources=false.
  To create these resources, you must run Terraform from within the VPC with Private Service Connect access.
  Set TF_VAR_create_private_resources=true in env.sh when running from inside the VPC.
  
  CloudClusterAdmin Service Account (created with full Kafka API key):
  %s: %s
  %s's Kafka API Key:     "%s"
  %s's Kafka API Secret:  "%s"
  
  NOTE: The env-admin service account has CloudClusterAdmin role with full cluster access.
  EOT
    ,
    confluent_environment.staging.id,
    confluent_kafka_cluster.dedicated.id,
    confluent_service_account.app-manager.display_name, confluent_service_account.app-manager.id,
    confluent_service_account.app-producer.display_name, confluent_service_account.app-producer.id,
    confluent_service_account.app-consumer.display_name, confluent_service_account.app-consumer.id,
    confluent_service_account.env-admin.display_name, confluent_service_account.env-admin.id,
    confluent_service_account.env-admin.display_name, confluent_service_account.env-admin.id,
    confluent_service_account.env-admin.display_name, confluent_api_key.env-admin-kafka-api-key.id,
    confluent_service_account.env-admin.display_name, confluent_api_key.env-admin-kafka-api-key.secret
  )

  sensitive = true
}

output "bastion_vm_info" {
  value = var.create_bastion_vm ? format(
    <<-EOT
  Bastion VM Information:
  =====================
  VM Name:        %s
  External IP:    %s
  Internal IP:    %s
  Zone:           %s
  SSH Username:   %s
  
  SSH Commands:
  # Using SSH key (recommended):
  ssh %s@%s
  
  # Or using gcloud:
  gcloud compute ssh %s@%s --zone=%s --project=%s
  
  # Copy Terraform files to VM:
  scp -r ./* %s@%s:~/confluent-terraform/
  
  Next Steps:
  1. Generate SSH key if you haven't: ssh-keygen -t rsa -b 4096 -f ~/.ssh/confluent_bastion
  2. Update env.sh with: export TF_VAR_ssh_public_key="$(cat ~/.ssh/confluent_bastion.pub)"
  3. Run: terraform apply (to update VM with your SSH key)
  4. SSH into the VM using the command above
  5. On the VM: cd ~/confluent-terraform && vim env.sh (set create_private_resources=true)
  6. On the VM: source env.sh && terraform apply
  
  The VM has been configured with:
  - Terraform (latest version)
  - Google Cloud SDK
  - Access to the VPC with Private Service Connect endpoints
  - Sudo access for user '%s'
  EOT
    ,
    google_compute_instance.bastion[0].name,
    google_compute_address.bastion[0].address,
    google_compute_instance.bastion[0].network_interface[0].network_ip,
    google_compute_instance.bastion[0].zone,
    var.ssh_username,
    var.ssh_username,
    google_compute_address.bastion[0].address,
    var.ssh_username,
    google_compute_instance.bastion[0].name,
    google_compute_instance.bastion[0].zone,
    var.customer_project_id,
    var.ssh_username,
    google_compute_address.bastion[0].address,
    var.ssh_username
  ) : "Bastion VM not created. Set TF_VAR_create_bastion_vm=true to create it."
}

output "private_link_network_info" {
  description = "Private Link Network details for GCP PrivateLink"
  value = {
    network_id   = confluent_network.private-link.id
    display_name = confluent_network.private-link.display_name
    dns_domain   = confluent_network.private-link.dns_domain
    zones        = confluent_network.private-link.zones
  }
}

output "private_link_setup_complete" {
  description = "Confirmation that PrivateLink setup is complete"
  value = format(
    <<-EOT
  ✓ Confluent Network: %s
  ✓ Network Type: PrivateLink (Dedicated Cluster)
  ✓ DNS Domain: %s
  ✓ Zones: %s
  
  Status: Your Dedicated Kafka cluster is now accessible via PrivateLink!
  
  Next Steps:
  - You can now access the Kafka cluster from within the VPC
  - To create topics and ACLs, set create_private_resources=true and run terraform apply from the bastion VM
  EOT
    ,
    confluent_network.private-link.id,
    confluent_network.private-link.dns_domain,
    join(", ", confluent_network.private-link.zones)
  )
}

output "windows_vm_info" {
  description = "Windows VM access information for browser-based Confluent Cloud management"
  value = var.create_windows_vm ? format(
    <<-EOT
  ============================================================================
  🪟 WINDOWS VM ACCESS INFORMATION
  ============================================================================
  
  VM Name:          %s
  External IP:      %s
  Internal IP:      %s
  Machine Type:     n2-standard-4 (4 vCPUs, 16 GB RAM)
  Operating System: Windows Server 2022
  
  📋 RDP Connection:
  ------------------
  Username: %s
  Password: [The password you set in TF_VAR_windows_admin_password]
  
  To connect via RDP:
  
  macOS:
    1. Install Microsoft Remote Desktop from the App Store
    2. Click '+' → Add PC
    3. PC Name: %s
    4. User account: %s
    5. Connect and enter your password
  
  Windows:
    1. Open Remote Desktop Connection (mstsc.exe)
    2. Computer: %s
    3. Username: %s
    4. Connect and enter your password
  
  Linux:
    rdesktop %s -u %s
    # Or use Remmina GUI application
  
  🎯 Pre-installed Software:
  --------------------------
  ✓ Google Chrome (default browser, opens to Confluent Cloud)
  ✓ Mozilla Firefox (alternative browser)
  ✓ Visual Studio Code (for viewing configurations)
  ✓ 7-Zip (file extraction)
  ✓ Chocolatey (package manager)
  
  📄 Desktop Shortcuts:
  ---------------------
  ✓ Confluent-Welcome.html - Quick links and information
  ✓ Google Chrome - Pre-configured to open Confluent Cloud
  ✓ Firefox - Alternative browser
  
  🌐 What You Can Do:
  -------------------
  • Create and manage Kafka topics via Confluent Cloud UI
  • Configure ACLs and permissions
  • Monitor cluster metrics and health
  • Set up connectors and ksqlDB
  • Manage Schema Registry
  • Access Stream Lineage and Data Flow diagrams
  
  ⚡ Performance Notes:
  ---------------------
  • 4 vCPUs ensure smooth browser experience
  • 16 GB RAM handles multiple browser tabs
  • Balanced persistent disk for good I/O
  • Connected to same VPC as Kafka cluster
  
  🔒 Security Notes:
  ------------------
  • VM is in the same VPC as your Kafka cluster
  • RDP access currently allows all IPs (0.0.0.0/0)
  • Consider restricting source_ranges in the firewall rule
  • Use a strong password for the admin account
  
  ⏱️  First Boot:
  ----------------
  The VM may take 5-10 minutes on first boot to:
  • Complete Windows setup
  • Install all software via startup script
  • Configure browser settings
  
  If Chrome isn't installed yet, wait a few minutes and check the
  C:\ProgramData\chocolatey\logs directory for installation logs.
  
  ============================================================================
  EOT
    ,
    google_compute_instance.windows_vm[0].name,
    google_compute_address.windows_vm[0].address,
    google_compute_instance.windows_vm[0].network_interface[0].network_ip,
    var.windows_admin_username,
    google_compute_address.windows_vm[0].address,
    var.windows_admin_username,
    google_compute_address.windows_vm[0].address,
    var.windows_admin_username,
    google_compute_address.windows_vm[0].address,
    var.windows_admin_username
  ) : "Windows VM not created. Set TF_VAR_create_windows_vm=true to create it."
}

# ============================================================================
# Egress Private Service Connect Endpoint Information
# ============================================================================

output "egress_endpoint_info" {
  description = "Information about the egress Private Service Connect endpoint for Google APIs"
  value       = var.enable_egress_endpoint ? format(<<-EOT

============================================================================
🌐 EGRESS PRIVATE SERVICE CONNECT ENDPOINT - ✅ READY
============================================================================
  
✅ Setup Complete! Your cluster can now access Google Cloud APIs privately.
  
📡 Confluent Configuration:
---------------------------
Gateway ID:         %s
Access Point ID:    %s
Access Point Name:  %s
Target:             all-google-apis
Status:             Active
Endpoint IP:        %s
  
📡 GCP Network Configuration:
------------------------------
Egress Subnet:      confluent-egress-psc-subnet (10.1.0.0/24)
DNS Zone (googleapis.com): *.googleapis.com → %s
DNS Zone (gcr.io):          *.gcr.io → %s
  
🔐 Private Access Enabled For:
-------------------------------
✓ Google Cloud Storage (storage.googleapis.com)
✓ Google BigQuery (bigquery.googleapis.com)
✓ Google Pub/Sub (pubsub.googleapis.com)
✓ Google Container Registry (gcr.io)
✓ All other Google Cloud APIs (*.googleapis.com)
  
🎯 Use Cases:
-------------
• Kafka Connect to Google Cloud Storage
• BigQuery Sink/Source Connectors
• Pub/Sub Connectors
• GCS Sink Connector for data lake integration
• Schema Registry with GCS backend
• Cloud Functions integration
  
💡 Configuration Examples:
--------------------------
  
GCS Sink Connector Configuration:
  "gcs.bucket.name": "your-bucket-name",
  "gcs.credentials.json": "{{ your-service-account-key }}",
  "topics": "your-topic",
  "tasks.max": "1"
  
BigQuery Sink Connector Configuration:
  "project": "your-project-id",
  "datasets": "your-dataset",
  "topics": "your-topic",
  "keyfile": "{{ your-service-account-key }}"
  
📝 Important Notes:
-------------------
• All traffic to Google Cloud APIs goes through this private endpoint
• No public internet egress required for Google Cloud services
• Reduced data transfer costs (no egress charges within GCP)
• Enhanced security with private connectivity
• Service account credentials still required for authentication
• DNS resolution automatically routes *.googleapis.com and *.gcr.io
  
⚡ Testing Connectivity:
------------------------
From bastion VM or within VPC:
  
1. Test DNS resolution (should return 10.2.255.255):
   nslookup storage.googleapis.com
   nslookup bigquery.googleapis.com
  
2. Test HTTPS connectivity:
   curl -I https://storage.googleapis.com
   curl -I https://bigquery.googleapis.com
  
3. Configure Kafka Connect connector with Google Cloud service
  
============================================================================
  
  EOT
    ,
    data.confluent_gateway.egress.id,
    confluent_access_point.gcp_apis.id,
    confluent_access_point.gcp_apis.display_name,
    confluent_access_point.gcp_apis.gcp_egress_private_service_connect_endpoint[0].private_service_connect_endpoint_ip_address,
    confluent_access_point.gcp_apis.gcp_egress_private_service_connect_endpoint[0].private_service_connect_endpoint_ip_address,
    confluent_access_point.gcp_apis.gcp_egress_private_service_connect_endpoint[0].private_service_connect_endpoint_ip_address
  ) : ""
}