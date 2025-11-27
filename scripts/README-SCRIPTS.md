# 🚀 Mac Pro → K3s: Skrypty instalacyjne

**Cel:** Automatyczna, powtarzalna instalacja 9× Mac Pro jako K3s nodes  
**Tryb:** Offline-ready (minimalne wymagania internetowe)  
**Czas:** ~10 minut per node (po przygotowaniu)

---

## 📋 Przegląd skryptów

### 1. **mac-pro-ubuntu-installer.sh** (GŁÓWNY)
**Purpose:** Uniwersalny instalator dla wszystkich 9 nodów  
**Usage:** `sudo ./mac-pro-ubuntu-installer.sh <node-number>`  
**Features:**
- ✅ Pre-flight checks (hardware, OS, disk space)
- ✅ Wykrywanie 2× 10Gbps interfaces (automatyczne)
- ✅ Bonding configuration (active-backup)
- ✅ Static IP assignment (VLAN 110)
- ✅ Hostname configuration
- ✅ K3s preparation (swap off, kernel modules, sysctl)
- ✅ Firewall disable (UFW → NetworkPolicies)
- ✅ GRUB priority (Ubuntu default)
- ✅ Comprehensive verification
- ✅ Detailed report generation
- ✅ **Offline-ready** (wszystkie checki bez netu)

**Example:**
```bash
# Node 1 (k3s-master-01):
sudo ./mac-pro-ubuntu-installer.sh 1

# Node 5 (k3s-worker-02):
sudo ./mac-pro-ubuntu-installer.sh 5
```

**Output:**
- Hostname: `k3s-master-01` (lub worker-XX)
- IP: `192.168.10.11` (masters: .11-.13, workers: .14-.19)
- Network: `bond0` (2× 10Gbps active-backup)
- Report: `/root/k3s-node-1-config.txt`

---

### 2. **test-network.sh**
**Purpose:** Test bonding & connectivity (offline-safe)  
**Usage:** `sudo ./test-network.sh`  
**Tests:**
- bond0 interface exists & state UP
- IP address assigned
- Bonding status (mode, active slave)
- Default route configured
- DNS configuration
- Gateway reachability (skip if offline)
- Internet connectivity (skip if offline)
- DNS resolution (skip if offline)
- Link speed (10 Gbps verification)
- MTU size

**Example output:**
```
[PASS] bond0 exists and is UP
[PASS] IP Address: 192.168.10.11
[PASS] Bonding Mode: fault-tolerance (active-backup)
[PASS] Active Interface: en0
[WARN] Internet unreachable (expected offline)

TEST SUMMARY
  PASSED:   8
  FAILED:   0
  WARNINGS: 2

✓ ALL CRITICAL TESTS PASSED
Network is ready for K3s installation.
```

---

### 3. **check-system.sh**
**Purpose:** Comprehensive readiness check (offline-ready)  
**Usage:** `sudo ./check-system.sh`  
**Categories:**
- System information (OS, kernel, arch)
- Hardware resources (CPU, RAM, disk)
- Network configuration (bond0, IP, routes)
- K3s requirements (swap, modules, sysctl)
- Required packages
- Storage (filesystem, iSCSI, NFS)
- Dual-boot verification
- Connectivity tests (offline-safe)

**Example output:**
```
[CRITICAL] Architecture... ✓ aarch64
[CRITICAL] CPU Cores... ✓ 24
[WARNING] RAM (GB)... ⚠ 189 (expected: 192)
[CRITICAL] bond0 exists... ✓ YES
[CRITICAL] SWAP disabled... ✓ 0
[CRITICAL] IP forwarding... ✓ 1

SUMMARY
  CRITICAL PASS:  15
  CRITICAL FAIL:  0
  WARNINGS:       3
  INFO:           8

✓ SYSTEM READY FOR K3S INSTALLATION
```

---

### 4. **batch-install.sh**
**Purpose:** Deploy all 9 nodes automatycznie  
**Usage:** `./batch-install.sh`  
**Prerequisites:**
- Wszystkie Mac Pro mają Ubuntu 24.04 (dual-boot)
- SSH enabled (admin user)
- Temporary DHCP IPs (edytuj w skrypcie)

**Configuration (edit first!):**
```bash
declare -A TEMP_IPS=(
    [1]="192.168.1.101"  # CHANGE: Current DHCP IP of k3s-master-01
    [2]="192.168.1.102"  # CHANGE: Current DHCP IP of k3s-master-02
    # ... etc
)
```

**Workflow:**
1. Test SSH connectivity to all nodes
2. Copy `mac-pro-ubuntu-installer.sh` to each node
3. Execute installer (node 1, 2, 3, ...)
4. Wait for reboot
5. Verify new IP (192.168.10.11+)
6. Move to next node

**Timeline:**
- Per node: ~10 minutes (install + reboot + verify)
- All 9 nodes: ~90 minutes total

---

### 5. **download-packages.sh**
**Purpose:** Download packages dla offline installation  
**Usage:** `./download-packages.sh` (run on machine WITH internet)  
**Downloads:**
- K3s binary (arm64)
- K3s airgap images (arm64)
- Ubuntu packages (curl, vim, htop, nfs-common, etc.)
- Dependencies (recursive)

**Output:** `k3s-offline-packages-arm64.tar.gz` (~2-4 GB)

**Transfer to offline machines:**
```bash
# From download machine:
scp k3s-offline-packages-arm64.tar.gz admin@192.168.10.11:~/

# On target machine:
tar xzf k3s-offline-packages-arm64.tar.gz
cd k3s-offline-packages
sudo ./install-offline.sh
```

---

## 🎯 Workflow: Od zera do K3s

### Phase 1: Przygotowanie (1 godzina, z internetem)

```bash
# 1. Pobierz pakiety offline (na laptopie z internetem):
cd scripts
./download-packages.sh
# Output: k3s-offline-packages-arm64.tar.gz

# 2. Transfer na USB drive lub NAS
cp k3s-offline-packages-arm64.tar.gz /mnt/usb/

# 3. Sprawdź czy masz SSH key
[[ -f ~/.ssh/id_ed25519 ]] && echo "OK" || ssh-keygen -t ed25519

# 4. Zbierz MAC addresses (opcjonalnie, później):
# (na każdym Mac Pro: ifconfig en0 | grep ether)
```

---

### Phase 2: Instalacja pojedynczego noda (10 minut, offline OK)

**Na Mac Pro (lokalnie lub SSH):**

```bash
# 1. Copy installer script (jeśli nie masz)
# scp mac-pro-ubuntu-installer.sh admin@<temp-ip>:/tmp/

# 2. Run installer
sudo ./mac-pro-ubuntu-installer.sh 1  # Node 1 (k3s-master-01)

# Skrypt pyta:
# - Potwierdzenie konfiguracji (hostname, IP, network)
# - Wybór interfejsów (auto-detect lub manual)
# - Aplikacja konfiguracji sieciowej (WARNING: przerywa SSH!)

# 3. Pre-flight checks (automatyczne)
# 4. Network detection (automatyczne)
# 5. Configuration (automatyczne):
#    - Hostname → k3s-master-01
#    - Network → bond0 (2× 10Gbps)
#    - Static IP → 192.168.10.11
#    - SWAP → off
#    - Kernel modules → loaded
#    - Sysctl → configured
#    - UFW → disabled
#    - GRUB → Ubuntu default

# 6. Verification (automatyczne)
# 7. Report → /root/k3s-node-1-config.txt

# 8. Reboot (optional, zalecane)
sudo reboot
```

**Po reboot:**

```bash
# Sprawdź network:
sudo ./test-network.sh

# Sprawdź system:
sudo ./check-system.sh

# Jeśli wszystko OK → gotowy do K3s!
```

---

### Phase 3: Batch installation (90 minut, offline OK after prep)

**Na laptopie (z SSH access do wszystkich Mac Pro):**

```bash
# 1. Edytuj batch-install.sh (temporary IPs)
nano batch-install.sh
# Wpisz aktualne DHCP IPs dla wszystkich 9 nodów

# 2. Run batch installer
./batch-install.sh

# Skrypt:
# - Testuje SSH do każdego noda
# - Kopiuje mac-pro-ubuntu-installer.sh
# - Wykonuje instalację (node 1 → 2 → 3 → ...)
# - Czeka na reboot
# - Weryfikuje nowy IP (192.168.10.11+)
# - Przechodzi do następnego

# Timeline: ~90 minut dla 9 nodów
```

---

### Phase 4: Verification (15 minut)

```bash
# Test SSH connectivity do wszystkich nodów
for ip in 192.168.10.{11..19}; do
    echo -n "$ip: "
    ssh -o ConnectTimeout=2 admin@$ip "hostname" || echo "FAIL"
done

# Output:
# 192.168.10.11: k3s-master-01
# 192.168.10.12: k3s-master-02
# ...
# 192.168.10.19: k3s-worker-06

# Run system check na wszystkich nodach
for ip in 192.168.10.{11..19}; do
    echo "=== $ip ==="
    ssh admin@$ip "sudo /tmp/check-system.sh" | grep "SYSTEM READY"
done

# Sprawdź bonding status
for ip in 192.168.10.{11..19}; do
    echo "=== $ip ==="
    ssh admin@$ip "cat /proc/net/bonding/bond0 | grep -E 'Mode|Active'"
done
```

---

### Phase 5: K3s Installation (30 minut)

**Masters (HA etcd cluster):**

```bash
# Master 01 (init cluster):
ssh admin@192.168.10.11
curl -sfL https://get.k3s.io | sh -s - server \
    --cluster-init \
    --disable traefik \
    --disable servicelb \
    --write-kubeconfig-mode 644

# Get token:
sudo cat /var/lib/rancher/k3s/server/node-token
# Output: K10abc123...xyz::server:abc123

# Master 02:
ssh admin@192.168.10.12
curl -sfL https://get.k3s.io | K3S_TOKEN=<token> sh -s - server \
    --server https://192.168.10.11:6443 \
    --disable traefik \
    --disable servicelb

# Master 03:
ssh admin@192.168.10.13
curl -sfL https://get.k3s.io | K3S_TOKEN=<token> sh -s - server \
    --server https://192.168.10.11:6443 \
    --disable traefik \
    --disable servicelb
```

**Workers:**

```bash
# Workers 01-06:
for ip in 192.168.10.{14..19}; do
    ssh admin@$ip "curl -sfL https://get.k3s.io | K3S_URL=https://192.168.10.11:6443 K3S_TOKEN=<token> sh -"
done
```

**Verify cluster:**

```bash
ssh admin@192.168.10.11
sudo kubectl get nodes -o wide

# Expected output:
# NAME             STATUS   ROLES                  AGE   VERSION        INTERNAL-IP
# k3s-master-01    Ready    control-plane,master   5m    v1.28.5+k3s1   192.168.10.11
# k3s-master-02    Ready    control-plane,master   3m    v1.28.5+k3s1   192.168.10.12
# k3s-master-03    Ready    control-plane,master   2m    v1.28.5+k3s1   192.168.10.13
# k3s-worker-01    Ready    <none>                 1m    v1.28.5+k3s1   192.168.10.14
# ...
# k3s-worker-06    Ready    <none>                 30s   v1.28.5+k3s1   192.168.10.19
```

---

## 🔧 Troubleshooting

### Problem: Installer nie może wykryć interfejsów
```bash
# Manual check:
ip link show | grep "^[0-9]*: en"

# Expected: en0, en1 (lub podobne)
# If missing: check if interfaces are UP:
sudo ip link set en0 up
sudo ip link set en1 up
```

### Problem: bond0 nie startuje
```bash
# Check logs:
sudo journalctl -u systemd-networkd -n 50

# Manual test:
sudo ip link add bond0 type bond mode active-backup
sudo ip link set en0 master bond0
sudo ip link set en1 master bond0
sudo ip link set bond0 up
```

### Problem: SSH traci połączenie po netplan apply
```bash
# Expected! Network się restartuje.
# Wait 30 seconds, then SSH to new IP:
ssh admin@192.168.10.11  # (nie stary DHCP IP!)
```

### Problem: "CRITICAL FAIL" w check-system.sh
```bash
# Check specific failure:
sudo ./check-system.sh | grep "FAIL"

# Common fixes:
sudo swapoff -a                    # Disable SWAP
sudo modprobe br_netfilter         # Load kernel module
sudo sysctl -w net.ipv4.ip_forward=1  # Enable IP forwarding
```

### Problem: K3s installation fails
```bash
# Check requirements:
sudo ./check-system.sh

# Check if systemd-resolved blocks port 53:
sudo systemctl disable systemd-resolved
sudo systemctl stop systemd-resolved

# Retry K3s install
```

---

## 📊 Checklist: Installation progress

```
[ ] Phase 1: Preparation (1 hour)
    [ ] Download offline packages (download-packages.sh)
    [ ] Transfer to USB/NAS
    [ ] Generate SSH key (if needed)
    [ ] Collect MAC addresses (optional)

[ ] Phase 2: Pilot node (node 1) (30 min)
    [ ] Run mac-pro-ubuntu-installer.sh 1
    [ ] Verify with test-network.sh
    [ ] Verify with check-system.sh
    [ ] Reboot & re-test

[ ] Phase 3: Batch install (nodes 2-9) (90 min)
    [ ] Edit batch-install.sh (temporary IPs)
    [ ] Run batch-install.sh
    [ ] Monitor progress
    [ ] Verify all nodes

[ ] Phase 4: Verification (15 min)
    [ ] Test SSH to all nodes
    [ ] Run check-system.sh on all nodes
    [ ] Verify bonding status
    [ ] Test connectivity (ping all-to-all)

[ ] Phase 5: K3s installation (30 min)
    [ ] Install K3s masters (HA etcd)
    [ ] Install K3s workers
    [ ] Verify cluster (kubectl get nodes)
    [ ] Deploy MetalLB (BGP)
    [ ] Test LoadBalancer

[ ] Phase 6: Applications (ArgoCD) (30 min)
    [ ] Deploy ArgoCD
    [ ] Configure App-of-Apps
    [ ] Deploy 39 applications
    [ ] Monitor sync waves

Total time: ~4 hours (with testing & verification)
```

---

## 📞 Support & Next Steps

**Issues?**
- Check logs: `/var/log/syslog` (Ubuntu), `journalctl -xe` (systemd)
- Network: `ip addr show`, `ip route show`, `cat /proc/net/bonding/bond0`
- K3s: `sudo systemctl status k3s`, `sudo journalctl -u k3s -n 100`

**Next steps:**
1. **Now:** Install nodes using scripts above
2. **After K3s:** MetalLB BGP configuration (see `K8S-CLUSTER-ARCHITECTURE.md`)
3. **After MetalLB:** Deploy applications via ArgoCD (see `zsel-eip-gitops`)
4. **After apps:** Monitoring (Prometheus, Grafana, Zabbix)

**Gotowy zacząć?** 🚀
```bash
cd scripts
chmod +x *.sh
sudo ./mac-pro-ubuntu-installer.sh 1
```
