#!/usr/bin/env bash
# =============================================================================
# GCP Pub/Sub Connector - Credentials Setup Script
# =============================================================================
# This script automates the creation of a GCP service account with the
# necessary permissions for Confluent Cloud to read from Google Pub/Sub.
#
# Usage:
#   ./setup-pubsub-credentials.sh [GCP_PROJECT_ID]
#
# Example:
#   ./setup-pubsub-credentials.sh solutionsarchitect-01
#
# Prerequisites:
#   - gcloud CLI installed and authenticated
#   - Permissions to create service accounts in the GCP project
#   - Pub/Sub API enabled in the project
# =============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Service account details
SA_NAME="confluent-pubsub-connector"
SA_DISPLAY_NAME="Confluent Pub/Sub Connector"
SA_DESCRIPTION="Service account for Confluent Cloud to read from GCP Pub/Sub"
CREDENTIALS_FILE="./gcp-credentials/confluent-pubsub-credentials.json"
CREDENTIALS_BASE64_FILE="./gcp-credentials/confluent-pubsub-credentials.base64"

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------

print_header() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo "  $1"
}

# -----------------------------------------------------------------------------
# Main Script
# -----------------------------------------------------------------------------

print_header "GCP Pub/Sub Connector - Credentials Setup"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI is not installed"
    echo "  Please install it from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi
print_success "gcloud CLI is installed"

# Get GCP project ID
if [ -z "$1" ]; then
    # Try to get from gcloud config
    GCP_PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
    if [ -z "$GCP_PROJECT_ID" ]; then
        print_error "No GCP project specified"
        echo "Usage: $0 [GCP_PROJECT_ID]"
        echo "Or set default project: gcloud config set project YOUR_PROJECT_ID"
        exit 1
    fi
    print_info "Using default project: $GCP_PROJECT_ID"
else
    GCP_PROJECT_ID="$1"
    print_info "Using project: $GCP_PROJECT_ID"
fi

# Check if project exists and user has access
if ! gcloud projects describe "$GCP_PROJECT_ID" &>/dev/null; then
    print_error "Cannot access project: $GCP_PROJECT_ID"
    echo "  Make sure:"
    echo "  1. The project exists"
    echo "  2. You have access to it"
    echo "  3. You're authenticated: gcloud auth login"
    exit 1
fi
print_success "Project exists and is accessible"

# Create credentials directory if it doesn't exist
mkdir -p ./gcp-credentials
print_success "Created credentials directory"

# -----------------------------------------------------------------------------
# Step 1: Create Service Account
# -----------------------------------------------------------------------------

print_header "Step 1: Create Service Account"

SA_EMAIL="${SA_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

# Check if service account already exists
if gcloud iam service-accounts describe "$SA_EMAIL" --project="$GCP_PROJECT_ID" &>/dev/null; then
    print_warning "Service account already exists: $SA_EMAIL"
    read -p "Do you want to continue and use the existing service account? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Aborted by user"
        exit 1
    fi
else
    print_info "Creating service account: $SA_EMAIL"
    gcloud iam service-accounts create "$SA_NAME" \
        --display-name="$SA_DISPLAY_NAME" \
        --description="$SA_DESCRIPTION" \
        --project="$GCP_PROJECT_ID"
    print_success "Service account created"
fi

# -----------------------------------------------------------------------------
# Step 2: Grant Permissions
# -----------------------------------------------------------------------------

print_header "Step 2: Grant Permissions"

print_info "Granting Pub/Sub Subscriber role..."
gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/pubsub.subscriber" \
    --condition=None \
    > /dev/null
print_success "Granted Pub/Sub Subscriber role"

print_info "Granting Pub/Sub Viewer role..."
gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/pubsub.viewer" \
    --condition=None \
    > /dev/null
print_success "Granted Pub/Sub Viewer role"

# -----------------------------------------------------------------------------
# Step 3: Create and Download Credentials
# -----------------------------------------------------------------------------

print_header "Step 3: Create Credentials Key"

print_info "Creating service account key..."
gcloud iam service-accounts keys create "$CREDENTIALS_FILE" \
    --iam-account="$SA_EMAIL" \
    --project="$GCP_PROJECT_ID"
print_success "Credentials saved to: $CREDENTIALS_FILE"

# Base64 encode the credentials
print_info "Encoding credentials to base64..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    base64 -i "$CREDENTIALS_FILE" -o "$CREDENTIALS_BASE64_FILE"
else
    # Linux
    base64 -w 0 "$CREDENTIALS_FILE" > "$CREDENTIALS_BASE64_FILE"
fi
print_success "Base64 credentials saved to: $CREDENTIALS_BASE64_FILE"

# -----------------------------------------------------------------------------
# Step 4: Update env.sh
# -----------------------------------------------------------------------------

print_header "Step 4: Configure Terraform Variables"

BASE64_CONTENT=$(cat "$CREDENTIALS_BASE64_FILE")

cat <<EOF

Add these lines to your env.sh file:

# GCP Pub/Sub Connector Configuration
export TF_VAR_create_pubsub_connector=true
export TF_VAR_pubsub_project_id="$GCP_PROJECT_ID"
export TF_VAR_pubsub_subscription="YOUR_SUBSCRIPTION_NAME"  # e.g., "test-subscription"
export TF_VAR_pubsub_kafka_topic="pubsub-messages"
export TF_VAR_gcp_pubsub_credentials_base64="$BASE64_CONTENT"

EOF

# Ask if user wants to append to env.sh automatically
if [ -f "./env.sh" ]; then
    read -p "Do you want to append these variables to env.sh automatically? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cat <<EOF >> ./env.sh

# =============================================================================
# GCP Pub/Sub Connector Configuration (added by setup-pubsub-credentials.sh)
# =============================================================================
export TF_VAR_create_pubsub_connector=true
export TF_VAR_pubsub_project_id="$GCP_PROJECT_ID"
export TF_VAR_pubsub_subscription="YOUR_SUBSCRIPTION_NAME"  # CHANGE THIS!
export TF_VAR_pubsub_kafka_topic="pubsub-messages"
export TF_VAR_gcp_pubsub_credentials_base64="$BASE64_CONTENT"

EOF
        print_success "Variables appended to env.sh"
        print_warning "IMPORTANT: Edit env.sh and set TF_VAR_pubsub_subscription to your actual subscription name!"
    fi
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

print_header "Setup Complete!"

echo "✓ Service Account:   $SA_EMAIL"
echo "✓ Credentials File:  $CREDENTIALS_FILE"
echo "✓ Base64 File:       $CREDENTIALS_BASE64_FILE"
echo ""
echo "Next Steps:"
echo "1. Edit env.sh and set TF_VAR_pubsub_subscription to your Pub/Sub subscription name"
echo "2. (Optional) Create a test Pub/Sub topic and subscription:"
echo "   gcloud pubsub topics create test-topic --project=$GCP_PROJECT_ID"
echo "   gcloud pubsub subscriptions create test-subscription --topic=test-topic --project=$GCP_PROJECT_ID"
echo "3. Load the environment variables:"
echo "   source env.sh"
echo "4. Deploy the connector:"
echo "   terraform plan"
echo "   terraform apply"
echo ""
echo "For more information, see: PUBSUB-CONNECTOR-SETUP.md"
echo ""

print_warning "SECURITY: Keep $CREDENTIALS_FILE secure and never commit it to Git!"
print_info "The credentials are already in .gitignore (gcp-credentials/)"
