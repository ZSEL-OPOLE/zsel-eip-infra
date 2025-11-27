# 🎯 ACCESS-SWITCH-01 - Pełna Konfiguracja

**Model:** MikroTik CRS354-48G-4S+2Q+RM  
**Rola:** Access switch (Mac Pro 01-03 connectivity)  
**Lokalizacja:** Rack z Mac Pro 01-03

---

## 📋 ADDRESSING

### Management IP (VLAN 600)
```
Interface: vlan-600
IP Address: 192.168.255.11/28
VLAN ID: 600
Gateway: 192.168.255.1 (CORE)
DNS: 8.8.8.8, 8.8.4.4
```

### Connected Devices (VLAN 110 - Untagged)
```
ether1 → Mac Pro 01 (k3s-master-01) - 192.168.10.11
ether2 → Mac Pro 02 (k3s-master-02) - 192.168.10.12
ether3 → Mac Pro 03 (k3s-master-03) - 192.168.10.13

Each Mac Pro:
- 2× 10Gbps interfaces (bonded)
- Bond config: active-backup
- IP: Static (configured on server)
```

### Uplink to Core
```
sfp-sfpplus1 → CORE-SWITCH-01 (trunk port)
VLANs: 110 (K3s), 600 (Management) - tagged
```

---

## 🔧 COMPLETE CONFIGURATION

### STEP 1: Initial Setup (Factory Default)

**⚠️ IMPORTANT:** Configure this switch AFTER CORE is working!

**Physical Connection:**
```
[Laptop] ─── ether48 ─── [ACCESS-01]
         192.168.88.100   192.168.88.1 (factory default)
```

**Laptop Configuration:**
```powershell
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.88.100 -PrefixLength 24
```

**Access Web Interface:**
```
URL: http://192.168.88.1
User: admin
Password: <EMPTY> (press Enter)
```

---

### STEP 2: Basic System Configuration

```routeros
# ═══════════════════════════════════════════════════════════════
# SYSTEM IDENTITY & SECURITY
# ═══════════════════════════════════════════════════════════════

# Set strong password (SAME as CORE!)
/user set admin password=YourStrongPassword123!

# Set hostname
/system identity set name=access-switch-01

# Disable unnecessary services
/ip service disable telnet,ftp,www-ssl
/ip service set ssh disabled=no port=22
/ip service set winbox disabled=no port=8291

# Set timezone
/system clock set time-zone-name=Europe/Warsaw
```

---

### STEP 3: Bridge Configuration

```routeros
# ═══════════════════════════════════════════════════════════════
# BRIDGE SETUP (VLAN-aware)
# ═══════════════════════════════════════════════════════════════

# Remove default bridge if exists
/interface bridge remove [find name=bridge]

# Create VLAN-aware bridge
/interface bridge add name=bridge vlan-filtering=yes comment="Main VLAN Bridge"

# Add management port (ether48)
/interface bridge port add bridge=bridge interface=ether48 pvid=600 comment="Management Port"

# Add Mac Pro ports (K3s VLAN 110 - untagged)
/interface bridge port add bridge=bridge interface=ether1 pvid=110 comment="Mac Pro 01 - master-01"
/interface bridge port add bridge=bridge interface=ether2 pvid=110 comment="Mac Pro 02 - master-02"
/interface bridge port add bridge=bridge interface=ether3 pvid=110 comment="Mac Pro 03 - master-03"

# Add uplink to CORE (trunk - tagged VLANs)
/interface bridge port add bridge=bridge interface=sfp-sfpplus1 comment="Trunk to CORE"
```

---

### STEP 4: VLAN Configuration

```routeros
# ═══════════════════════════════════════════════════════════════
# VLAN INTERFACES
# ═══════════════════════════════════════════════════════════════

# VLAN 600 - Management
/interface vlan add name=vlan-600 vlan-id=600 interface=bridge comment="Management"

# Note: No VLAN 110 interface needed (pure L2 switching)

# ═══════════════════════════════════════════════════════════════
# BRIDGE VLAN FILTERING
# ═══════════════════════════════════════════════════════════════

# VLAN 600 - Management (tagged on trunk, untagged on ether48)
/interface bridge vlan add bridge=bridge tagged=bridge,sfp-sfpplus1 untagged=ether48 vlan-ids=600 comment="Management VLAN"

# VLAN 110 - K3s (tagged on trunk, untagged on ether1-3)
/interface bridge vlan add bridge=bridge tagged=bridge,sfp-sfpplus1 untagged=ether1,ether2,ether3 vlan-ids=110 comment="K3s VLAN"

# Enable VLAN filtering
/interface bridge set bridge vlan-filtering=yes
```

---

### STEP 5: IP Addressing

```routeros
# ═══════════════════════════════════════════════════════════════
# IP ADDRESS & DEFAULT GATEWAY
# ═══════════════════════════════════════════════════════════════

# Remove old management IP
/ip address remove [find address~"192.168.88"]

# Set management IP (VLAN 600)
/ip address add address=192.168.255.11/28 interface=vlan-600 comment="Management IP"

# Set default gateway (to CORE)
/ip route add gateway=192.168.255.1 comment="Default Gateway to CORE"

# Set DNS servers
/ip dns set servers=8.8.8.8,8.8.4.4 allow-remote-requests=no

# ═══════════════════════════════════════════════════════════════
# UPDATE LAPTOP IP
# ═══════════════════════════════════════════════════════════════

# Disconnect laptop from ether48, change IP to 192.168.255.100/28
# Set gateway: 192.168.255.1
# Reconnect to ether48
```

---

### STEP 6: NTP Configuration

```routeros
# ═══════════════════════════════════════════════════════════════
# NTP CLIENT (Time Synchronization)
# ═══════════════════════════════════════════════════════════════

/system ntp client set enabled=yes primary-ntp=pool.ntp.org secondary-ntp=time.google.com

# Verify time:
/system clock print
```

---

### STEP 7: Firewall Configuration

```routeros
# ═══════════════════════════════════════════════════════════════
# FIREWALL - INPUT CHAIN (Switch Protection)
# ═══════════════════════════════════════════════════════════════

# Accept established/related
/ip firewall filter add chain=input connection-state=established,related action=accept comment="Accept Established/Related"

# Accept ICMP (ping)
/ip firewall filter add chain=input protocol=icmp action=accept comment="Accept ICMP"

# Accept SSH from Management VLAN only
/ip firewall filter add chain=input protocol=tcp dst-port=22 src-address=192.168.255.0/28 action=accept comment="SSH from Management"

# Accept WinBox from Management VLAN only
/ip firewall filter add chain=input protocol=tcp dst-port=8291 src-address=192.168.255.0/28 action=accept comment="WinBox from Management"

# Drop invalid
/ip firewall filter add chain=input connection-state=invalid action=drop comment="Drop Invalid"

# Drop all other input
/ip firewall filter add chain=input action=drop comment="Drop Other Input"

# ═══════════════════════════════════════════════════════════════
# FORWARD CHAIN (L2 Switch - Usually Empty)
# ═══════════════════════════════════════════════════════════════

# Note: As L2 switch, forward chain is rarely needed
# All filtering happens on CORE router
```

---

### STEP 8: Advanced Security

```routeros
# ═══════════════════════════════════════════════════════════════
# SSH BRUTE-FORCE PROTECTION
# ═══════════════════════════════════════════════════════════════

/ip firewall filter add chain=input protocol=tcp dst-port=22 connection-state=new src-address-list=ssh_blacklist action=drop comment="SSH Blacklist"
/ip firewall filter add chain=input protocol=tcp dst-port=22 connection-state=new action=add-src-to-address-list address-list=ssh_stage1 address-list-timeout=1m
/ip firewall filter add chain=input protocol=tcp dst-port=22 connection-state=new src-address-list=ssh_stage1 action=add-src-to-address-list address-list=ssh_blacklist address-list-timeout=1d comment="SSH Brute-Force Protection"
```

---

### STEP 9: Monitoring

```routeros
# ═══════════════════════════════════════════════════════════════
# MONITORING SETUP
# ═══════════════════════════════════════════════════════════════

# Enable SNMP
/snmp set enabled=yes contact="admin@zsel.opole.pl" location="BCU Building - Rack with Mac Pro 01-03"
/snmp community add name=public addresses=192.168.255.0/28 read-access=yes

# Logging
/system logging add topics=system,info action=memory
/system logging add topics=critical,error,warning action=memory

# Interface monitoring
/tool graphing interface add interface=ether1 comment="Mac Pro 01"
/tool graphing interface add interface=ether2 comment="Mac Pro 02"
/tool graphing interface add interface=ether3 comment="Mac Pro 03"
/tool graphing interface add interface=sfp-sfpplus1 comment="Uplink to CORE"
```

---

### STEP 10: Physical Cable Test (Before Mac Pro Connection)

```routeros
# ═══════════════════════════════════════════════════════════════
# CABLE DIAGNOSTICS
# ═══════════════════════════════════════════════════════════════

# Test ether1-3 (Mac Pro ports):
/interface ethernet cable-test ether1
/interface ethernet cable-test ether2
/interface ethernet cable-test ether3

# Expected: status=OK, length=<cable_length>

# Test uplink:
/interface ethernet cable-test sfp-sfpplus1
# Expected: status=OK (if connected to CORE)
```

---

### STEP 11: Backup Configuration

```routeros
# ═══════════════════════════════════════════════════════════════
# BACKUP & EXPORT
# ═══════════════════════════════════════════════════════════════

/system backup save name=access-switch-01-initial
/export file=access-switch-01-config

# Download via WinBox: Files → *.backup, *.rsc
```

---

## ✅ VERIFICATION CHECKLIST

### 1. Connectivity to CORE
```routeros
/ping 192.168.255.1 count=10
# Expected: 0% packet loss
```

### 2. Internet via CORE
```routeros
/ping 8.8.8.8 count=10
/ping google.com count=10
# Expected: Working (routed via CORE)
```

### 3. VLAN Configuration
```routeros
/interface vlan print
# Expected: vlan-600 visible

/interface bridge vlan print
# Expected: VLAN 110, 600 configured
```

### 4. Bridge Ports
```routeros
/interface bridge port print
# Expected: ether1-3, ether48, sfp-sfpplus1 in bridge
```

### 5. Default Gateway
```routeros
/ip route print
# Expected: 0.0.0.0/0 gateway 192.168.255.1
```

### 6. Firewall Active
```routeros
/ip firewall filter print statistics
# Expected: Rules with counters
```

---

## 📊 PORT MAPPING

### Access Ports (VLAN 110 - K3s Untagged)
- **ether1**: Mac Pro 01 (k3s-master-01) - 192.168.10.11
- **ether2**: Mac Pro 02 (k3s-master-02) - 192.168.10.12
- **ether3**: Mac Pro 03 (k3s-master-03) - 192.168.10.13

**Note:** Each Mac Pro has 2× 10Gbps NICs bonded:
- Primary: ether1-3 (active interface)
- Backup: Connect to ACCESS-04 (redundancy)

### Management Port (VLAN 600 - Untagged)
- **ether48**: Management laptop/workstation

### Trunk Port (VLAN 110, 600 - Tagged)
- **sfp-sfpplus1**: Uplink to CORE-SWITCH-01 (10Gbps)

### Reserved Ports
- **ether4-47**: Available for expansion
- **sfp-sfpplus2-4**: Available for redundancy/expansion

---

## 🔧 TROUBLESHOOTING

### Cannot Ping CORE (192.168.255.1)
```routeros
# Check physical connection:
/interface ethernet monitor sfp-sfpplus1
# Expected: status=link-ok, rate=10Gbps

# Check VLAN:
/interface bridge vlan print
# Expected: VLAN 600 tagged on sfp-sfpplus1

# Check bridge:
/interface bridge port print
# Expected: sfp-sfpplus1 in bridge
```

### No Internet Access
```routeros
# Check default gateway:
/ip route print
# Should show: 0.0.0.0/0 gateway 192.168.255.1 reachable

# Ping gateway:
/ping 192.168.255.1

# Ping Internet:
/ping 8.8.8.8
```

### Mac Pro Not Getting Network
```routeros
# Check port status:
/interface ethernet monitor ether1

# Check VLAN assignment:
/interface bridge port print where interface=ether1
# Expected: pvid=110

# Check on CORE DHCP:
ssh admin@192.168.255.1
/ip dhcp-server lease print
# Should see Mac Pro MAC address
```

### Trunk Port Issues
```routeros
# Check SFP+ module:
/interface ethernet monitor sfp-sfpplus1
# Expected: link-ok, 10Gbps

# Check VLAN tagging:
/interface bridge vlan print where vlan-ids=110
# Expected: sfp-sfpplus1 in tagged

# Disable/enable VLAN filtering:
/interface bridge set bridge vlan-filtering=no
/interface bridge set bridge vlan-filtering=yes
```

---

## 🔌 PHYSICAL CABLING

### Mac Pro Bonding Configuration

**Each Mac Pro has 2× 10Gbps interfaces:**

```bash
# Mac Pro bonding (on Ubuntu):
bond0:
  - Primary: Connected to ACCESS-0X (this switch)
  - Backup: Connected to ACCESS-04 (redundancy switch)
  - Mode: active-backup
  - Primary slave: First detected interface
```

**Recommended Cable Setup:**
```
Mac Pro 01:
├── NIC1 (primary) → ACCESS-01 ether1
└── NIC2 (backup)  → ACCESS-04 ether1

Mac Pro 02:
├── NIC1 (primary) → ACCESS-01 ether2
└── NIC2 (backup)  → ACCESS-04 ether2

Mac Pro 03:
├── NIC1 (primary) → ACCESS-01 ether3
└── NIC2 (backup)  → ACCESS-04 ether3
```

**Verify bonding (on Mac Pro):**
```bash
cat /proc/net/bonding/bond0
# Expected: Mode: active-backup, Primary Slave: <interface>, Active Slave: <interface>
```

---

## 📋 QUICK REFERENCE

| Parameter | Value |
|-----------|-------|
| **Hostname** | access-switch-01 |
| **Management IP** | 192.168.255.11/28 (VLAN 600) |
| **Gateway** | 192.168.255.1 (CORE) |
| **Connected Devices** | Mac Pro 01-03 (K3s masters) |
| **VLAN 110 Ports** | ether1-3 (untagged) |
| **VLAN 600 Port** | ether48 (untagged) |
| **Trunk Port** | sfp-sfpplus1 (tagged 110, 600) |
| **Admin Password** | YourStrongPassword123! |

---

## 🎯 NEXT STEPS

Po ukończeniu konfiguracji ACCESS-01:

1. ✅ Test connectivity: `ping 192.168.255.1`
2. ✅ Test Internet: `ping google.com`
3. ✅ Backup config: `/system backup save`
4. ✅ **Physically disconnect from laptop!**
5. ✅ Connect sfp-sfpplus1 → CORE sfp-sfpplus1 (fiber/DAC)
6. ✅ Verify trunk: `ping 192.168.255.1` (should still work)
7. ⏸️ **DO NOT connect Mac Pro yet!** (Wait until all 5 switches ready)
8. ✅ Proceed to ACCESS-02 configuration

---

**Status:** 🟢 READY FOR MAC PRO CONNECTION (after all switches configured)  
**Last Updated:** 2025-11-27
