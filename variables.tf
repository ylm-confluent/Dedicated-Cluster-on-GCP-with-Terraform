variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API Key (also referred as Cloud API ID)"
  type        = string
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API Secret"
  type        = string
  sensitive   = true
}

variable "customer_project_id" {
  description = "The GCP Project ID"
  type        = string
}

variable "region" {
  description = "The region of Confluent Cloud Network"
  type        = string
}

variable "customer_vpc_network" {
  description = "The VPC network name to provision Private Service Connect endpoint to Confluent Cloud"
  type        = string
}

variable "customer_subnetwork_name" {
  description = "The subnetwork name to provision Private Service Connect endpoint to Confluent Cloud"
  type        = string
}

variable "subnet_name_by_zone" {
  description = "A map of Zone to Subnet Name"
  type        = map(string)
}

variable "environment_name" {
  description = "The name of the Confluent Cloud Environment"
  type        = string
  default     = "Staging"
}

variable "cluster_name" {
  description = "The name of the Kafka Cluster"
  type        = string
  default     = "inventory"
}

variable "cku_count" {
  description = "The number of Confluent Kafka Units (CKUs) for the Dedicated cluster. Minimum is 1 for single zone, 2 for multi-zone"
  type        = number
  default     = 2
}

variable "create_private_resources" {
  description = "Whether to create resources that require private network access (topics, ACLs). Set to false if running Terraform from outside the VPC."
  type        = bool
  default     = false
}

variable "create_bastion_vm" {
  description = "Whether to create a bastion VM in the VPC for running Terraform to create private resources"
  type        = bool
  default     = false
}

variable "ssh_public_key" {
  description = "SSH public key for accessing the bastion VM. Generate with: ssh-keygen -t rsa -b 4096 -C 'your_email@example.com'"
  type        = string
  default     = ""
}

variable "ssh_username" {
  description = "Username for SSH access to the bastion VM"
  type        = string
  default     = "terraform"
}

variable "create_windows_vm" {
  description = "Whether to create a Windows VM in the VPC for browser-based access to Confluent Cloud"
  type        = bool
  default     = false
}

variable "windows_admin_username" {
  description = "Admin username for the Windows VM"
  type        = string
  default     = "confluent_admin"
}

variable "windows_admin_password" {
  description = "Admin password for the Windows VM (must meet Windows complexity requirements: 14+ chars, uppercase, lowercase, number, special char)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "enable_egress_endpoint" {
  description = "Whether to create GCP egress Private Service Connect endpoint for accessing Google Cloud APIs"
  type        = bool
  default     = true
}

