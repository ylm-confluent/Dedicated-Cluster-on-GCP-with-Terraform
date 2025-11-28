#!/bin/bash

# Setup SSH keys for bastion VM access
echo "================================================"
echo "  Confluent Bastion VM - SSH Setup"
echo "================================================"
echo ""

SSH_KEY_PATH="$HOME/.ssh/confluent_bastion-dedicated"

# Check if SSH key already exists
if [ -f "$SSH_KEY_PATH" ]; then
    echo "✓ SSH key already exists at: $SSH_KEY_PATH"
    echo ""
    read -p "Do you want to use this existing key? (y/n): " use_existing
    if [ "$use_existing" != "y" ]; then
        echo "Please specify a different key name or remove the existing key."
        exit 1
    fi
else
    echo "Generating new SSH key pair..."
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -C "confluent-bastion-dedicated" -N ""
    echo "✓ SSH key generated successfully!"
    echo ""
fi

# Display the public key
echo "Your SSH public key:"
echo "-------------------"
cat "${SSH_KEY_PATH}.pub"
echo ""
echo "-------------------"
echo ""

# Update env.sh with the SSH public key
echo "Updating env.sh with your SSH public key..."

# Check if env.sh exists
if [ ! -f "env.sh" ]; then
    echo "Error: env.sh not found in current directory"
    exit 1
fi

# Backup env.sh
cp env.sh env.sh.backup
echo "✓ Created backup: env.sh.backup"

# Update or add SSH public key in env.sh
if grep -q "TF_VAR_ssh_public_key" env.sh; then
    # Update existing line
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|^export TF_VAR_ssh_public_key=.*|export TF_VAR_ssh_public_key=\"$(cat ${SSH_KEY_PATH}.pub)\"|" env.sh
    else
        # Linux
        sed -i "s|^export TF_VAR_ssh_public_key=.*|export TF_VAR_ssh_public_key=\"$(cat ${SSH_KEY_PATH}.pub)\"|" env.sh
    fi
    echo "✓ Updated SSH public key in env.sh"
else
    echo "Warning: TF_VAR_ssh_public_key not found in env.sh"
    echo "Please add it manually or re-source your env.sh"
fi

echo ""
echo "================================================"
echo "  Setup Complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo "  1. Load the environment variables: source env.sh"
echo "  2. Apply Terraform to create/update the VM: terraform apply"
echo "  3. SSH into the bastion VM:"
echo "     ssh -i $SSH_KEY_PATH terraform@<BASTION_IP>"
echo ""
echo "After Terraform apply, run 'terraform output bastion_vm_info' to get the bastion IP."
echo ""
