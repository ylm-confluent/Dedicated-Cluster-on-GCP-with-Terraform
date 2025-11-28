# Common Issue: Project ID Mismatch

## Problem

When creating the Pub/Sub connector, you get this error:

```
Failed
There is a connector configuration error in the following fields.
gcp.pubsub.project.id: Invalid name for Project or Subscription: 
com.google.api.gax.rpc.NotFoundException: io.grpc.StatusRuntimeException: 
NOT_FOUND: Requested project not found or user does not have access to it 
(project=solutions-architect-01). Make sure to specify the unique project 
identifier and not the Google Cloud Console display name.
```

## Root Cause

You entered the **display name** instead of the **project ID**:

❌ **Wrong (Display Name):** `solutions-architect-01` (with dash)  
✅ **Correct (Project ID):** `solutionsarchitect-01` (without dash)

## How to Find Your Actual Project ID

### Method 1: Using gcloud CLI
```bash
gcloud projects list --format="table(projectId,name)"
```

Output example:
```
PROJECT_ID              NAME
solutionsarchitect-01   Solutions Architect 01
```

### Method 2: Check Your Credentials File
```bash
cat ./gcp-credentials/confluent-pubsub-credentials.json | grep project_id
```

Should show:
```json
"project_id": "solutionsarchitect-01"
```

### Method 3: GCP Console
1. Go to https://console.cloud.google.com
2. Click the project dropdown at the top
3. Look at the **ID** column (not the Name column)

## Solution

### If Connector Already Created (Manual)

1. **Edit the connector configuration:**
   - Go to Confluent Cloud UI
   - Navigate to: Environment → Cluster → Connectors
   - Click on the failed connector
   - Click "Settings" or "Configuration"
   - Find `gcp.pubsub.project.id`
   - Change from `solutions-architect-01` to `solutionsarchitect-01`
   - Save

2. **Or delete and recreate:**
   - Delete the failed connector in Confluent Cloud UI
   - Use Terraform (recommended - see below)

### If Using Terraform (Recommended)

Your `env.sh` has been updated with the correct values:

```bash
export TF_VAR_pubsub_project_id="solutionsarchitect-01"
export TF_VAR_pubsub_subscription="ismail-test-sub"
```

Deploy with Terraform:

```bash
# Reload environment variables
source env.sh

# Apply
terraform apply
```

Terraform will use the correct project ID from the credentials file.

## Verify Configuration

Before creating the connector, verify these match:

1. **Project ID in credentials file:**
```bash
cat ./gcp-credentials/confluent-pubsub-credentials.json | jq -r .project_id
# Should output: solutionsarchitect-01
```

2. **Project ID in env.sh:**
```bash
echo $TF_VAR_pubsub_project_id
# Should output: solutionsarchitect-01
```

3. **Subscription exists:**
```bash
gcloud pubsub subscriptions describe ismail-test-sub \
    --project=solutionsarchitect-01
```

## Test End-to-End

Once the connector is fixed/recreated:

```bash
# 1. Publish a test message
gcloud pubsub topics publish ismail-test \
    --message='{"test": "hello from pubsub"}' \
    --project=solutionsarchitect-01

# 2. SSH to bastion VM
ssh -i ~/.ssh/confluent_bastion terraform@<BASTION_IP>

# 3. Consume from Kafka (should see your message)
confluent kafka topic consume pubsub-messages --from-beginning
```

## Prevention

**Always use the project ID, not the display name:**

- ✅ Use: Output from `gcloud projects list`
- ✅ Use: Value in credentials JSON file (`project_id`)
- ❌ Don't use: What you see in GCP Console header
- ❌ Don't use: Display name from project selector

## GCP Project ID vs Display Name

| What You See | Type | Use for Connector? |
|--------------|------|-------------------|
| `Solutions Architect 01` | Display Name | ❌ No |
| `solutions-architect-01` | Display Name (with dash) | ❌ No |
| `solutionsarchitect-01` | Project ID | ✅ Yes! |

The **project ID** is immutable and globally unique. The display name can be changed and may contain spaces or special characters.

## Your Specific Configuration

Based on your setup:

```bash
# Correct values for your connector:
Project ID:       solutionsarchitect-01
Topic:            ismail-test
Subscription:     ismail-test-sub
Kafka Topic:      pubsub-messages
```

## Quick Reference Card

Print this out and keep it handy:

```
┌─────────────────────────────────────────────────┐
│  GCP Pub/Sub Connector Configuration            │
├─────────────────────────────────────────────────┤
│  Project ID:      solutionsarchitect-01         │
│  (NO DASH! ^^^^^^^^^^^^^^^^^^^)                 │
│                                                  │
│  Subscription:    ismail-test-sub               │
│  Topic:           ismail-test                   │
│  Kafka Topic:     pubsub-messages               │
└─────────────────────────────────────────────────┘
```
