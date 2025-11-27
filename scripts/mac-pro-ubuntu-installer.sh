#!/bin/bash
################################################################################
# Mac Pro M2 Ultra - Ubuntu 24.04 Dual-Boot Installer
# 
# Purpose: Universal installer script for K3s nodes
# Usage: sudo ./mac-pro-ubuntu-installer.sh <node-number>
# Example: sudo ./mac-pro-ubuntu-installer.sh 1  (for k3s-master-01)
#
# Offline-ready: All checks, no internet required
# Network: Manual config for 2× 10Gbps ports (bonding)
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURATION - EDIT THIS SECTION
# ============================================================================

# Network Configuration
VLAN_ID=110
NETWORK_PREFIX="192.168.10"
GATEWAY="${NETWORK_PREFIX}.1"
DNS_SERVERS="8.8.8.8,8.8.4.4"
NETMASK="24"

# Node Types (masters: 1-3, workers: 4-9)
declare -A NODE_HOSTNAMES=(
    [1]="k3s-master-01"
    [2]="k3s-master-02"
    [3]="k3s-master-03"
    [4]="k3s-worker-01"
    [5]="k3s-worker-02"
    [6]="k3s-worker-03"
    [7]="k3s-worker-04"
    [8]="k3s-worker-05"
    [9]="k3s-worker-06"
)

declare -A NODE_IPS=(
    [1]="${NETWORK_PREFIX}.11"
    [2]="${NETWORK_PREFIX}.12"
    [3]="${NETWORK_PREFIX}.13"
    [4]="${NETWORK_PREFIX}.14"
    [5]="${NETWORK_PREFIX}.15"
    [6]="${NETWORK_PREFIX}.16"
    [7]="${NETWORK_PREFIX}.17"
    [8]="${NETWORK_PREFIX}.18"
    [9]="${NETWORK_PREFIX}.19"
)

declare -A NODE_ROLES=(
    [1]="master"
    [2]="master"
    [3]="master"
    [4]="worker"
    [5]="worker"
    [6]="worker"
    [7]="worker"
    [8]="worker"
    [9]="worker"
)

# K3s preparation packages (offline-ready list)
K3S_PACKAGES=(
    "curl"
    "wget"
    "vim"
    "htop"
    "iotop"
    "sysstat"
    "net-tools"
    "bridge-utils"
    "vlan"
    "ifenslave"
    "nfs-common"
    "open-iscsi"
    "python3"
    "python3-pip"
    "git"
    "jq"
)

# ============================================================================
# COLORS & FORMATTING
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo ""
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║ $1${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                  ║"
    echo "║     Mac Pro M2 Ultra → Ubuntu 24.04 K3s Node Installer         ║"
    echo "║                                                                  ║"
    echo "║     Offline-ready | Dual-boot | 2× 10Gbps Bonding              ║"
    echo "║                                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Ten skrypt musi być uruchomiony jako root (sudo)"
        exit 1
    fi
}

check_node_number() {
    local node_num=$1
    
    if [[ ! "$node_num" =~ ^[1-9]$ ]]; then
        log_error "Nieprawidłowy numer noda. Użyj 1-9."
        echo ""
        echo "Dostępne nody:"
        for i in {1..9}; do
            echo "  $i: ${NODE_HOSTNAMES[$i]} (${NODE_IPS[$i]}) - ${NODE_ROLES[$i]}"
        done
        exit 1
    fi
}

confirm_action() {
    local node_num=$1
    local hostname=${NODE_HOSTNAMES[$node_num]}
    local ip=${NODE_IPS[$node_num]}
    local role=${NODE_ROLES[$node_num]}
    
    echo ""
    echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}${BOLD}║  POTWIERDŹ KONFIGURACJĘ NODA                                     ║${NC}"
    echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Hostname:   ${BOLD}$hostname${NC}"
    echo -e "  IP Address: ${BOLD}$ip/$NETMASK${NC}"
    echo -e "  Gateway:    ${BOLD}$GATEWAY${NC}"
    echo -e "  VLAN:       ${BOLD}$VLAN_ID${NC}"
    echo -e "  Role:       ${BOLD}$role${NC}"
    echo -e "  Network:    ${BOLD}2× 10Gbps bonding (active-backup)${NC}"
    echo ""
    echo -e "${RED}${BOLD}UWAGA: Skrypt zmieni konfigurację sieciową i hostname!${NC}"
    echo ""
    read -p "Kontynuować? [yes/NO]: " -r confirm
    
    if [[ ! "$confirm" =~ ^[Yy][Ee][Ss]$ ]]; then
        log_warning "Instalacja anulowana przez użytkownika."
        exit 0
    fi
}

# ============================================================================
# PRE-FLIGHT CHECKS
# ============================================================================

run_preflight_checks() {
    log_step "PRE-FLIGHT CHECKS"
    
    local errors=0
    local warnings=0
    
    # Check 1: OS Version
    log_info "Sprawdzam wersję OS..."
    if grep -q "Ubuntu 24.04" /etc/os-release 2>/dev/null; then
        log_success "Ubuntu 24.04 LTS wykryty"
    else
        log_warning "OS nie jest Ubuntu 24.04 LTS"
        ((warnings++))
    fi
    
    # Check 2: Architecture
    log_info "Sprawdzam architekturę..."
    if [[ "$(uname -m)" == "aarch64" ]]; then
        log_success "ARM64 architecture (Apple Silicon)"
    else
        log_error "Nieprawidłowa architektura: $(uname -m)"
        ((errors++))
    fi
    
    # Check 3: Kernel version
    log_info "Sprawdzam wersję kernela..."
    kernel_version=$(uname -r)
    log_success "Kernel: $kernel_version"
    
    # Check 4: Memory
    log_info "Sprawdzam pamięć RAM..."
    total_ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $total_ram_gb -ge 180 ]]; then
        log_success "RAM: ${total_ram_gb} GB (Mac Pro M2 Ultra)"
    else
        log_warning "RAM: ${total_ram_gb} GB (spodziewano się ~192 GB)"
        ((warnings++))
    fi
    
    # Check 5: CPU cores
    log_info "Sprawdzam CPU..."
    cpu_cores=$(nproc)
    if [[ $cpu_cores -ge 20 ]]; then
        log_success "CPU: ${cpu_cores} cores (Apple M2 Ultra)"
    else
        log_warning "CPU: ${cpu_cores} cores (spodziewano się 24)"
        ((warnings++))
    fi
    
    # Check 6: Disk space
    log_info "Sprawdzam miejsce na dysku..."
    root_avail_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $root_avail_gb -ge 1000 ]]; then
        log_success "Wolne miejsce: ${root_avail_gb} GB"
    else
        log_warning "Wolne miejsce: ${root_avail_gb} GB (zalecane min 1 TB)"
        ((warnings++))
    fi
    
    # Check 7: Dual-boot detection
    log_info "Sprawdzam dual-boot setup..."
    if lsblk | grep -q "APFS"; then
        log_success "Wykryto dual-boot (macOS partition obecny)"
    else
        log_warning "Nie wykryto macOS partition (może być OK)"
        ((warnings++))
    fi
    
    # Check 8: Network interfaces (10Gbps)
    log_info "Sprawdzam interfejsy sieciowe..."
    local iface_count=$(ip link show | grep -c "^[0-9]*: en")
    if [[ $iface_count -ge 2 ]]; then
        log_success "Wykryto $iface_count interfejsów sieciowych"
    else
        log_error "Za mało interfejsów sieciowych: $iface_count (potrzeba min 2)"
        ((errors++))
    fi
    
    # Check 9: Swap disabled
    log_info "Sprawdzam SWAP..."
    if swapon --show | grep -q "/"; then
        log_warning "SWAP jest włączony (zostanie wyłączony dla K3s)"
        ((warnings++))
    else
        log_success "SWAP wyłączony"
    fi
    
    # Check 10: Required commands
    log_info "Sprawdzam wymagane narzędzia..."
    local missing_tools=()
    for tool in ip awk sed grep systemctl; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -eq 0 ]]; then
        log_success "Wszystkie wymagane narzędzia dostępne"
    else
        log_error "Brakujące narzędzia: ${missing_tools[*]}"
        ((errors++))
    fi
    
    # Summary
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
    if [[ $errors -eq 0 && $warnings -eq 0 ]]; then
        log_success "PRE-FLIGHT CHECK: ${GREEN}PASS${NC} (0 errors, 0 warnings)"
    elif [[ $errors -eq 0 ]]; then
        log_warning "PRE-FLIGHT CHECK: ${YELLOW}PASS WITH WARNINGS${NC} (0 errors, $warnings warnings)"
    else
        log_error "PRE-FLIGHT CHECK: ${RED}FAIL${NC} ($errors errors, $warnings warnings)"
        echo ""
        echo "Napraw błędy przed kontynuacją."
        exit 1
    fi
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    sleep 2
}

# ============================================================================
# NETWORK CONFIGURATION (2× 10Gbps Bonding)
# ============================================================================

detect_network_interfaces() {
    log_step "WYKRYWANIE INTERFEJSÓW SIECIOWYCH"
    
    log_info "Skanowanie interfejsów 10Gbps..."
    
    # Get all physical Ethernet interfaces
    local interfaces=()
    while IFS= read -r line; do
        iface=$(echo "$line" | awk -F': ' '{print $2}')
        if [[ "$iface" =~ ^en ]]; then
            interfaces+=("$iface")
        fi
    done < <(ip link show | grep "^[0-9]*: en")
    
    echo ""
    echo "Wykryte interfejsy:"
    for i in "${!interfaces[@]}"; do
        local iface="${interfaces[$i]}"
        local speed="N/A"
        local state=$(ip link show "$iface" | grep -oP '(?<=state )[^ ]+')
        
        # Try to get speed (może nie działać bez kabla)
        if [[ -f "/sys/class/net/$iface/speed" ]]; then
            speed=$(cat "/sys/class/net/$iface/speed" 2>/dev/null || echo "N/A")
            [[ "$speed" != "N/A" ]] && speed="${speed} Mbps"
        fi
        
        echo "  [$((i+1))] $iface - State: $state, Speed: $speed"
    done
    echo ""
    
    # Auto-select first two interfaces
    if [[ ${#interfaces[@]} -ge 2 ]]; then
        BOND_INTERFACE1="${interfaces[0]}"
        BOND_INTERFACE2="${interfaces[1]}"
        log_success "Auto-wybrano: $BOND_INTERFACE1 + $BOND_INTERFACE2 dla bonding"
    else
        log_error "Znaleziono tylko ${#interfaces[@]} interfejs(y). Potrzeba min 2."
        exit 1
    fi
    
    # Manual override (opcjonalne)
    echo ""
    read -p "Użyć innych interfejsów? [y/N]: " -r change_ifaces
    if [[ "$change_ifaces" =~ ^[Yy]$ ]]; then
        read -p "Interface 1: " BOND_INTERFACE1
        read -p "Interface 2: " BOND_INTERFACE2
        log_info "Wybrano ręcznie: $BOND_INTERFACE1 + $BOND_INTERFACE2"
    fi
    
    echo ""
}

configure_network_bonding() {
    local node_num=$1
    local hostname=${NODE_HOSTNAMES[$node_num]}
    local ip=${NODE_IPS[$node_num]}
    
    log_step "KONFIGURACJA BONDING (2× 10Gbps)"
    
    log_info "Tworzę konfigurację netplan..."
    
    # Backup existing config
    if [[ -f /etc/netplan/00-installer-config.yaml ]]; then
        cp /etc/netplan/00-installer-config.yaml /etc/netplan/00-installer-config.yaml.backup
        log_success "Backup: /etc/netplan/00-installer-config.yaml.backup"
    fi
    
    # Create bonding config
    cat > /etc/netplan/01-k3s-bonding.yaml <<EOF
# K3s Node Network Configuration
# Node: $hostname ($ip)
# Bonding: $BOND_INTERFACE1 + $BOND_INTERFACE2 (active-backup)
# Generated: $(date)

network:
  version: 2
  renderer: networkd
  
  ethernets:
    $BOND_INTERFACE1:
      dhcp4: no
      dhcp6: no
    
    $BOND_INTERFACE2:
      dhcp4: no
      dhcp6: no
  
  bonds:
    bond0:
      interfaces:
        - $BOND_INTERFACE1
        - $BOND_INTERFACE2
      parameters:
        mode: active-backup          # Failover (jeden aktywny, drugi backup)
        primary: $BOND_INTERFACE1    # Preferowany interface
        mii-monitor-interval: 100    # Link monitoring (100ms)
        downdelay: 200               # Wait before marking down (200ms)
        updelay: 200                 # Wait before marking up (200ms)
      addresses:
        - $ip/$NETMASK
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [${DNS_SERVERS//,/, }]
EOF
    
    log_success "Konfiguracja zapisana: /etc/netplan/01-k3s-bonding.yaml"
    
    # Show config
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    cat /etc/netplan/01-k3s-bonding.yaml
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    
    # Validate syntax
    log_info "Walidacja składni netplan..."
    if netplan generate; then
        log_success "Netplan config valid"
    else
        log_error "Błąd w konfiguracji netplan!"
        exit 1
    fi
    
    # Apply (with confirmation)
    echo ""
    log_warning "Zastosowanie konfiguracji może przerwać połączenie SSH!"
    read -p "Zastosować konfigurację sieciową? [yes/NO]: " -r apply_network
    
    if [[ "$apply_network" =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Aplikuję konfigurację sieciową..."
        if netplan apply; then
            log_success "Konfiguracja sieciowa zastosowana"
            sleep 2
            
            # Verify bonding
            log_info "Weryfikacja bonding..."
            if ip link show bond0 &> /dev/null; then
                log_success "Interface bond0 utworzony"
                
                # Show bonding status
                echo ""
                cat /proc/net/bonding/bond0 2>/dev/null || log_warning "Nie można odczytać statusu bonding"
            else
                log_error "Interface bond0 nie został utworzony!"
            fi
        else
            log_error "Błąd podczas aplikacji konfiguracji!"
            log_warning "Przywracam backup..."
            cp /etc/netplan/00-installer-config.yaml.backup /etc/netplan/00-installer-config.yaml
            netplan apply
            exit 1
        fi
    else
        log_warning "Konfiguracja sieciowa pominięta (zastosuj ręcznie: netplan apply)"
    fi
    
    echo ""
}

# ============================================================================
# SYSTEM CONFIGURATION
# ============================================================================

configure_hostname() {
    local hostname=$1
    
    log_step "KONFIGURACJA HOSTNAME"
    
    log_info "Ustawiam hostname: $hostname"
    hostnamectl set-hostname "$hostname"
    
    # Update /etc/hosts
    log_info "Aktualizuję /etc/hosts..."
    sed -i '/^127.0.1.1/d' /etc/hosts
    echo "127.0.1.1 $hostname" >> /etc/hosts
    
    log_success "Hostname ustawiony: $(hostname)"
    echo ""
}

disable_swap() {
    log_step "WYŁĄCZANIE SWAP (K3s requirement)"
    
    if swapon --show | grep -q "/"; then
        log_info "Wyłączam SWAP..."
        swapoff -a
        
        log_info "Usuwam SWAP z /etc/fstab..."
        sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
        
        log_success "SWAP wyłączony permanentnie"
    else
        log_success "SWAP już wyłączony"
    fi
    
    echo ""
}

configure_kernel_modules() {
    log_step "KONFIGURACJA MODUŁÓW KERNELA (K3s requirement)"
    
    log_info "Dodaję moduły do /etc/modules-load.d/k8s.conf..."
    cat > /etc/modules-load.d/k8s.conf <<EOF
# Kubernetes required modules
overlay
br_netfilter
EOF
    
    log_info "Ładuję moduły..."
    modprobe overlay 2>/dev/null || log_warning "Moduł overlay już załadowany"
    modprobe br_netfilter 2>/dev/null || log_warning "Moduł br_netfilter już załadowany"
    
    log_success "Moduły kernela skonfigurowane"
    echo ""
}

configure_sysctl() {
    log_step "KONFIGURACJA SYSCTL (K3s requirement)"
    
    log_info "Tworzę /etc/sysctl.d/k8s.conf..."
    cat > /etc/sysctl.d/k8s.conf <<EOF
# Kubernetes sysctl configuration
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
    
    log_info "Aplikuję ustawienia sysctl..."
    sysctl --system > /dev/null
    
    # Verify
    if [[ "$(sysctl -n net.ipv4.ip_forward)" == "1" ]]; then
        log_success "IP forwarding włączone"
    else
        log_error "Błąd konfiguracji IP forwarding"
    fi
    
    echo ""
}

disable_firewall() {
    log_step "WYŁĄCZANIE UFW FIREWALL"
    
    log_info "K3s używa NetworkPolicies zamiast UFW..."
    
    if systemctl is-active --quiet ufw; then
        systemctl stop ufw
        systemctl disable ufw
        log_success "UFW wyłączony"
    else
        log_success "UFW już wyłączony"
    fi
    
    echo ""
}

install_packages() {
    log_step "INSTALACJA PAKIETÓW (OFFLINE MODE)"
    
    log_warning "Tryb offline: sprawdzam już zainstalowane pakiety..."
    
    local missing_packages=()
    for pkg in "${K3S_PACKAGES[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            missing_packages+=("$pkg")
        fi
    done
    
    if [[ ${#missing_packages[@]} -eq 0 ]]; then
        log_success "Wszystkie wymagane pakiety już zainstalowane"
    else
        log_warning "Brakujące pakiety (${#missing_packages[@]}): ${missing_packages[*]}"
        echo ""
        read -p "Spróbować zainstalować (wymaga internetu)? [y/N]: " -r install_now
        
        if [[ "$install_now" =~ ^[Yy]$ ]]; then
            log_info "Instaluję pakiety..."
            apt-get update || log_warning "apt-get update failed (offline?)"
            apt-get install -y "${missing_packages[@]}" || log_warning "Niektóre pakiety nie zostały zainstalowane"
        else
            log_warning "Instalacja pakietów pominięta. Zainstaluj później: apt install ${missing_packages[*]}"
        fi
    fi
    
    echo ""
}

configure_grub() {
    log_step "KONFIGURACJA GRUB (Dual-Boot Priority)"
    
    log_info "Sprawdzam konfigurację GRUB..."
    
    local grub_default=$(grep "^GRUB_DEFAULT=" /etc/default/grub | cut -d'=' -f2)
    local grub_timeout=$(grep "^GRUB_TIMEOUT=" /etc/default/grub | cut -d'=' -f2)
    
    log_info "Aktualna konfiguracja: DEFAULT=$grub_default, TIMEOUT=$grub_timeout"
    
    # Set Ubuntu as default (0 = first entry)
    if [[ "$grub_default" != "0" ]]; then
        log_info "Ustawiam Ubuntu jako domyślny OS..."
        sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=0/' /etc/default/grub
    fi
    
    # Set timeout to 3 seconds (fast boot)
    if [[ "$grub_timeout" != "3" ]]; then
        log_info "Ustawiam timeout GRUB na 3 sekundy..."
        sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=3/' /etc/default/grub
    fi
    
    log_info "Regeneruję konfigurację GRUB..."
    update-grub
    
    log_success "GRUB skonfigurowany: Ubuntu (default), 3s timeout"
    echo ""
}

# ============================================================================
# VERIFICATION
# ============================================================================

verify_configuration() {
    log_step "WERYFIKACJA KONFIGURACJI"
    
    local errors=0
    
    # Check 1: Hostname
    log_info "Sprawdzam hostname..."
    current_hostname=$(hostname)
    if [[ "$current_hostname" == "${NODE_HOSTNAMES[$NODE_NUM]}" ]]; then
        log_success "Hostname: $current_hostname ✓"
    else
        log_error "Hostname nieprawidłowy: $current_hostname (oczekiwano ${NODE_HOSTNAMES[$NODE_NUM]})"
        ((errors++))
    fi
    
    # Check 2: Network - Bond interface
    log_info "Sprawdzam bonding interface..."
    if ip link show bond0 &> /dev/null; then
        local bond_state=$(ip link show bond0 | grep -oP '(?<=state )[^ ]+')
        if [[ "$bond_state" == "UP" ]]; then
            log_success "bond0: UP ✓"
        else
            log_warning "bond0: $bond_state (cable disconnected?)"
        fi
    else
        log_error "bond0 nie istnieje!"
        ((errors++))
    fi
    
    # Check 3: Network - IP Address
    log_info "Sprawdzam adres IP..."
    if ip addr show bond0 2>/dev/null | grep -q "${NODE_IPS[$NODE_NUM]}"; then
        log_success "IP Address: ${NODE_IPS[$NODE_NUM]} ✓"
    else
        log_error "IP Address nieprawidłowy lub brak"
        ((errors++))
    fi
    
    # Check 4: Network - Gateway
    log_info "Sprawdzam gateway..."
    if ip route | grep -q "default via $GATEWAY"; then
        log_success "Gateway: $GATEWAY ✓"
    else
        log_error "Gateway nieprawidłowy lub brak"
        ((errors++))
    fi
    
    # Check 5: SWAP disabled
    log_info "Sprawdzam SWAP..."
    if ! swapon --show | grep -q "/"; then
        log_success "SWAP: wyłączony ✓"
    else
        log_error "SWAP: wciąż włączony!"
        ((errors++))
    fi
    
    # Check 6: Kernel modules
    log_info "Sprawdzam moduły kernela..."
    if lsmod | grep -q "br_netfilter" && lsmod | grep -q "overlay"; then
        log_success "Kernel modules: załadowane ✓"
    else
        log_error "Kernel modules: nie załadowane!"
        ((errors++))
    fi
    
    # Check 7: IP forwarding
    log_info "Sprawdzam IP forwarding..."
    if [[ "$(sysctl -n net.ipv4.ip_forward)" == "1" ]]; then
        log_success "IP forwarding: włączone ✓"
    else
        log_error "IP forwarding: wyłączone!"
        ((errors++))
    fi
    
    # Check 8: UFW
    log_info "Sprawdzam firewall..."
    if ! systemctl is-active --quiet ufw; then
        log_success "UFW: wyłączony ✓"
    else
        log_warning "UFW: wciąż aktywny"
    fi
    
    # Summary
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
    if [[ $errors -eq 0 ]]; then
        log_success "WERYFIKACJA: ${GREEN}PASS${NC} (wszystkie testy OK)"
    else
        log_error "WERYFIKACJA: ${RED}FAIL${NC} ($errors błędów)"
        echo ""
        echo "Napraw błędy przed instalacją K3s."
    fi
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ============================================================================
# FINAL REPORT
# ============================================================================

generate_report() {
    local node_num=$1
    local hostname=${NODE_HOSTNAMES[$node_num]}
    local ip=${NODE_IPS[$node_num]}
    local role=${NODE_ROLES[$node_num]}
    
    local report_file="/root/k3s-node-${node_num}-config.txt"
    
    log_step "GENEROWANIE RAPORTU"
    
    log_info "Tworzę raport: $report_file"
    
    cat > "$report_file" <<EOF
╔══════════════════════════════════════════════════════════════════╗
║  K3s Node Configuration Report                                   ║
╚══════════════════════════════════════════════════════════════════╝

Generated: $(date)
Node Number: $node_num
Hostname: $hostname
IP Address: $ip/$NETMASK
Role: $role
VLAN: $VLAN_ID

═══════════════════════════════════════════════════════════════════
NETWORK CONFIGURATION
═══════════════════════════════════════════════════════════════════

Bonding Mode: active-backup (failover)
Interface 1: $BOND_INTERFACE1
Interface 2: $BOND_INTERFACE2
Bond Interface: bond0
Gateway: $GATEWAY
DNS: $DNS_SERVERS

Netplan Config: /etc/netplan/01-k3s-bonding.yaml

Bond Status:
$(cat /proc/net/bonding/bond0 2>/dev/null || echo "N/A (bond0 not active)")

═══════════════════════════════════════════════════════════════════
SYSTEM INFORMATION
═══════════════════════════════════════════════════════════════════

OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
Kernel: $(uname -r)
Architecture: $(uname -m)
CPU Cores: $(nproc)
Memory: $(free -h | grep Mem | awk '{print $2}')
Disk: $(df -h / | tail -1 | awk '{print $2}')

═══════════════════════════════════════════════════════════════════
K3S READINESS
═══════════════════════════════════════════════════════════════════

SWAP: $(swapon --show | wc -l | awk '{if($1==0) print "Disabled ✓"; else print "Enabled ✗"}')
IP Forwarding: $(sysctl -n net.ipv4.ip_forward | awk '{if($1==1) print "Enabled ✓"; else print "Disabled ✗"}')
Kernel Modules:
  - overlay: $(lsmod | grep -q overlay && echo "Loaded ✓" || echo "Not loaded ✗")
  - br_netfilter: $(lsmod | grep -q br_netfilter && echo "Loaded ✓" || echo "Not loaded ✗")
Firewall (UFW): $(systemctl is-active ufw | awk '{if($1=="inactive") print "Disabled ✓"; else print "Active ✗"}')

═══════════════════════════════════════════════════════════════════
NEXT STEPS
═══════════════════════════════════════════════════════════════════

1. Test network connectivity:
   ping $GATEWAY
   ping 8.8.8.8

2. Test bonding failover:
   # Disconnect cable from $BOND_INTERFACE1
   # Verify bond0 switches to $BOND_INTERFACE2:
   cat /proc/net/bonding/bond0

3. SSH from remote machine:
   ssh admin@$ip

4. Install K3s:
   # For masters:
   curl -sfL https://get.k3s.io | sh -s - server \\
     --cluster-init \\
     --disable traefik \\
     --disable servicelb

   # For workers:
   curl -sfL https://get.k3s.io | K3S_URL=https://192.168.10.11:6443 \\
     K3S_TOKEN=<master-token> sh -

═══════════════════════════════════════════════════════════════════
ROLLBACK (jeśli potrzeba)
═══════════════════════════════════════════════════════════════════

1. Przywróć network config:
   sudo cp /etc/netplan/00-installer-config.yaml.backup \\
           /etc/netplan/00-installer-config.yaml
   sudo rm /etc/netplan/01-k3s-bonding.yaml
   sudo netplan apply

2. Usuń bonding interface:
   sudo ip link delete bond0

3. Przywróć hostname:
   sudo hostnamectl set-hostname old-hostname

4. Reboot:
   sudo reboot

═══════════════════════════════════════════════════════════════════
SUPPORT
═══════════════════════════════════════════════════════════════════

K3s Docs: https://docs.k3s.io/
Ubuntu Netplan: https://netplan.io/
Bonding: https://wiki.ubuntu.com/Bonding

EOF
    
    log_success "Raport zapisany: $report_file"
    
    # Display summary
    echo ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║  INSTALACJA ZAKOŃCZONA POMYŚLNIE                                ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Node:     ${GREEN}$hostname${NC} ($role)"
    echo -e "  IP:       ${GREEN}$ip${NC}"
    echo -e "  Network:  ${GREEN}bond0${NC} ($BOND_INTERFACE1 + $BOND_INTERFACE2)"
    echo -e "  Status:   ${GREEN}READY FOR K3S${NC}"
    echo ""
    echo -e "  Raport:   ${CYAN}$report_file${NC}"
    echo ""
    echo -e "${YELLOW}Następny krok: Zrebootuj maszynę (sudo reboot)${NC}"
    echo ""
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    # Parse arguments
    if [[ $# -ne 1 ]]; then
        echo "Usage: $0 <node-number>"
        echo ""
        echo "Dostępne nody (1-9):"
        for i in {1..9}; do
            echo "  $i: ${NODE_HOSTNAMES[$i]} (${NODE_IPS[$i]}) - ${NODE_ROLES[$i]}"
        done
        exit 1
    fi
    
    NODE_NUM=$1
    
    # Print banner
    print_banner
    
    # Checks
    check_root
    check_node_number "$NODE_NUM"
    confirm_action "$NODE_NUM"
    
    # Pre-flight checks
    run_preflight_checks
    
    # Network detection
    detect_network_interfaces
    
    # Configuration steps
    configure_hostname "${NODE_HOSTNAMES[$NODE_NUM]}"
    configure_network_bonding "$NODE_NUM"
    disable_swap
    configure_kernel_modules
    configure_sysctl
    disable_firewall
    install_packages
    configure_grub
    
    # Verification
    verify_configuration
    
    # Report
    generate_report "$NODE_NUM"
    
    # Done
    log_success "Instalacja zakończona!"
    echo ""
    read -p "Zrebootować teraz? [y/N]: " -r do_reboot
    if [[ "$do_reboot" =~ ^[Yy]$ ]]; then
        log_info "Rebooting..."
        sleep 2
        reboot
    else
        log_warning "Pamiętaj o reboot przed instalacją K3s!"
    fi
}

# Run main
main "$@"
