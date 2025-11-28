#!/usr/bin/env bash
# =============================================================================
# Get GCP Pub/Sub Connector Configuration Values
# =============================================================================
# This script uses gcloud CLI to retrieve the exact values needed for your
# Confluent Cloud Pub/Sub Source Connector.
#
# Usage:
#   ./get-pubsub-config.sh
#
# Prerequisites:
#   - gcloud CLI installed and authenticated
#   - Access to the GCP project
# =============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  GCP Pub/Sub Connector - Configuration Value Retriever${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Get current project
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)

if [ -z "$CURRENT_PROJECT" ]; then
    echo -e "${YELLOW}No default project set. Please select a project:${NC}"
    gcloud projects list --format="table(projectId,name)"
    echo ""
    read -p "Enter project ID: " CURRENT_PROJECT
    gcloud config set project "$CURRENT_PROJECT"
fi

echo -e "${BLUE}Using project:${NC} $CURRENT_PROJECT"
echo ""

# =============================================================================
# 1. Get Project ID (the actual project ID, not display name)
# =============================================================================
echo -e "${GREEN}1. Project ID (use this exact value)${NC}"
echo "   ────────────────────────────────────"

PROJECT_ID=$(gcloud projects describe "$CURRENT_PROJECT" --format="value(projectId)" 2>/dev/null)

echo -e "   ${BLUE}gcp.pubsub.project.id:${NC} ${YELLOW}${PROJECT_ID}${NC}"
echo ""

# =============================================================================
# 2. List Available Pub/Sub Topics
# =============================================================================
echo -e "${GREEN}2. Available Pub/Sub Topics${NC}"
echo "   ────────────────────────────────────"

TOPICS=$(gcloud pubsub topics list --format="value(name)" 2>/dev/null | awk -F'/' '{print $NF}')

if [ -z "$TOPICS" ]; then
    echo "   ⚠ No topics found in project: $PROJECT_ID"
    echo ""
    echo "   Create a topic with:"
    echo "   gcloud pubsub topics create YOUR-TOPIC-NAME --project=$PROJECT_ID"
    echo ""
else
    echo "$TOPICS" | while read -r topic; do
        echo -e "   • ${topic}"
    done
    echo ""
fi

# =============================================================================
# 3. List Available Pub/Sub Subscriptions
# =============================================================================
echo -e "${GREEN}3. Available Pub/Sub Subscriptions${NC}"
echo "   ────────────────────────────────────"

SUBSCRIPTIONS=$(gcloud pubsub subscriptions list --format="table(name,topic)" 2>/dev/null)

if [ -z "$SUBSCRIPTIONS" ] || [ "$SUBSCRIPTIONS" = "Listed 0 items." ]; then
    echo "   ⚠ No subscriptions found in project: $PROJECT_ID"
    echo ""
    echo "   Create a subscription with:"
    echo "   gcloud pubsub subscriptions create YOUR-SUBSCRIPTION-NAME \\"
    echo "       --topic=YOUR-TOPIC-NAME \\"
    echo "       --project=$PROJECT_ID"
    echo ""
else
    # Get just the subscription names
    SUB_NAMES=$(gcloud pubsub subscriptions list --format="value(name)" 2>/dev/null | awk -F'/' '{print $NF}')
    
    echo "$SUB_NAMES" | while read -r sub; do
        # Get the topic for this subscription
        TOPIC_FULL=$(gcloud pubsub subscriptions describe "$sub" --format="value(topic)" 2>/dev/null)
        TOPIC_NAME=$(echo "$TOPIC_FULL" | awk -F'/' '{print $NF}')
        echo -e "   • ${YELLOW}${sub}${NC} → topic: ${topic_name:-$TOPIC_NAME}"
    done
    echo ""
fi

# =============================================================================
# 4. Check Service Account and Credentials
# =============================================================================
echo -e "${GREEN}4. Service Account Status${NC}"
echo "   ────────────────────────────────────"

SA_EMAIL="confluent-pubsub-connector@${PROJECT_ID}.iam.gserviceaccount.com"

if gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" &>/dev/null; then
    echo -e "   ✓ Service account exists: ${SA_EMAIL}"
    
    # Check if credentials file exists
    if [ -f "./gcp-credentials/confluent-pubsub-credentials.json" ]; then
        echo -e "   ✓ Credentials file exists: ./gcp-credentials/confluent-pubsub-credentials.json"
        
        # Verify project ID in credentials matches
        CRED_PROJECT=$(cat ./gcp-credentials/confluent-pubsub-credentials.json | grep -o '"project_id"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        
        if [ "$CRED_PROJECT" = "$PROJECT_ID" ]; then
            echo -e "   ✓ Credentials project ID matches: ${CRED_PROJECT}"
        else
            echo -e "   ⚠ WARNING: Credentials project ID (${CRED_PROJECT}) doesn't match current project (${PROJECT_ID})"
        fi
    else
        echo -e "   ⚠ Credentials file not found"
        echo "     Run: ./setup-pubsub-credentials.sh $PROJECT_ID"
    fi
else
    echo -e "   ✗ Service account NOT found: ${SA_EMAIL}"
    echo "     Run: ./setup-pubsub-credentials.sh $PROJECT_ID"
fi
echo ""

# =============================================================================
# 5. Generate Connector Configuration
# =============================================================================
echo -e "${GREEN}5. Connector Configuration (Copy/Paste Values)${NC}"
echo "   ════════════════════════════════════════════════════════"
echo ""

# Prompt for subscription if multiple exist
if [ ! -z "$SUB_NAMES" ]; then
    SUB_COUNT=$(echo "$SUB_NAMES" | wc -l | tr -d ' ')
    
    if [ "$SUB_COUNT" -gt 1 ]; then
        echo "   Select a subscription:"
        select SELECTED_SUB in $SUB_NAMES; do
            if [ -n "$SELECTED_SUB" ]; then
                break
            fi
        done
    else
        SELECTED_SUB=$(echo "$SUB_NAMES" | head -1)
    fi
    
    echo ""
    echo "   ┌─────────────────────────────────────────────────────────┐"
    echo "   │  Use these EXACT values in Confluent Cloud UI:         │"
    echo "   ├─────────────────────────────────────────────────────────┤"
    echo -e "   │  ${BLUE}GCP Pub/Sub Project ID:${NC}                              │"
    echo -e "   │    ${YELLOW}${PROJECT_ID}${NC}"
    printf "   │    %*s│\n" 53 ""
    echo -e "   │  ${BLUE}GCP Pub/Sub Subscription ID:${NC}                         │"
    echo -e "   │    ${YELLOW}${SELECTED_SUB}${NC}"
    printf "   │    %*s│\n" 53 ""
    echo -e "   │  ${BLUE}Kafka Topic:${NC}                                         │"
    echo -e "   │    ${YELLOW}pubsub-messages${NC}"
    printf "   │    %*s│\n" 53 ""
    echo "   └─────────────────────────────────────────────────────────┘"
    echo ""
    
    # Generate env.sh snippet
    echo -e "${GREEN}6. For Terraform (add to env.sh):${NC}"
    echo "   ════════════════════════════════════════════════════════"
    echo ""
    echo "   export TF_VAR_create_pubsub_connector=true"
    echo "   export TF_VAR_pubsub_project_id=\"${PROJECT_ID}\""
    echo "   export TF_VAR_pubsub_subscription=\"${SELECTED_SUB}\""
    echo "   export TF_VAR_pubsub_kafka_topic=\"pubsub-messages\""
    echo ""
    
    # Ask if user wants to update env.sh
    if [ -f "./env.sh" ]; then
        read -p "   Update env.sh with these values? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Check if pubsub config already exists in env.sh
            if grep -q "TF_VAR_pubsub_subscription" env.sh; then
                # Update existing values
                sed -i.bak "s/export TF_VAR_pubsub_subscription=.*/export TF_VAR_pubsub_subscription=\"${SELECTED_SUB}\"/" env.sh
                echo -e "   ${GREEN}✓${NC} Updated env.sh with subscription: ${SELECTED_SUB}"
            else
                echo "   ⚠ Pub/Sub config not found in env.sh. Please add manually or run setup-pubsub-credentials.sh first."
            fi
        fi
    fi
    
else
    echo "   ⚠ No subscriptions found. Create one first:"
    echo ""
    echo "   gcloud pubsub topics create my-topic --project=$PROJECT_ID"
    echo "   gcloud pubsub subscriptions create my-subscription \\"
    echo "       --topic=my-topic \\"
    echo "       --project=$PROJECT_ID"
    echo ""
fi

# =============================================================================
# 7. Test Command
# =============================================================================
echo ""
echo -e "${GREEN}7. Test Your Configuration${NC}"
echo "   ════════════════════════════════════════════════════════"
echo ""

if [ ! -z "$SELECTED_SUB" ]; then
    # Get the topic for the selected subscription
    TOPIC_FOR_SUB=$(gcloud pubsub subscriptions describe "$SELECTED_SUB" --format="value(topic)" 2>/dev/null | awk -F'/' '{print $NF}')
    
    echo "   # Publish a test message:"
    echo "   gcloud pubsub topics publish ${TOPIC_FOR_SUB} \\"
    echo "       --message='{\"test\": \"hello from pubsub\"}' \\"
    echo "       --project=${PROJECT_ID}"
    echo ""
    echo "   # Verify subscription receives it:"
    echo "   gcloud pubsub subscriptions pull ${SELECTED_SUB} \\"
    echo "       --limit=1 \\"
    echo "       --project=${PROJECT_ID}"
    echo ""
fi

echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
