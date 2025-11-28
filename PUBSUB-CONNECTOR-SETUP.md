# Google Pub/Sub Source Connector Setup

This guide walks you through creating a fully managed Google Pub/Sub Source Connector for Confluent Cloud.

## Prerequisites

- ✅ Confluent Cloud Kafka cluster deployed (from main.tf)
- ✅ GCP project with Pub/Sub enabled
- ✅ GCP service account with Pub/Sub permissions
- ✅ Service account credentials JSON file

---

## Step 1: Create GCP Service Account for Pub/Sub

The connector needs a GCP service account with permissions to read from Pub/Sub topics.

### 1.1 Create the Service Account

```bash
# Set your GCP project
export GCP_PROJECT_ID="your-project-id"  # e.g., solutionsarchitect-01

# Create service account
gcloud iam service-accounts create confluent-pubsub-connector \
    --display-name="Confluent Pub/Sub Connector" \
    --description="Service account for Confluent Cloud to read from GCP Pub/Sub" \
    --project=${GCP_PROJECT_ID}
```

### 1.2 Grant Required Permissions

The service account needs these roles:
- **Pub/Sub Subscriber** - to read messages from subscriptions
- **Pub/Sub Viewer** - to list and describe topics/subscriptions

```bash
# Grant Pub/Sub Subscriber role
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
    --member="serviceAccount:confluent-pubsub-connector@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/pubsub.subscriber"

# Grant Pub/Sub Viewer role
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
    --member="serviceAccount:confluent-pubsub-connector@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/pubsub.viewer"
```

### 1.3 Create and Download Credentials JSON

```bash
# Create a key for the service account
gcloud iam service-accounts keys create ~/confluent-pubsub-credentials.json \
    --iam-account=confluent-pubsub-connector@${GCP_PROJECT_ID}.iam.gserviceaccount.com \
    --project=${GCP_PROJECT_ID}

# Verify the file was created
ls -lh ~/confluent-pubsub-credentials.json
cat ~/confluent-pubsub-credentials.json
```

**⚠️ IMPORTANT:** Keep this file secure! It contains credentials to access your GCP Pub/Sub.

---

## Step 2: Prepare the Credentials for Terraform

Terraform needs the credentials file content as a string. You have two options:

### Option A: Base64 Encode (Recommended)

```bash
# Base64 encode the credentials
base64 -i ~/confluent-pubsub-credentials.json > ~/confluent-pubsub-credentials.base64

# Copy to clipboard (macOS)
cat ~/confluent-pubsub-credentials.base64 | pbcopy

# Or view it
cat ~/confluent-pubsub-credentials.base64
```

Then add to `env.sh`:
```bash
export TF_VAR_gcp_pubsub_credentials_base64="<paste base64 string here>"
```

### Option B: Use File Path

```bash
# Copy to a known location
cp ~/confluent-pubsub-credentials.json ./gcp-credentials/

# Add to env.sh
export TF_VAR_gcp_pubsub_credentials_file="./gcp-credentials/confluent-pubsub-credentials.json"
```

---

## Step 3: Configure Pub/Sub Connector Variables

Edit your `env.sh` file and add these variables:

```bash
# GCP Pub/Sub Connector Configuration
export TF_VAR_create_pubsub_connector=true
export TF_VAR_pubsub_project_id="your-gcp-project-id"
export TF_VAR_pubsub_subscription="your-subscription-name"  # e.g., "my-pubsub-subscription"
export TF_VAR_pubsub_kafka_topic="pubsub-messages"  # Kafka topic to write to

# Option A: Use base64 encoded credentials (recommended)
export TF_VAR_gcp_pubsub_credentials_base64="<your-base64-credentials>"

# Option B: Use file path
# export TF_VAR_gcp_pubsub_credentials_file="./gcp-credentials/confluent-pubsub-credentials.json"
```

---

## Step 4: Create Pub/Sub Topic and Subscription (if needed)

If you don't have a Pub/Sub topic/subscription yet:

```bash
# Create a Pub/Sub topic
gcloud pubsub topics create test-topic \
    --project=${GCP_PROJECT_ID}

# Create a subscription
gcloud pubsub subscriptions create test-subscription \
    --topic=test-topic \
    --project=${GCP_PROJECT_ID}

# Publish test message
gcloud pubsub topics publish test-topic \
    --message="Hello from GCP Pub/Sub!" \
    --project=${GCP_PROJECT_ID}
```

---

## Step 5: Add Connector Terraform Configuration

Create a new file `connectors.tf`:

```terraform
# Variables for Pub/Sub Connector
variable "create_pubsub_connector" {
  description = "Whether to create the GCP Pub/Sub source connector"
  type        = bool
  default     = false
}

variable "pubsub_project_id" {
  description = "GCP Project ID where Pub/Sub topic/subscription exists"
  type        = string
  default     = ""
}

variable "pubsub_subscription" {
  description = "Name of the GCP Pub/Sub subscription to read from"
  type        = string
  default     = ""
}

variable "pubsub_kafka_topic" {
  description = "Kafka topic to write Pub/Sub messages to"
  type        = string
  default     = "pubsub-messages"
}

variable "gcp_pubsub_credentials_base64" {
  description = "Base64 encoded GCP service account credentials JSON"
  type        = string
  default     = ""
  sensitive   = true
}

variable "gcp_pubsub_credentials_file" {
  description = "Path to GCP service account credentials JSON file"
  type        = string
  default     = ""
}

# Local to handle credentials from either base64 or file
locals {
  gcp_pubsub_credentials = var.gcp_pubsub_credentials_base64 != "" ? base64decode(var.gcp_pubsub_credentials_base64) : (
    var.gcp_pubsub_credentials_file != "" ? file(var.gcp_pubsub_credentials_file) : ""
  )
}

# Service Account for Pub/Sub Connector
resource "confluent_service_account" "pubsub_connector" {
  count        = var.create_pubsub_connector ? 1 : 0
  display_name = "pubsub-connector-sa"
  description  = "Service account for GCP Pub/Sub Source Connector"
}

# API Key for Pub/Sub Connector
resource "confluent_api_key" "pubsub_connector_key" {
  count        = var.create_pubsub_connector ? 1 : 0
  display_name = "pubsub-connector-kafka-api-key"
  description  = "Kafka API Key for Pub/Sub connector"
  
  owner {
    id          = confluent_service_account.pubsub_connector[0].id
    api_version = confluent_service_account.pubsub_connector[0].api_version
    kind        = confluent_service_account.pubsub_connector[0].kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.enterprise.id
    api_version = confluent_kafka_cluster.enterprise.api_version
    kind        = confluent_kafka_cluster.enterprise.kind
    environment {
      id = confluent_environment.staging.id
    }
  }

  depends_on = [
    confluent_private_link_attachment_connection.gcp
  ]
}

# Grant DeveloperWrite role to connector service account
resource "confluent_role_binding" "pubsub_connector_write" {
  count       = var.create_pubsub_connector ? 1 : 0
  principal   = "User:${confluent_service_account.pubsub_connector[0].id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${confluent_kafka_cluster.enterprise.rbac_crn}/kafka=${confluent_kafka_cluster.enterprise.id}/topic=${var.pubsub_kafka_topic}"
}

# Create Kafka topic for Pub/Sub messages
resource "confluent_kafka_topic" "pubsub_topic" {
  count            = var.create_pubsub_connector && var.create_private_resources ? 1 : 0
  kafka_cluster_id = confluent_kafka_cluster.enterprise.id
  topic_name       = var.pubsub_kafka_topic
  partitions_count = 6
  
  rest_endpoint = confluent_kafka_cluster.enterprise.rest_endpoint
  
  credentials {
    key    = confluent_api_key.env-admin-kafka-api-key.id
    secret = confluent_api_key.env-admin-kafka-api-key.secret
  }

  lifecycle {
    prevent_destroy = false
  }
}

# GCP Pub/Sub Source Connector
resource "confluent_connector" "pubsub_source" {
  count = var.create_pubsub_connector ? 1 : 0
  
  environment {
    id = confluent_environment.staging.id
  }
  
  kafka_cluster {
    id = confluent_kafka_cluster.enterprise.id
  }

  config_sensitive = {
    "gcp.pubsub.credentials.json" = local.gcp_pubsub_credentials
    "kafka.api.key"               = confluent_api_key.pubsub_connector_key[0].id
    "kafka.api.secret"            = confluent_api_key.pubsub_connector_key[0].secret
  }

  config_nonsensitive = {
    "connector.class"          = "PubSubSource"
    "name"                     = "GcpPubSubSourceConnector"
    "kafka.auth.mode"          = "KAFKA_API_KEY"
    "gcp.pubsub.project.id"    = var.pubsub_project_id
    "gcp.pubsub.subscription"  = var.pubsub_subscription
    "kafka.topic"              = var.pubsub_kafka_topic
    "tasks.max"                = "1"
    
    # Message format settings
    "gcp.pubsub.message.format" = "JSON"
    
    # Optional: Configure message attributes
    # "gcp.pubsub.message.attributes.enabled" = "true"
  }

  depends_on = [
    confluent_role_binding.pubsub_connector_write,
    confluent_api_key.pubsub_connector_key
  ]
}
```

---

## Step 6: Deploy the Connector

```bash
# Load environment variables
source env.sh

# Plan the changes
terraform plan

# Apply the changes
terraform apply
```

---

## Step 7: Verify the Connector

### Check Connector Status in Confluent Cloud UI

1. Navigate to your environment → cluster → Connectors
2. Find "GcpPubSubSourceConnector"
3. Status should be "Running"
4. Check for any errors in the logs

### Check via CLI (from Bastion VM)

```bash
# SSH to bastion
ssh -i ~/.ssh/confluent_bastion terraform@<BASTION_IP>

# Login to Confluent Cloud
confluent login --save

# Use your environment
confluent environment use <ENV_ID>

# Use your cluster
confluent kafka cluster use <CLUSTER_ID>

# List connectors
confluent connect cluster list

# Describe the connector
confluent connect cluster describe <CONNECTOR_ID>

# Check connector status
confluent connect cluster status <CONNECTOR_ID>
```

### Verify Messages Are Flowing

```bash
# Consume from the Kafka topic (from bastion VM)
confluent kafka topic consume pubsub-messages --from-beginning

# Or publish a test message to Pub/Sub
gcloud pubsub topics publish test-topic \
    --message='{"test": "message from pubsub"}' \
    --project=${GCP_PROJECT_ID}

# Check if it appears in Kafka topic
```

---

## Troubleshooting

### Issue: Connector fails with "Permission Denied"

**Solution:** Verify service account has correct roles:
```bash
# Check IAM policy
gcloud projects get-iam-policy ${GCP_PROJECT_ID} \
    --flatten="bindings[].members" \
    --filter="bindings.members:serviceAccount:confluent-pubsub-connector@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
```

### Issue: "Invalid credentials" error

**Solution:** Regenerate credentials file:
```bash
# Delete old key
gcloud iam service-accounts keys list \
    --iam-account=confluent-pubsub-connector@${GCP_PROJECT_ID}.iam.gserviceaccount.com

# Create new key
gcloud iam service-accounts keys create ~/confluent-pubsub-credentials-new.json \
    --iam-account=confluent-pubsub-connector@${GCP_PROJECT_ID}.iam.gserviceaccount.com
```

### Issue: Connector stuck in "Provisioning" state

**Solution:** Check connector configuration:
```bash
# View connector config
confluent connect cluster describe <CONNECTOR_ID> --output json

# Check for configuration errors
# Verify subscription name is correct
gcloud pubsub subscriptions list --project=${GCP_PROJECT_ID}
```

### Issue: Messages not appearing in Kafka

**Solution:** 
1. Verify subscription has messages:
```bash
gcloud pubsub subscriptions pull test-subscription --limit=5 --project=${GCP_PROJECT_ID}
```

2. Check connector throughput:
```bash
confluent connect cluster status <CONNECTOR_ID>
```

3. Check Kafka topic exists:
```bash
confluent kafka topic list
confluent kafka topic describe pubsub-messages
```

---

## Credentials JSON File Format

Your `confluent-pubsub-credentials.json` file should look like this:

```json
{
  "type": "service_account",
  "project_id": "your-project-id",
  "private_key_id": "abc123...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "confluent-pubsub-connector@your-project-id.iam.gserviceaccount.com",
  "client_id": "123456789",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/..."
}
```

---

## Security Best Practices

1. **Never commit credentials to Git:**
   ```bash
   # Add to .gitignore
   echo "gcp-credentials/" >> .gitignore
   echo "*.json" >> .gitignore
   echo "*.base64" >> .gitignore
   ```

2. **Rotate credentials regularly:**
   ```bash
   # Create new key
   gcloud iam service-accounts keys create ~/new-credentials.json \
       --iam-account=confluent-pubsub-connector@${GCP_PROJECT_ID}.iam.gserviceaccount.com
   
   # Delete old key
   gcloud iam service-accounts keys delete <OLD_KEY_ID> \
       --iam-account=confluent-pubsub-connector@${GCP_PROJECT_ID}.iam.gserviceaccount.com
   ```

3. **Use least privilege:**
   - Only grant `roles/pubsub.subscriber` and `roles/pubsub.viewer`
   - Don't use project owner or editor roles

4. **Store credentials securely:**
   - Use GCP Secret Manager
   - Use Terraform Cloud variables (marked as sensitive)
   - Use environment variables (not committed to Git)

---

## Advanced Configuration Options

### Multiple Subscriptions

To read from multiple Pub/Sub subscriptions, create multiple connector resources:

```terraform
resource "confluent_connector" "pubsub_source_2" {
  # ... similar config but different subscription
  config_nonsensitive = {
    "name"                    = "GcpPubSubSourceConnector2"
    "gcp.pubsub.subscription" = "another-subscription"
    "kafka.topic"             = "pubsub-messages-2"
    # ...
  }
}
```

### Message Format Options

The connector supports different message formats:

- **JSON** (default): Parses Pub/Sub message data as JSON
- **AVRO**: Parses Pub/Sub message data as Avro
- **PROTOBUF**: Parses Pub/Sub message data as Protobuf
- **BYTES**: Treats message data as raw bytes

### Scaling

To increase throughput, increase `tasks.max`:

```terraform
config_nonsensitive = {
  "tasks.max" = "3"  # Increase parallelism
  # ...
}
```

---

## Cost Considerations

- **Connector Tasks:** Each connector task counts toward your Confluent Cloud connector capacity
- **Pub/Sub Subscription:** Standard Pub/Sub pricing applies
- **Data Transfer:** Consider GCP egress costs if Confluent Cloud is in a different region

---

## References

- [Confluent GCP Pub/Sub Source Connector Docs](https://docs.confluent.io/cloud/current/connectors/cc-gcp-pubsub-source.html)
- [GCP Pub/Sub IAM Roles](https://cloud.google.com/pubsub/docs/access-control)
- [GCP Service Account Keys](https://cloud.google.com/iam/docs/creating-managing-service-account-keys)
