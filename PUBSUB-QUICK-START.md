# Quick Reference: GCP Pub/Sub Connector Setup

## TL;DR - 5 Minute Setup

```bash
# 1. Run the automated setup script
./setup-pubsub-credentials.sh YOUR_GCP_PROJECT_ID

# 2. Edit env.sh and change YOUR_SUBSCRIPTION_NAME to your actual subscription
# The script already added the necessary variables to env.sh

# 3. Load environment variables
source env.sh

# 4. Deploy
terraform apply
```

## What You Need

### GCP Side (Pub/Sub)
- **Service Account**: Automated by `setup-pubsub-credentials.sh`
- **Permissions**: `roles/pubsub.subscriber` + `roles/pubsub.viewer` (automated)
- **Credentials JSON**: Created by the script at `./gcp-credentials/confluent-pubsub-credentials.json`
- **Pub/Sub Subscription**: You must have or create one

### Confluent Side (Kafka)
- **Environment**: Already created by main.tf
- **Kafka Cluster**: Already created by main.tf (private cluster)
- **Service Account**: Created by connectors.tf
- **Kafka Topic**: Created by connectors.tf (or manually via CLI/UI)

## Files Created

This setup adds 4 new files to your workspace:

1. **`connectors.tf`** - Terraform configuration for the Pub/Sub connector
2. **`PUBSUB-CONNECTOR-SETUP.md`** - Detailed documentation
3. **`setup-pubsub-credentials.sh`** - Automated GCP credentials setup script
4. **`THIS-FILE.md`** - Quick reference

## Environment Variables Required

Add these to `env.sh` (the script does this automatically):

```bash
export TF_VAR_create_pubsub_connector=true
export TF_VAR_pubsub_project_id="your-gcp-project-id"
export TF_VAR_pubsub_subscription="your-subscription-name"
export TF_VAR_pubsub_kafka_topic="pubsub-messages"
export TF_VAR_gcp_pubsub_credentials_base64="<base64-encoded-json>"
```

## Create Test Pub/Sub Resources

If you don't have a Pub/Sub subscription yet:

```bash
# Set your project
export GCP_PROJECT_ID="your-project-id"

# Create topic
gcloud pubsub topics create test-topic --project=$GCP_PROJECT_ID

# Create subscription
gcloud pubsub subscriptions create test-subscription \
    --topic=test-topic \
    --project=$GCP_PROJECT_ID

# Publish test message
gcloud pubsub topics publish test-topic \
    --message='{"test": "Hello from Pub/Sub"}' \
    --project=$GCP_PROJECT_ID
```

## Verify Connector is Working

### Option 1: Confluent Cloud UI
1. Login to https://confluent.cloud
2. Navigate to your environment → cluster
3. Click "Connectors" in left menu
4. Find "GcpPubSubSourceConnector"
5. Status should be "Running" (green)

### Option 2: CLI from Bastion VM
```bash
# SSH to bastion
ssh -i ~/.ssh/confluent_bastion terraform@<BASTION_IP>

# Login and select cluster
confluent login --save
confluent environment use <ENV_ID>
confluent kafka cluster use <CLUSTER_ID>

# Check connector status
confluent connect cluster list
confluent connect cluster describe <CONNECTOR_ID>

# Consume messages from Kafka topic
confluent kafka topic consume pubsub-messages --from-beginning
```

### Option 3: Check Terraform Output
```bash
terraform output pubsub_connector_info
```

## Test End-to-End Flow

```bash
# 1. Publish message to Pub/Sub
gcloud pubsub topics publish test-topic \
    --message='{"order_id": "12345", "amount": 99.99}' \
    --project=$GCP_PROJECT_ID

# 2. SSH to bastion VM
ssh -i ~/.ssh/confluent_bastion terraform@<BASTION_IP>

# 3. Consume from Kafka (should see your message)
confluent kafka topic consume pubsub-messages --from-beginning
```

## Common Issues

| Issue | Solution |
|-------|----------|
| "Permission denied" | Run `./setup-pubsub-credentials.sh` to create service account with correct roles |
| "Subscription not found" | Create subscription: `gcloud pubsub subscriptions create test-subscription --topic=test-topic` |
| "Invalid credentials" | Re-run setup script to regenerate credentials |
| Connector stuck in "Provisioning" | Check subscription name is correct in env.sh |
| No messages in Kafka | Verify messages exist in Pub/Sub subscription with `gcloud pubsub subscriptions pull` |

## Architecture

```
GCP Pub/Sub Topic
    ↓
GCP Pub/Sub Subscription
    ↓
[GCP Service Account with credentials]
    ↓
Confluent Cloud Pub/Sub Source Connector (Fully Managed)
    ↓
Confluent Kafka Topic (Private Cluster)
    ↓
Your Applications
```

## Security

✅ **DO:**
- Use the automated script `setup-pubsub-credentials.sh`
- Store credentials in env.sh (already in .gitignore)
- Rotate credentials every 90 days
- Use least privilege (only Pub/Sub Subscriber + Viewer roles)

❌ **DON'T:**
- Commit credentials to Git (already blocked by .gitignore)
- Use project Owner or Editor roles
- Share credentials via email or Slack
- Use the same credentials for multiple connectors

## Cost

- **Confluent**: ~$0.10/hour per connector task (1 task = $0.10/hour)
- **GCP Pub/Sub**: Standard Pub/Sub pricing (message ingestion + storage)
- **Data Transfer**: Standard GCP egress charges apply

## Scaling

To increase throughput, edit `connectors.tf`:

```terraform
config_nonsensitive = {
  "tasks.max" = "3"  # Increase from 1 to 3 (3x throughput)
  # ...
}
```

Then run `terraform apply`.

## Monitoring

**Confluent Cloud UI:**
- Connector status and health
- Throughput metrics (messages/sec, bytes/sec)
- Error logs
- Task assignment

**GCP Cloud Console:**
- Pub/Sub subscription backlog
- Message age
- Delivery attempts

## Next Steps

1. ✅ Set up credentials: `./setup-pubsub-credentials.sh`
2. ✅ Configure env.sh with your subscription name
3. ✅ Deploy: `terraform apply`
4. ✅ Verify connector is running
5. ✅ Test with sample message
6. 📚 Read full documentation: `PUBSUB-CONNECTOR-SETUP.md`
7. 🔒 Set up monitoring and alerting
8. 🔄 Plan credential rotation schedule

## Resources

- **Full Documentation**: [PUBSUB-CONNECTOR-SETUP.md](./PUBSUB-CONNECTOR-SETUP.md)
- **Terraform Config**: [connectors.tf](./connectors.tf)
- **Confluent Docs**: https://docs.confluent.io/cloud/current/connectors/cc-gcp-pubsub-source.html
- **GCP Pub/Sub Docs**: https://cloud.google.com/pubsub/docs
