#!/bin/bash
################################################################################
# Batch Installer - Deploy all 9 nodes sequentially
# 
# Purpose: Automate installation on multiple Mac Pros
# Usage: ./batch-install.sh
#
# Prerequisites:
# - All Mac Pros have Ubuntu 24.04 installed (dual-boot)
# - All Mac Pros have SSH enabled
# - All Mac Pros have temporary IPs (DHCP)
################################################################################

set -euo pipefail

# Node temporary IPs (DHCP, before configuration)
declare -A TEMP_IPS=(
    [1]="192.168.1.101"  # CHANGE: Current DHCP IP of k3s-master-01
    [2]="192.168.1.102"  # CHANGE: Current DHCP IP of k3s-master-02
    [3]="192.168.1.103"  # CHANGE: Current DHCP IP of k3s-master-03
    [4]="192.168.1.104"  # CHANGE: Current DHCP IP of k3s-worker-01
    [5]="192.168.1.105"  # CHANGE: Current DHCP IP of k3s-worker-02
    [6]="192.168.1.106"  # CHANGE: Current DHCP IP of k3s-worker-03
    [7]="192.168.1.107"  # CHANGE: Current DHCP IP of k3s-worker-04
    [8]="192.168.1.108"  # CHANGE: Current DHCP IP of k3s-worker-05
    [9]="192.168.1.109"  # CHANGE: Current DHCP IP of k3s-worker-06
)

SSH_USER="admin"
SSH_KEY="$HOME/.ssh/id_ed25519"  # CHANGE if using different key

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  Batch Installer - Deploy All 9 K3s Nodes                        ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Check if installer script exists
if [[ ! -f "mac-pro-ubuntu-installer.sh" ]]; then
    echo -e "${RED}ERROR: mac-pro-ubuntu-installer.sh not found!${NC}"
    exit 1
fi

echo "Nodes to install:"
for i in {1..9}; do
    echo "  Node $i: ${TEMP_IPS[$i]}"
done
echo ""
read -p "Continue? [yes/NO]: " -r confirm
if [[ ! "$confirm" =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Install each node
for NODE_NUM in {1..9}; do
    TEMP_IP="${TEMP_IPS[$NODE_NUM]}"
    
    echo ""
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  Installing Node $NODE_NUM (temp IP: $TEMP_IP)${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Test SSH connectivity
    echo "Testing SSH connectivity..."
    if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i "$SSH_KEY" "$SSH_USER@$TEMP_IP" "echo OK" &> /dev/null; then
        echo -e "${RED}ERROR: Cannot connect to $TEMP_IP${NC}"
        echo "Skipping node $NODE_NUM..."
        continue
    fi
    echo -e "${GREEN}✓ SSH OK${NC}"
    
    # Copy installer script
    echo "Copying installer script..."
    scp -i "$SSH_KEY" mac-pro-ubuntu-installer.sh "$SSH_USER@$TEMP_IP:/tmp/"
    echo -e "${GREEN}✓ Script copied${NC}"
    
    # Run installer
    echo "Running installer (this will take 5-10 minutes)..."
    ssh -i "$SSH_KEY" "$SSH_USER@$TEMP_IP" "sudo bash /tmp/mac-pro-ubuntu-installer.sh $NODE_NUM" || {
        echo -e "${RED}ERROR: Installation failed for node $NODE_NUM${NC}"
        continue
    }
    
    echo -e "${GREEN}✓ Node $NODE_NUM configured${NC}"
    
    # Node will reboot automatically
    echo "Waiting for reboot (30 seconds)..."
    sleep 30
    
    # Wait for node to come back up (with new IP)
    NEW_IP="192.168.10.$((10 + NODE_NUM))"
    echo "Waiting for node to come back online (new IP: $NEW_IP)..."
    
    for attempt in {1..20}; do
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i "$SSH_KEY" "$SSH_USER@$NEW_IP" "echo OK" &> /dev/null; then
            echo -e "${GREEN}✓ Node $NODE_NUM is back online at $NEW_IP${NC}"
            break
        fi
        echo "  Attempt $attempt/20..."
        sleep 10
    done
    
    echo -e "${GREEN}${BOLD}✓ Node $NODE_NUM installation complete!${NC}"
done

echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║  BATCH INSTALLATION COMPLETE                                     ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "All nodes configured. Next step: Install K3s cluster."
echo ""
