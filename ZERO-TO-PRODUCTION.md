# 🚀 ZERO TO PRODUCTION - Fast Track Deployment

**Sytuacja:** 57× nowych switchy MikroTik + 9× Mac Pro (fabrycznie nowe)  
**Cel:** Działająca infrastruktura K3s w **5-7 dni**  
**Strategia:** Automatyzacja maksymalna, etapowe wdrożenie

---

## 📊 REALITY CHECK

### Co masz (FACTORY NEW):
```
Hardware:
├── 57× MikroTik switches (CRS/CCR - FACTORY DEFAULT)
├── 9× Mac Pro M2 Ultra (macOS - FACTORY DEFAULT)
├── 2× cAP access points (FACTORY DEFAULT)
└── 1× router uplink (ISP connection)

Stan początkowy:
├── IP: 192.168.88.1 (wszystkie switche - MikroTik default!)
├── User: admin / Password: <EMPTY> (factory default)
├── Config: NONE (pristine devices)
└── Network: FLAT (brak VLANs, brak routing)
```

### Problem z PFU 2.7:
- ⚠️ Dokumentacja zakłada **istniejącą** infrastrukturę (pracownie, WiFi, CCTV)
- ⚠️ Wymaga 15 pracowni (VLAN 208-246) - **NIE MASZ**
- ⚠️ Wymaga QoS dla dydaktyki - **NIE POTRZEBA NA START**
- ⚠️ 57 switchy to overkill dla 9 serwerów

### Co naprawdę potrzebujesz TERAZ:
```
Phase 1 (START - 5-7 dni):
├── 1× Router/Core switch (CCR lub CRS z routing)
├── 4× Access switches (dla 9× Mac Pro + uplinks)
├── VLAN 110 (K3s cluster - 9 nodes)
├── VLAN 600 (Management - switche)
└── BGP (MetalLB LoadBalancer)

Phase 2 (PÓŹNIEJ - gdy będziesz gotowy):
├── 53× pozostałe switche (dla pracowni)
├── VLANs 208-246 (pracownie)
├── WiFi dla studentów (VLAN 300-303)
├── CCTV (VLAN 501)
└── Full QoS policies
```

---

## ⚡ FAST TRACK PLAN (5-7 DNI)

### 🎯 STRATEGIA: Network First, Servers Second

**Kluczowy princip:** 
1. ✅ **NAJPIERW:** Sieć w pełni działająca (Internet, routing, security, VLANs)
2. ✅ **POTEM:** Podłączenie serwerów do gotowej sieci
3. ✅ **DLACZEGO:** Serwery potrzebują działającej sieci (DHCP, Internet, routing)

---

### 🎯 Timeline Overview:

```
═══════════════════════════════════════════════════════════════
PHASE 1: NETWORK INFRASTRUCTURE (3 dni)
═══════════════════════════════════════════════════════════════

Day 1: Initial Setup + Core Switch (6-8 godzin)
├── [2h] Fizyczne podłączenie core switch
├── [1h] Zmiana default IP + password
├── [1h] Internet uplink (ISP connection)
├── [2h] Basic routing + NAT (wyjście na świat!)
├── [1h] Firewall rules (podstawowe zabezpieczenia)
└── [1h] Test: ping google.com z core switch

Day 2: VLANs + Access Switches (8-10 godzin)
├── [2h] Configure 4× access switches (sequential, IP change)
├── [2h] VLAN 110 (K3s cluster) - FULL CONFIG
├── [2h] VLAN 600 (Management) - FULL CONFIG
├── [1h] Trunk ports (core ↔ access switches)
├── [1h] Access ports (dla Mac Pro - przygotowane porty)
├── [1h] BGP setup (AS 65000, peers ready)
└── [1h] Verification: VLANs UP, routing OK, Internet accessible

Day 3: Security + Advanced Routing (6-8 godzin)
├── [2h] Firewall rules (inter-VLAN, Internet access control)
├── [2h] QoS policies (basic - priorytet dla K3s traffic)
├── [1h] DHCP servers (VLAN 110 ready dla serwerów)
├── [1h] DNS forwarding (8.8.8.8, 8.8.4.4)
├── [1h] NTP servers (time sync)
└── [1h] Full network test (bez serwerów - ping, traceroute, DNS)

🎉 CHECKPOINT: Sieć w 100% gotowa, przetestowana, bezpieczna!
   ✅ Internet działa
   ✅ Routing skonfigurowany
   ✅ VLANs gotowe
   ✅ DHCP ready dla serwerów
   ✅ Firewall + security ON
   ✅ Monitoring basic (SNMP/Zabbix)

═══════════════════════════════════════════════════════════════
PHASE 2: SERVERS (NETWORK READY!) (2 dni)
═══════════════════════════════════════════════════════════════

Day 4: Mac Pro - Ubuntu Install (8 godzin)
├── [2h] Fizyczne podłączenie 9× Mac Pro (do access switches)
├── [2h] Pilot install (1 Mac Pro - test dual-boot + network)
│   └── Verify: DHCP lease, Internet access, DNS resolution
├── [4h] Batch install (8× pozostałych Mac Pro)
└── Checkpoint: All Mac Pro boot Ubuntu, network UP

Day 5: Node Configuration + K3s Cluster (8-10 godzin)
├── [3h] Network bonding (2× 10Gbps per node)
├── [1h] Static IPs + hostname (change z DHCP → static)
├── [1h] System checks (swap off, modules, sysctl)
├── [2h] Install K3s masters (HA etcd)
├── [2h] Install K3s workers
└── [1h] Deploy MetalLB (BGP) + test LoadBalancer

═══════════════════════════════════════════════════════════════
PHASE 3: APPLICATIONS (2 dni)
═══════════════════════════════════════════════════════════════

Day 6: Core Services (6-8 godzin)
├── [2h] Deploy ArgoCD (GitOps)
├── [2h] Deploy FreeIPA (LDAP/DNS)
├── [2h] Deploy Keycloak (SSO)
└── [2h] Deploy Prometheus/Grafana (monitoring)

Day 7: Verification & Production (4-6 godzin)
├── [2h] End-to-end testing (network + apps)
├── [1h] Documentation update
├── [1h] Backup all configs (network + K3s)
├── [1h] Disaster recovery test
└── [1h] Team training + handoff

═══════════════════════════════════════════════════════════════
TOTAL: 40-50 godzin pracy (5-7 dni roboczych)
═══════════════════════════════════════════════════════════════
```

---

## 📋 DAY 1: Core Switch + Internet (NETWORK FOUNDATION)

**Cel dnia:** Core switch działający, Internet working, podstawowy routing + security

### Problem: 57 switchy z tym samym IP (192.168.88.1)!

**Nie możesz skonfigurować wszystkich naraz - konflikt IP!**

### Strategia: Core First (Foundation)

```
PHASE 1 (Day 1):
1. Configure CORE switch (Internet + routing + security)
2. Test: ping google.com, traceroute, DNS
3. Verify: NAT working, firewall rules active
4. Backup config

PHASE 2 (Day 2):
1. Add access switches (sequential config)
2. Configure VLANs (K3s ready)
3. Test: end-to-end network (bez serwerów)

PHASE 3 (Day 4+):
1. Connect servers (network already working!)
2. DHCP assigns IPs automatically
3. Servers get Internet immediately
```

---

### Krok 1.1: Physical setup (CORE SWITCH)

**Wybierz najlepszy switch jako CORE:**
- ✅ CCR2216-1G-12XS-2XQ (jeśli masz - routing + 100G)
- ✅ CRS354-48G-4S+2Q+ (jeśli CCR brak - duża przepustowość)

**Topology:**
```
[ISP Router]
     |
     | ether1 (WAN)
     |
[CORE SWITCH] ← Laptop (ether2, 192.168.88.1)
     |
     | (później: ether3-10 = trunk do access switches)
```

---

### Krok 1.2: Configure CORE switch + INTERNET (KLUCZOWE!)

**Physical connection:**
```
[ISP Router/Modem] ─── ether1 (WAN) ─── [CORE SWITCH] ─── ether2 (LAN) ─── [Laptop]
   (Internet)                           192.168.88.1            192.168.88.100
```

**Podłącz laptop do ether2:**

```powershell
# Windows: Set static IP on laptop
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.88.100 -PrefixLength 24
```

**Connect via WinBox or browser:**
```
http://192.168.88.1
User: admin
Password: <EMPTY> (just press Enter)
```

**FULL CONFIGURATION (Copy-paste to Terminal):**

```routeros
# ═══════════════════════════════════════════════════════════════
# PART 1: BASIC SETUP
# ═══════════════════════════════════════════════════════════════

# 1. CHANGE PASSWORD (FIRST!)
/user set admin password=YourStrongPassword123!

# 2. SET HOSTNAME
/system identity set name=core-switch-01

# 3. CHANGE MANAGEMENT IP (later, after Internet working)
# /ip address remove [find interface=bridge]
# /ip address add address=192.168.255.1/24 interface=bridge comment="Core Management"

# ═══════════════════════════════════════════════════════════════
# PART 2: INTERNET CONNECTION (ISP UPLINK)
# ═══════════════════════════════════════════════════════════════

# Check ISP connection method (choose ONE):

# OPTION A: DHCP Client (most common - ISP gives you IP)
/ip dhcp-client add interface=ether1 disabled=no use-peer-dns=yes use-peer-ntp=yes comment="ISP Uplink"

# OPTION B: Static IP (if ISP gave you static IP):
# /ip address add address=<ISP_IP>/29 interface=ether1 comment="ISP Static IP"
# /ip route add gateway=<ISP_GATEWAY>
# /ip dns set servers=8.8.8.8,8.8.4.4

# ═══════════════════════════════════════════════════════════════
# PART 3: NAT (Internet Sharing)
# ═══════════════════════════════════════════════════════════════

# Enable NAT (masquerade) - wyjście na świat!
/ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade comment="Internet NAT"

# ═══════════════════════════════════════════════════════════════
# PART 4: BASIC FIREWALL (Security)
# ═══════════════════════════════════════════════════════════════

# Accept established/related connections
/ip firewall filter add chain=input connection-state=established,related action=accept comment="Accept Established"

# Accept ICMP (ping)
/ip firewall filter add chain=input protocol=icmp action=accept comment="Accept ICMP"

# Accept SSH from LAN only
/ip firewall filter add chain=input protocol=tcp dst-port=22 in-interface=bridge action=accept comment="SSH from LAN"
/ip firewall filter add chain=input protocol=tcp dst-port=8291 in-interface=bridge action=accept comment="WinBox from LAN"

# Drop everything else from WAN
/ip firewall filter add chain=input in-interface=ether1 action=drop comment="Drop WAN Input"

# Allow forwarding (LAN → Internet)
/ip firewall filter add chain=forward connection-state=established,related action=accept
/ip firewall filter add chain=forward connection-state=new in-interface=bridge action=accept comment="LAN to Internet"
/ip firewall filter add chain=forward action=drop comment="Drop Invalid"

# ═══════════════════════════════════════════════════════════════
# PART 5: DNS + NTP
# ═══════════════════════════════════════════════════════════════

# DNS Servers (if not using DHCP client's DNS)
/ip dns set servers=8.8.8.8,8.8.4.4 allow-remote-requests=yes

# NTP Client (time sync)
/system ntp client set enabled=yes primary-ntp=pool.ntp.org secondary-ntp=time.google.com

# ═══════════════════════════════════════════════════════════════
# PART 6: ENABLE SSH
# ═══════════════════════════════════════════════════════════════

/ip service set ssh disabled=no port=22
/ip service set winbox disabled=no
/ip service disable telnet,ftp,www-ssl  # Disable insecure services

# ═══════════════════════════════════════════════════════════════
# DONE! Test Internet:
# ═══════════════════════════════════════════════════════════════

/ping 8.8.8.8 count=5
/ping google.com count=5
```

**⚠️ CRITICAL TEST:**
```routeros
# Should see replies:
/ping 8.8.8.8
# 64 bytes from 8.8.8.8: icmp_seq=1 ttl=118 time=15 ms

/ping google.com
# 64 bytes from 142.250.74.46: icmp_seq=1 ttl=117 time=20 ms

# Check routing:
/ip route print
# Should have: default route via ether1 (ISP gateway)

# Check NAT:
/ip firewall nat print
# Should show: srcnat, ether1, masquerade

# Check DNS:
/ip dns cache print
# Should have: google.com resolved
```

**If ping works:** ✅ Internet configured correctly!  
**If ping fails:** Check ISP cable, DHCP client status, firewall rules

---

**⚠️ DOCUMENT THIS:**
```
Device: core-switch-01
Management IP: 192.168.88.1 (change to 192.168.255.1 on Day 2)
Password: YourStrongPassword123!
WAN Interface: ether1 (ISP uplink)
LAN Interface: bridge (internal network)
Status: Internet WORKING ✅
```

---

### Krok 1.3: Configure ACCESS switches (4 sztuki)

**Repeat for each access switch (one at a time!):**

```powershell
# 1. Podłącz TYLKO JEDEN switch do laptop
# 2. Laptop IP: 192.168.88.100

# 3. Connect via browser: http://192.168.88.1
# User: admin, Password: <EMPTY>

# 4. Change config:
```

**Switch 1 (access-01):**
```routeros
/user set admin password=YourStrongPassword123!
/ip address remove [find interface=bridge]
/ip address add address=192.168.255.11/24 interface=bridge
/system identity set name=access-switch-01
/ip service set ssh address=192.168.255.0/24 disabled=no
```

**Switch 2 (access-02):**
```routeros
/user set admin password=YourStrongPassword123!
/ip address remove [find interface=bridge]
/ip address add address=192.168.255.12/24 interface=bridge
/system identity set name=access-switch-02
/ip service set ssh address=192.168.255.0/24 disabled=no
```

**Switch 3 (access-03):**
```routeros
/user set admin password=YourStrongPassword123!
/ip address remove [find interface=bridge]
/ip address add address=192.168.255.13/24 interface=bridge
/system identity set name=access-switch-03
/ip service set ssh address=192.168.255.0/24 disabled=no
```

**Switch 4 (access-04):**
```routeros
/user set admin password=YourStrongPassword123!
/ip address remove [find interface=bridge]
/ip address add address=192.168.255.14/24 interface=bridge
/system identity set name=access-switch-04
/ip service set ssh address=192.168.255.0/24 disabled=no
```

**⚠️ After each:** Odłącz switch, przejdź do następnego!

---

### Krok 1.4: Physical topology (5 switches)

**Po konfiguracji wszystkich 5 switchy:**

```
Podłącz topology:

[ISP] ─ ether1 ─ [CORE-01] ─┬─ ether3 ─ [ACCESS-01] ─┬─ ether1-3: Mac Pro 01-03
        (WAN)   192.168.255.1 │            192.168.255.11 │
                              │                          └─ ether48: Uplink to CORE
                              │
                              ├─ ether4 ─ [ACCESS-02] ─┬─ ether1-3: Mac Pro 04-06
                              │            192.168.255.12 │
                              │                          └─ ether48: Uplink to CORE
                              │
                              ├─ ether5 ─ [ACCESS-03] ─┬─ ether1-3: Mac Pro 07-09
                              │            192.168.255.13 │
                              │                          └─ ether48: Uplink to CORE
                              │
                              └─ ether6 ─ [ACCESS-04] ──── (reserve for future)
                                           192.168.255.14
```

---

### Krok 1.5: Verify connectivity

**Change laptop IP:**
```powershell
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.255.100 -PrefixLength 24
```

**Test all switches:**
```powershell
# Ping test:
ping 192.168.255.1   # CORE
ping 192.168.255.11  # ACCESS-01
ping 192.168.255.12  # ACCESS-02
ping 192.168.255.13  # ACCESS-03
ping 192.168.255.14  # ACCESS-04

# SSH test:
ssh admin@192.168.255.1 "/system resource print"
ssh admin@192.168.255.11 "/system resource print"
# ... repeat for all
```

**Expected:** All pings OK, all SSH working

---

### Krok 1.6: Test Internet from laptop (through core switch)

**Change laptop to use CORE as gateway:**

```powershell
# Remove old IP:
Remove-NetIPAddress -InterfaceAlias "Ethernet" -Confirm:$false

# Set new IP (with CORE as gateway):
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.88.100 -PrefixLength 24 -DefaultGateway 192.168.88.1

# Set DNS (through CORE):
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 192.168.88.1
```

**Test Internet through CORE:**
```powershell
# Ping gateway:
ping 192.168.88.1
# Should work

# Ping Internet:
ping 8.8.8.8
ping google.com
# Should work through NAT!

# DNS test:
nslookup google.com
# Should resolve
```

**If working:** 🎉 **Internet routing complete! Core switch is gateway!**

---

## 📋 DAY 2: VLANs + Access Switches (NETWORK EXPANSION)

**Cel dnia:** VLANs configured, 4× access switches added, trunk ports ready

### Krok 2.1: Change CORE management IP (to avoid conflict)

**On CORE switch:**

```routeros
# Add new management IP (VLAN 600):
/interface vlan add name=vlan-600 vlan-id=600 interface=bridge comment="Management VLAN"
/ip address add address=192.168.255.1/28 interface=vlan-600 comment="New Management IP"

# Keep old IP for now (remove later):
# /ip address remove [find address="192.168.88.1/24"]

# Update laptop IP:
# Disconnect, change to 192.168.255.100/24, reconnect to vlan-600 port
```

---

### Krok 2.2: Automated VLAN configuration script

**Na laptop (PowerShell), stwórz script:**

```powershell
# configure-core-network.ps1

$coreSwitch = "192.168.255.1"
$sshUser = "admin"
$sshPass = "YourStrongPassword123!"

# VLAN 110 (K3s Cluster)
ssh ${sshUser}@${coreSwitch} @"
/interface vlan add name=vlan-110 vlan-id=110 interface=bridge comment='K3s Cluster'
/ip address add address=192.168.10.1/24 interface=vlan-110 comment='K3s Gateway'
/ip pool add name=k3s-pool ranges=192.168.10.200-192.168.10.254
/ip dhcp-server add name=k3s-dhcp interface=vlan-110 address-pool=k3s-pool
/ip dhcp-server network add address=192.168.10.0/24 gateway=192.168.10.1 dns-server=8.8.8.8,8.8.4.4 comment='K3s Network'
"@

# VLAN 600 (Management)
ssh ${sshUser}@${coreSwitch} @"
/interface vlan add name=vlan-600 vlan-id=600 interface=bridge comment='Management'
/ip address add address=192.168.255.1/28 interface=vlan-600 comment='Management Gateway'
"@

# BGP Configuration
ssh ${sshUser}@${coreSwitch} @"
/routing bgp instance add name=main as=65000 router-id=192.168.255.1 redistribute-connected=yes
/routing bgp peer add name=k3s-master-01 instance=main remote-address=192.168.10.11 remote-as=65001 ttl=255
/routing bgp peer add name=k3s-master-02 instance=main remote-address=192.168.10.12 remote-as=65001 ttl=255
/routing bgp peer add name=k3s-master-03 instance=main remote-address=192.168.10.13 remote-as=65001 ttl=255
/routing bgp network add network=192.168.10.20/27 comment='MetalLB PROD'
/routing bgp network add network=192.168.10.101/26 comment='MetalLB DEV'
"@

# Internet NAT
ssh ${sshUser}@${coreSwitch} @"
/ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade comment='Internet NAT'
"@

Write-Host "Core network configured!" -ForegroundColor Green
```

**Run:**
```powershell
.\configure-core-network.ps1
```

---

### Krok 2.2: Configure trunk ports (to access switches)

```routeros
# On CORE switch:
/interface bridge port
set [find interface=ether3] pvid=1  # ACCESS-01
set [find interface=ether4] pvid=1  # ACCESS-02
set [find interface=ether5] pvid=1  # ACCESS-03
set [find interface=ether6] pvid=1  # ACCESS-04

# Enable VLAN filtering:
/interface bridge set bridge vlan-filtering=yes

# Add VLANs to trunk:
/interface bridge vlan
add bridge=bridge tagged=ether3,ether4,ether5,ether6,bridge vlan-ids=110,600
```

---

### Krok 2.3: Configure access switches (VLAN access ports)

**ACCESS-01 (Mac Pro 01-03):**
```routeros
ssh admin@192.168.255.11

# Ports for Mac Pros (VLAN 110):
/interface bridge port
set [find interface=ether1] pvid=110 comment="Mac Pro 01"
set [find interface=ether2] pvid=110 comment="Mac Pro 02"
set [find interface=ether3] pvid=110 comment="Mac Pro 03"

# Uplink to CORE (trunk):
set [find interface=ether48] pvid=1 comment="Uplink to CORE"

# Enable VLAN filtering:
/interface bridge set bridge vlan-filtering=yes

# VLAN membership:
/interface bridge vlan
add bridge=bridge untagged=ether1,ether2,ether3 vlan-ids=110
add bridge=bridge tagged=ether48,bridge vlan-ids=110,600
```

**Repeat for ACCESS-02, ACCESS-03:**
- ACCESS-02: ether1-3 (Mac Pro 04-06)
- ACCESS-03: ether1-3 (Mac Pro 07-09)

---

---

## 📋 DAY 3: Security + Final Network Verification

**Cel dnia:** Advanced firewall, QoS, monitoring, FULL network test (bez serwerów)

### Krok 3.1: Advanced Firewall Rules

```routeros
# On CORE switch:

# ═══════════════════════════════════════════════════════════════
# Inter-VLAN Rules
# ═══════════════════════════════════════════════════════════════

# K3s (VLAN 110) → Internet: ALLOW
/ip firewall filter add chain=forward src-address=192.168.10.0/24 out-interface=ether1 action=accept comment="K3s to Internet"

# Management (VLAN 600) → All: ALLOW
/ip firewall filter add chain=forward src-address=192.168.255.0/28 action=accept comment="Management Full Access"

# K3s → Management: DENY (security)
/ip firewall filter add chain=forward src-address=192.168.10.0/24 dst-address=192.168.255.0/28 action=drop comment="Block K3s to Management"

# ═══════════════════════════════════════════════════════════════
# Rate Limiting (DDoS protection)
# ═══════════════════════════════════════════════════════════════

/ip firewall filter add chain=input protocol=tcp dst-port=22 connection-state=new src-address-list=ssh_blacklist action=drop comment="SSH Blacklist"
/ip firewall filter add chain=input protocol=tcp dst-port=22 connection-state=new action=add-src-to-address-list address-list=ssh_stage1 address-list-timeout=1m
/ip firewall filter add chain=input protocol=tcp dst-port=22 connection-state=new src-address-list=ssh_stage1 action=add-src-to-address-list address-list=ssh_blacklist address-list-timeout=1d
```

### Krok 3.2: QoS Policies (K3s traffic priority)

```routeros
# Mark K3s traffic (VLAN 110):
/ip firewall mangle add chain=prerouting src-address=192.168.10.0/24 action=mark-packet new-packet-mark=k3s-traffic passthrough=no comment="K3s Traffic"

# Priority queue (if supported by switch):
/queue tree add name=k3s-queue parent=global packet-mark=k3s-traffic priority=2 max-limit=10G
```

### Krok 3.3: Monitoring Setup

```routeros
# Enable SNMP (for Zabbix/Prometheus):
/snmp set enabled=yes contact="admin@zsel.opole.pl" location="BCU Building"
/snmp community add name=public addresses=192.168.10.0/24 read-access=yes

# Enable logging:
/system logging add topics=firewall,info action=memory
/system logging add topics=dhcp,info action=memory

# Resource monitoring:
/tool graphing interface add interface=ether1 comment="WAN Traffic"
/tool graphing interface add interface=vlan-110 comment="K3s Traffic"
```

### Krok 3.4: Full Network Verification (NO SERVERS YET!)

**Test checklist:**

```bash
# 1. Internet connectivity:
ssh admin@192.168.255.1
/ping 8.8.8.8
/ping google.com
# ✅ Should work

# 2. VLAN 110 gateway:
/ping 192.168.10.1
# ✅ Should respond (from CORE itself)

# 3. DHCP ready (no leases yet - servers not connected):
/ip dhcp-server lease print
# Empty (OK - servers not connected yet)

# 4. BGP ready (peers down - K3s not running):
/routing bgp peer print
# ✅ Peers configured, state: disabled (OK - K3s not installed)

# 5. Firewall active:
/ip firewall filter print
# ✅ Rules in place

# 6. NAT working:
/ip firewall nat print statistics
# ✅ Packets counter increasing
```

**🎉 CHECKPOINT - Network 100% ready!**

```
✅ Internet: WORKING
✅ Routing: CONFIGURED
✅ VLANs: READY (110, 600)
✅ DHCP: READY (waiting for servers)
✅ BGP: CONFIGURED (waiting for MetalLB)
✅ Firewall: ACTIVE
✅ Security: ENABLED
✅ QoS: CONFIGURED
✅ Monitoring: ENABLED

🚀 READY dla podłączenia serwerów!
```

**Backup config:**
```routeros
/export file=core-switch-final-config
# Download file via WinBox/SCP
```

---

## 📋 DAY 4: Mac Pro Setup (SERVERS TO READY NETWORK)

**Cel dnia:** 9× Mac Pro podłączone do GOTOWEJ SIECI, Ubuntu installed, network working

### KRYTYCZNE: Sieć już działa, serwery się tylko podłączają!

**Simplified workflow:**

```bash
# ═══════════════════════════════════════════════════════════════
# STEP 1: Fizyczne podłączenie (30 minut)
# ═══════════════════════════════════════════════════════════════

# Podłącz 9× Mac Pro do access switches:
# - ACCESS-01: ether1-3 → Mac Pro 01-03
# - ACCESS-02: ether1-3 → Mac Pro 04-06
# - ACCESS-03: ether1-3 → Mac Pro 07-09

# Boot Mac Pro (w macOS):
# - Sprawdź czy dostają DHCP IP z VLAN 110 (192.168.10.200+)
# - Test: ping 192.168.10.1 (gateway)
# - Test: ping 8.8.8.8 (Internet through NAT!)

# ═══════════════════════════════════════════════════════════════
# STEP 2: Zbierz MAC addresses (15 minut)
# ═══════════════════════════════════════════════════════════════

# Na każdym Mac Pro (w macOS):
ifconfig en0 | grep ether
# Save to file: mac-addresses.txt

# ═══════════════════════════════════════════════════════════════
# STEP 3: Ubuntu Install (6 godzin - może być parallel)
# ═══════════════════════════════════════════════════════════════

# 1. Przygotuj USB bootable (raz):
wget https://cdimage.ubuntu.com/releases/24.04/release/ubuntu-24.04-live-server-arm64.iso
# Flash to USB (Rufus/Etcher)

# 2. Install na każdym Mac Pro:
# - Boot z USB
# - Quick install (dual-boot, accept defaults)
# - Network: Use DHCP (dostanie IP z VLAN 110 automatycznie!)
# - First boot: Check Internet (ping google.com - should work!)

# ═══════════════════════════════════════════════════════════════
# STEP 4: Verify connectivity (CRITICAL!)
# ═══════════════════════════════════════════════════════════════

# Na CORE switch - check DHCP leases:
ssh admin@192.168.255.1
/ip dhcp-server lease print

# Should see:
# ADDRESS         MAC-ADDRESS       HOST-NAME        
# 192.168.10.201  xx:xx:xx:xx:01   mac-pro-01       
# 192.168.10.202  xx:xx:xx:xx:02   mac-pro-02       
# ... (all 9 nodes)

# From each Mac Pro (Ubuntu):
ping 192.168.10.1    # Gateway - should work
ping 8.8.8.8         # Internet - should work!
ping google.com      # DNS - should work!

# ═══════════════════════════════════════════════════════════════
# STEP 5: SSH mass configuration (90 minut)
# ═══════════════════════════════════════════════════════════════

# Auto-discover DHCP IPs and configure:
for i in {1..9}; do
    # Get DHCP IP from CORE:
    TEMP_IP=$(ssh admin@192.168.255.1 "/ip dhcp-server lease print" | grep -E "192.168.10.20[0-9]" | awk "NR==$i {print \$1}")
    
    echo "Configuring Node $i at $TEMP_IP..."
    
    # Transfer installer:
    scp scripts/mac-pro-ubuntu-installer.sh admin@$TEMP_IP:/tmp/
    
    # Run installer (will change to static IP):
    ssh admin@$TEMP_IP "sudo /tmp/mac-pro-ubuntu-installer.sh $i"
    
    echo "✓ Node $i configured (now at 192.168.10.$((10+i)))"
done
```

**Key advantage:** Network już działa, serwery dostają:
- ✅ DHCP IP automatycznie
- ✅ Internet access (through NAT)
- ✅ DNS resolution (8.8.8.8)
- ✅ Gateway routing (192.168.10.1)

**Timeline:** ~7-8 godzin (większość to Ubuntu install, można parallel)

---

## 📋 DAY 5: K3s Cluster (Fast Install)

### One-liner install script:

```bash
#!/bin/bash
# install-k3s-cluster.sh

# Masters (HA):
ssh admin@192.168.10.11 "curl -sfL https://get.k3s.io | sh -s - server --cluster-init --disable traefik --disable servicelb"
sleep 60
TOKEN=$(ssh admin@192.168.10.11 "sudo cat /var/lib/rancher/k3s/server/node-token")

ssh admin@192.168.10.12 "curl -sfL https://get.k3s.io | K3S_TOKEN=$TOKEN sh -s - server --server https://192.168.10.11:6443 --disable traefik --disable servicelb"
ssh admin@192.168.10.13 "curl -sfL https://get.k3s.io | K3S_TOKEN=$TOKEN sh -s - server --server https://192.168.10.11:6443 --disable traefik --disable servicelb"

# Workers (parallel):
for ip in 192.168.10.{14..19}; do
    ssh admin@$ip "curl -sfL https://get.k3s.io | K3S_URL=https://192.168.10.11:6443 K3S_TOKEN=$TOKEN sh -" &
done
wait

echo "K3s cluster installed!"
```

**Timeline:** 30 minut

---

## 📋 Pozostałe 52 switche - CO Z NIMI?

### Strategia: Staged rollout

**Phase 1 (DONE - Day 1-7):**
- 5 switchy (core + 4 access)
- 9 serwerów K3s
- Basic services

**Phase 2 (PÓŹNIEJ - gdy potrzeba):**
- Deploy 15 switchy (dla pracowni)
- Configure VLANs 208-246
- Deploy WiFi (4-8 switchy)
- Deploy CCTV (2-4 switchy)

**Phase 3 (PRZYSZŁOŚĆ):**
- Pozostałe ~30 switchy (reserve/expansion)

### Storage pozostałych switchy:

```
Fizycznie:
├── Pozostaw w pudełkach (factory sealed)
├── Store w suchym pomieszczeniu
└── Inventory spreadsheet (serial numbers)

Przygotowanie:
├── Gdy będziesz gotowy deploy pracowni
├── Use ansible/terraform (mass config)
└── Sequential rollout (5-10 per day)
```

---

## ✅ CHECKLIST: Fast Track

```
[ ] DAY 1: Initial Setup (4-6h)
    [ ] Configure CORE switch (192.168.255.1)
    [ ] Configure 4× ACCESS switches (.11-.14)
    [ ] Physical cabling (5 switches)
    [ ] Verify connectivity (ping all)
    [ ] Store remaining 52 switches

[ ] DAY 2: Core Network (6-8h)
    [ ] VLAN 110 (K3s cluster)
    [ ] VLAN 600 (Management)
    [ ] BGP configuration
    [ ] Internet routing + NAT
    [ ] Trunk ports configured
    [ ] Access ports configured
    [ ] Verify end-to-end

[ ] DAY 3: Ubuntu Install (8h)
    [ ] Prepare USB bootable
    [ ] Pilot install (1 Mac Pro)
    [ ] Batch install (8× Mac Pro)
    [ ] Verify all boots to Ubuntu

[ ] DAY 4: Node Configuration (4-6h)
    [ ] Network bonding (9 nodes)
    [ ] Static IPs assigned
    [ ] Hostnames set
    [ ] System checks passed
    [ ] Connectivity verified

[ ] DAY 5: K3s Cluster (4-6h)
    [ ] Install masters (HA etcd)
    [ ] Install workers
    [ ] Deploy MetalLB (BGP)
    [ ] Test LoadBalancer
    [ ] kubectl get nodes → all Ready

[ ] DAY 6: Core Services (6-8h)
    [ ] ArgoCD deployed
    [ ] FreeIPA deployed
    [ ] Keycloak deployed
    [ ] Prometheus/Grafana deployed
    [ ] All services healthy

[ ] DAY 7: Handoff (4h)
    [ ] End-to-end testing
    [ ] Documentation updated
    [ ] Backups created
    [ ] Team training
    [ ] Go-live decision
```

---

## 🚀 QUICK START (RIGHT NOW):

```powershell
# 1. Fizycznie podłącz 1 switch (CORE) do laptop
# 2. Laptop IP: 192.168.88.100
# 3. Browser: http://192.168.88.1
# 4. Login: admin / <EMPTY>
# 5. Follow: Krok 1.2 (configure CORE)
# 6. Repeat: Krok 1.3 (4× access switches, jeden po drugim)
# 7. Podłącz: Physical topology (Krok 1.4)
# 8. Test: Krok 1.5 (ping + SSH all switches)
```

**Pytanie:** Masz już CCR/CRS switche rozpakowane? Który model użyjesz jako CORE? 🚀
