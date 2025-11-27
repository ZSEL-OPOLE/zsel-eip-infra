#!/bin/bash
################################################################################
# Offline Package Downloader (run on machine WITH internet)
# 
# Purpose: Download all required packages for offline installation
# Usage: ./download-packages.sh
################################################################################

set -euo pipefail

DOWNLOAD_DIR="./k3s-offline-packages"
ARCH="arm64"  # Mac Pro M2 Ultra

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  K3s Offline Package Downloader                                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Create download directory
mkdir -p "$DOWNLOAD_DIR"
cd "$DOWNLOAD_DIR"

echo "[1/5] Downloading K3s binary..."
curl -sfL -o k3s https://github.com/k3s-io/k3s/releases/download/v1.28.5+k3s1/k3s-arm64
chmod +x k3s
echo "✓ K3s binary downloaded"

echo ""
echo "[2/5] Downloading K3s images..."
curl -sfL -o k3s-airgap-images-arm64.tar.gz \
    https://github.com/k3s-io/k3s/releases/download/v1.28.5+k3s1/k3s-airgap-images-arm64.tar.gz
echo "✓ K3s images downloaded"

echo ""
echo "[3/5] Downloading Ubuntu packages..."
# Create package list
cat > packages.list <<EOF
curl
wget
vim
htop
iotop
sysstat
net-tools
bridge-utils
vlan
ifenslave
nfs-common
open-iscsi
python3
python3-pip
git
jq
EOF

# Download packages with dependencies
apt-get update
apt-get download $(cat packages.list) $(apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances $(cat packages.list) | grep "^\w" | sort -u)

echo "✓ Ubuntu packages downloaded"

echo ""
echo "[4/5] Creating install script..."
cat > install-offline.sh <<'SCRIPT'
#!/bin/bash
set -euo pipefail

echo "Installing K3s offline..."

# Install .deb packages
dpkg -i *.deb || apt-get install -f -y

# Install K3s binary
install -o root -g root -m 0755 k3s /usr/local/bin/k3s

# Load K3s images
mkdir -p /var/lib/rancher/k3s/agent/images/
cp k3s-airgap-images-arm64.tar.gz /var/lib/rancher/k3s/agent/images/

echo "✓ K3s offline installation complete"
echo "Next: Run K3s installer script"
SCRIPT

chmod +x install-offline.sh
echo "✓ Install script created"

echo ""
echo "[5/5] Creating tarball..."
cd ..
tar czf k3s-offline-packages-arm64.tar.gz k3s-offline-packages/
SIZE=$(du -h k3s-offline-packages-arm64.tar.gz | awk '{print $1}')

echo "✓ Tarball created: k3s-offline-packages-arm64.tar.gz ($SIZE)"
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "DONE! Transfer file to offline machines:"
echo "  scp k3s-offline-packages-arm64.tar.gz admin@192.168.10.11:~/"
echo ""
echo "Then on target machine:"
echo "  tar xzf k3s-offline-packages-arm64.tar.gz"
echo "  cd k3s-offline-packages"
echo "  sudo ./install-offline.sh"
echo "═══════════════════════════════════════════════════════════════════"
