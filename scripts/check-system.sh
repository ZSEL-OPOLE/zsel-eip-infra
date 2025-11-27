#!/bin/bash
################################################################################
# Comprehensive System Checker (Offline)
# 
# Purpose: Verify system readiness for K3s (no internet required)
# Usage: sudo ./check-system.sh
################################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  K3s System Readiness Checker (Offline)                          ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

CRITICAL_PASS=0
CRITICAL_FAIL=0
WARNING_COUNT=0
INFO_COUNT=0

check() {
    local level=$1  # CRITICAL, WARNING, INFO
    local name=$2
    local cmd=$3
    local expected=$4
    
    echo -en "[$level] $name... "
    
    result=$(eval "$cmd" 2>/dev/null || echo "ERROR")
    
    if [[ "$result" == "$expected" ]] || [[ "$expected" == "ANY" && "$result" != "ERROR" ]]; then
        echo -e "${GREEN}✓${NC} $result"
        [[ "$level" == "CRITICAL" ]] && ((CRITICAL_PASS++))
        return 0
    else
        if [[ "$level" == "CRITICAL" ]]; then
            echo -e "${RED}✗${NC} $result (expected: $expected)"
            ((CRITICAL_FAIL++))
        elif [[ "$level" == "WARNING" ]]; then
            echo -e "${YELLOW}⚠${NC} $result (expected: $expected)"
            ((WARNING_COUNT++))
        else
            echo -e "${CYAN}ℹ${NC} $result"
            ((INFO_COUNT++))
        fi
        return 1
    fi
}

echo "═══════════════════════════════════════════════════════════════════"
echo "SYSTEM INFORMATION"
echo "═══════════════════════════════════════════════════════════════════"

check "INFO" "Hostname" "hostname" "ANY"
check "INFO" "OS Version" "grep PRETTY_NAME /etc/os-release | cut -d'\"' -f2" "ANY"
check "CRITICAL" "Architecture" "uname -m" "aarch64"
check "INFO" "Kernel Version" "uname -r" "ANY"
check "INFO" "Uptime" "uptime -p" "ANY"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "HARDWARE RESOURCES"
echo "═══════════════════════════════════════════════════════════════════"

check "CRITICAL" "CPU Cores" "nproc" "24"
check "WARNING" "RAM (GB)" "free -g | awk '/^Mem:/{print \$2}'" "192"
check "WARNING" "Disk Space (GB)" "df -BG / | awk 'NR==2 {print \$4}' | sed 's/G//'" "ANY"
check "INFO" "Load Average" "uptime | awk -F'load average:' '{print \$2}' | xargs" "ANY"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "NETWORK CONFIGURATION"
echo "═══════════════════════════════════════════════════════════════════"

check "CRITICAL" "bond0 exists" "ip link show bond0 &>/dev/null && echo YES || echo NO" "YES"
check "CRITICAL" "bond0 state" "ip link show bond0 | grep -oP '(?<=state )[^ ]+'" "UP"
check "CRITICAL" "IP assigned" "ip addr show bond0 | grep -q 'inet ' && echo YES || echo NO" "YES"
check "WARNING" "Default route" "ip route | grep -q '^default' && echo YES || echo NO" "YES"
check "INFO" "DNS configured" "[[ -f /etc/resolv.conf ]] && echo YES || echo NO" "YES"

if ip link show bond0 &>/dev/null; then
    echo ""
    echo "Bond Status:"
    echo "───────────────────────────────────────────────────────────────────"
    if [[ -f /proc/net/bonding/bond0 ]]; then
        grep -E "Bonding Mode|MII Status|Currently Active Slave" /proc/net/bonding/bond0 | sed 's/^/  /'
    else
        echo "  Cannot read bonding status"
    fi
    echo "───────────────────────────────────────────────────────────────────"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "K3S REQUIREMENTS"
echo "═══════════════════════════════════════════════════════════════════"

check "CRITICAL" "SWAP disabled" "swapon --show | wc -l" "0"
check "CRITICAL" "IP forwarding" "sysctl -n net.ipv4.ip_forward" "1"
check "CRITICAL" "br_netfilter loaded" "lsmod | grep -q br_netfilter && echo YES || echo NO" "YES"
check "CRITICAL" "overlay loaded" "lsmod | grep -q overlay && echo YES || echo NO" "YES"
check "WARNING" "UFW disabled" "systemctl is-active ufw 2>/dev/null || echo inactive" "inactive"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "REQUIRED PACKAGES"
echo "═══════════════════════════════════════════════════════════════════"

packages=(curl wget vim htop net-tools bridge-utils vlan nfs-common open-iscsi python3 git jq)
for pkg in "${packages[@]}"; do
    check "WARNING" "$pkg" "dpkg -l | grep -q \"^ii  $pkg \" && echo INSTALLED || echo MISSING" "INSTALLED"
done

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "STORAGE"
echo "═══════════════════════════════════════════════════════════════════"

check "INFO" "Filesystem type" "df -T / | awk 'NR==2 {print \$2}'" "ANY"
check "INFO" "iSCSI initiator" "[[ -f /etc/iscsi/initiatorname.iscsi ]] && echo YES || echo NO" "YES"
check "WARNING" "NFS mount support" "systemctl is-active nfs-common 2>/dev/null || echo inactive" "ANY"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "DUAL-BOOT VERIFICATION"
echo "═══════════════════════════════════════════════════════════════════"

check "INFO" "macOS partition" "lsblk | grep -q APFS && echo DETECTED || echo NOT_FOUND" "DETECTED"
check "INFO" "GRUB installed" "command -v grub-install &>/dev/null && echo YES || echo NO" "YES"
check "INFO" "GRUB default OS" "grep '^GRUB_DEFAULT=' /etc/default/grub | cut -d'=' -f2" "0"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "CONNECTIVITY TESTS (Offline-safe)"
echo "═══════════════════════════════════════════════════════════════════"

# Gateway ping (offline OK if no cable)
gateway=$(ip route | grep '^default' | awk '{print $3}')
if [[ -n "$gateway" ]]; then
    check "WARNING" "Ping gateway ($gateway)" "ping -c 1 -W 2 $gateway &>/dev/null && echo OK || echo FAIL" "OK"
else
    echo "[INFO] Gateway... ${CYAN}ℹ${NC} Not configured (OK for offline)"
fi

# Internet (offline OK)
check "INFO" "Ping Internet (8.8.8.8)" "ping -c 1 -W 2 8.8.8.8 &>/dev/null && echo OK || echo OFFLINE" "ANY"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "SUMMARY"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo -e "  ${GREEN}CRITICAL PASS:${NC}  $CRITICAL_PASS"
echo -e "  ${RED}CRITICAL FAIL:${NC}  $CRITICAL_FAIL"
echo -e "  ${YELLOW}WARNINGS:${NC}       $WARNING_COUNT"
echo -e "  ${CYAN}INFO:${NC}           $INFO_COUNT"
echo ""

if [[ $CRITICAL_FAIL -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}✓ SYSTEM READY FOR K3S INSTALLATION${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Install K3s: curl -sfL https://get.k3s.io | sh -"
    echo "  2. Or use offline installer: ./install-k3s-offline.sh"
    exit 0
else
    echo -e "${RED}${BOLD}✗ CRITICAL ISSUES FOUND${NC}"
    echo ""
    echo "Fix critical issues before installing K3s."
    exit 1
fi
