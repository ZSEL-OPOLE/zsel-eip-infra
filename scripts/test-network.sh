#!/bin/bash
################################################################################
# Network Configuration Tester
# 
# Purpose: Test network bonding and connectivity (offline)
# Usage: sudo ./test-network.sh
################################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

log_info() { echo -e "${CYAN}[TEST]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  Network Configuration & Connectivity Test                       ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

PASSED=0
FAILED=0
WARNINGS=0

# Test 1: Bond interface exists
log_info "Test 1: Sprawdzam bond0 interface..."
if ip link show bond0 &> /dev/null; then
    STATE=$(ip link show bond0 | grep -oP '(?<=state )[^ ]+')
    if [[ "$STATE" == "UP" ]]; then
        log_pass "bond0 exists and is UP"
        ((PASSED++))
    else
        log_warn "bond0 exists but is $STATE"
        ((WARNINGS++))
    fi
else
    log_fail "bond0 does not exist!"
    ((FAILED++))
fi

# Test 2: IP address assigned
log_info "Test 2: Sprawdzam adres IP..."
IP_ADDR=$(ip addr show bond0 2>/dev/null | grep -oP '(?<=inet )[0-9.]+')
if [[ -n "$IP_ADDR" ]]; then
    log_pass "IP Address: $IP_ADDR"
    ((PASSED++))
else
    log_fail "No IP address assigned to bond0"
    ((FAILED++))
fi

# Test 3: Bonding status
log_info "Test 3: Sprawdzam bonding status..."
if [[ -f /proc/net/bonding/bond0 ]]; then
    MODE=$(grep "Bonding Mode" /proc/net/bonding/bond0 | awk -F': ' '{print $2}')
    ACTIVE=$(grep "Currently Active Slave" /proc/net/bonding/bond0 | awk -F': ' '{print $2}')
    log_pass "Bonding Mode: $MODE"
    log_pass "Active Interface: $ACTIVE"
    ((PASSED+=2))
    
    echo ""
    echo "Full Bonding Status:"
    echo "═══════════════════════════════════════════════════════════════════"
    cat /proc/net/bonding/bond0
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
else
    log_fail "Cannot read bonding status"
    ((FAILED++))
fi

# Test 4: Default route
log_info "Test 4: Sprawdzam default route..."
if ip route | grep -q "^default"; then
    GATEWAY=$(ip route | grep "^default" | awk '{print $3}')
    log_pass "Default gateway: $GATEWAY"
    ((PASSED++))
else
    log_fail "No default route configured"
    ((FAILED++))
fi

# Test 5: DNS configuration
log_info "Test 5: Sprawdzam DNS..."
if [[ -f /etc/resolv.conf ]]; then
    DNS_SERVERS=$(grep "^nameserver" /etc/resolv.conf | awk '{print $2}' | tr '\n' ', ' | sed 's/,$//')
    log_pass "DNS servers: $DNS_SERVERS"
    ((PASSED++))
else
    log_fail "No DNS configuration"
    ((FAILED++))
fi

# Test 6: Ping gateway (if we have one)
if [[ -n "${GATEWAY:-}" ]]; then
    log_info "Test 6: Ping gateway ($GATEWAY)..."
    if ping -c 3 -W 2 "$GATEWAY" &> /dev/null; then
        log_pass "Gateway reachable"
        ((PASSED++))
    else
        log_fail "Gateway unreachable (cable disconnected?)"
        ((FAILED++))
    fi
else
    log_warn "Test 6: Skipped (no gateway)"
    ((WARNINGS++))
fi

# Test 7: Ping external DNS (if we have internet)
log_info "Test 7: Ping external DNS (8.8.8.8)..."
if ping -c 3 -W 2 8.8.8.8 &> /dev/null; then
    log_pass "Internet reachable"
    ((PASSED++))
else
    log_warn "Internet unreachable (expected offline)"
    ((WARNINGS++))
fi

# Test 8: DNS resolution (if we have internet)
log_info "Test 8: DNS resolution (google.com)..."
if ping -c 1 -W 2 google.com &> /dev/null; then
    log_pass "DNS resolution working"
    ((PASSED++))
else
    log_warn "DNS resolution failed (expected offline)"
    ((WARNINGS++))
fi

# Test 9: Link speed (if available)
log_info "Test 9: Sprawdzam prędkość linku..."
BOND_SLAVES=$(cat /sys/class/net/bond0/bonding/slaves 2>/dev/null)
if [[ -n "$BOND_SLAVES" ]]; then
    for slave in $BOND_SLAVES; do
        if [[ -f "/sys/class/net/$slave/speed" ]]; then
            SPEED=$(cat "/sys/class/net/$slave/speed" 2>/dev/null || echo "N/A")
            if [[ "$SPEED" == "10000" ]]; then
                log_pass "$slave: 10 Gbps"
                ((PASSED++))
            elif [[ "$SPEED" == "-1" ]] || [[ "$SPEED" == "N/A" ]]; then
                log_warn "$slave: No link (cable disconnected?)"
                ((WARNINGS++))
            else
                log_warn "$slave: ${SPEED} Mbps (expected 10000)"
                ((WARNINGS++))
            fi
        else
            log_warn "$slave: Cannot read speed"
            ((WARNINGS++))
        fi
    done
else
    log_fail "Cannot read bonding slaves"
    ((FAILED++))
fi

# Test 10: MTU size
log_info "Test 10: Sprawdzam MTU..."
if ip link show bond0 | grep -q "mtu 1500"; then
    log_pass "MTU: 1500 (standard)"
    ((PASSED++))
else
    MTU=$(ip link show bond0 | grep -oP '(?<=mtu )[0-9]+')
    log_warn "MTU: $MTU (non-standard)"
    ((WARNINGS++))
fi

# Summary
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}TEST SUMMARY${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}PASSED:${NC}   $PASSED"
echo -e "  ${RED}FAILED:${NC}   $FAILED"
echo -e "  ${YELLOW}WARNINGS:${NC} $WARNINGS"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}✓ ALL CRITICAL TESTS PASSED${NC}"
    echo ""
    echo "Network is ready for K3s installation."
    exit 0
else
    echo -e "${RED}${BOLD}✗ SOME TESTS FAILED${NC}"
    echo ""
    echo "Fix issues before proceeding with K3s installation."
    exit 1
fi
