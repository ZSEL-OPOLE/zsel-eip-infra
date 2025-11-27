# 🎯 CORE-SWITCH-01 - Pełna Konfiguracja

**Model:** MikroTik CRS354-48G-4S+2Q+RM  
**Rola:** Core router/switch (Internet gateway, routing, BGP, NAT)  
**Lokalizacja:** Rack główny

---

## 📋 ADDRESSING

### WAN Interface (ISP Uplink)
```
Interface: ether1
Mode: DHCP Client (or Static - depending on ISP)
```

### Management IP (VLAN 600)
```
Interface: vlan-600
IP Address: 192.168.255.1/28
VLAN ID: 600
Gateway: N/A (this is gateway)
DNS: 8.8.8.8, 8.8.4.4
```

### K3s Cluster Gateway (VLAN 110)
```
Interface: vlan-110
IP Address: 192.168.10.1/24
VLAN ID: 110
Purpose: Gateway for K3s nodes
```

### BGP Configuration
```
Local AS: 65000
Router ID: 192.168.10.1
BGP Peers:
  - 192.168.10.11 (k3s-master-01) AS 65001
  - 192.168.10.12 (k3s-master-02) AS 65001
  - 192.168.10.13 (k3s-master-03) AS 65001
```

---

## 🔧 COMPLETE CONFIGURATION

### STEP 1: Initial Setup (Factory Default)

**Physical Connection:**
```
[ISP Router] ─── ether1 ─── [CORE-SWITCH-01] ─── ether2 ─── [Laptop]
                             192.168.88.1              192.168.88.100
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

# Set strong password (CHANGE THIS!)
/user set admin password=YourStrongPassword123!

# Set hostname
/system identity set name=core-switch-01

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

# Remove default bridge if exists (WARNING: Will disconnect!)
/interface bridge remove [find name=bridge]

# Create VLAN-aware bridge
/interface bridge add name=bridge vlan-filtering=yes comment="Main VLAN Bridge"

# Add all LAN ports to bridge (ether2-ether48, NOT ether1/WAN!)
/interface bridge port
add bridge=bridge interface=ether2 pvid=600 comment="Management Port"
add bridge=bridge interface=ether3 pvid=1
add bridge=bridge interface=ether4 pvid=1
# ... (repeat for ether5-ether48)
# Or use loop:
:for i from=3 to=48 do={
    /interface bridge port add bridge=bridge interface=("ether".$i) pvid=1
}

# Add SFP+ ports (uplinks to access switches)
/interface bridge port
add bridge=bridge interface=sfp-sfpplus1 comment="Trunk to ACCESS-01"
add bridge=bridge interface=sfp-sfpplus2 comment="Trunk to ACCESS-02"
add bridge=bridge interface=sfp-sfpplus3 comment="Trunk to ACCESS-03"
add bridge=bridge interface=sfp-sfpplus4 comment="Trunk to ACCESS-04"
```

---

### STEP 4: VLAN Configuration

```routeros
# ═══════════════════════════════════════════════════════════════
# VLAN INTERFACES
# ═══════════════════════════════════════════════════════════════

# VLAN 110 - K3s Cluster
/interface vlan add name=vlan-110 vlan-id=110 interface=bridge comment="K3s Cluster"

# VLAN 600 - Management
/interface vlan add name=vlan-600 vlan-id=600 interface=bridge comment="Management"

# ═══════════════════════════════════════════════════════════════
# BRIDGE VLAN FILTERING
# ═══════════════════════════════════════════════════════════════

# Management VLAN (600) - ether2 + trunk ports
/interface bridge vlan
add bridge=bridge tagged=bridge,sfp-sfpplus1,sfp-sfpplus2,sfp-sfpplus3,sfp-sfpplus4 untagged=ether2 vlan-ids=600 comment="Management VLAN"

# K3s Cluster VLAN (110) - trunk ports only
add bridge=bridge tagged=bridge,sfp-sfpplus1,sfp-sfpplus2,sfp-sfpplus3,sfp-sfpplus4 vlan-ids=110 comment="K3s VLAN"

# Enable VLAN filtering
/interface bridge set bridge vlan-filtering=yes
```

---

### STEP 5: IP Addressing

```routeros
# ═══════════════════════════════════════════════════════════════
# IP ADDRESSES
# ═══════════════════════════════════════════════════════════════

# Remove old management IP (if exists)
/ip address remove [find address~"192.168.88"]

# VLAN 600 - Management IP
/ip address add address=192.168.255.1/28 interface=vlan-600 comment="Management IP"

# VLAN 110 - K3s Gateway
/ip address add address=192.168.10.1/24 interface=vlan-110 comment="K3s Gateway"

# ═══════════════════════════════════════════════════════════════
# UPDATE LAPTOP IP (or reconnect via WinBox using new IP)
# ═══════════════════════════════════════════════════════════════

# Disconnect laptop, change IP to 192.168.255.100/28, reconnect to ether2
```

---

### STEP 6: Internet Connection (ISP Uplink)

**Option A: DHCP Client (Most Common)**
```routeros
# ═══════════════════════════════════════════════════════════════
# ISP UPLINK - DHCP CLIENT
# ═══════════════════════════════════════════════════════════════

/ip dhcp-client add interface=ether1 disabled=no use-peer-dns=yes use-peer-ntp=yes comment="ISP Uplink"

# Verify connection:
/ip dhcp-client print detail
# Should show: status=bound, address=<ISP_IP>, gateway=<ISP_GW>
```

**Option B: Static IP (If ISP Provided)**
```routeros
# ═══════════════════════════════════════════════════════════════
# ISP UPLINK - STATIC IP
# ═══════════════════════════════════════════════════════════════

# Example (replace with your ISP values):
/ip address add address=203.0.113.10/29 interface=ether1 comment="ISP Static IP"
/ip route add gateway=203.0.113.9 comment="ISP Gateway"

# Set DNS servers:
/ip dns set servers=8.8.8.8,8.8.4.4 allow-remote-requests=yes
```

---

### STEP 7: NAT Configuration (Internet Sharing)

```routeros
# ═══════════════════════════════════════════════════════════════
# NAT - SOURCE NAT (MASQUERADE)
# ═══════════════════════════════════════════════════════════════

# Enable NAT for all internal networks → Internet
/ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade comment="Internet NAT"

# Test NAT:
/ping 8.8.8.8 count=5
# Should work!
```

---

### STEP 8: DHCP Server (For K3s VLAN)

```routeros
# ═══════════════════════════════════════════════════════════════
# DHCP SERVER - VLAN 110 (K3s Cluster)
# ═══════════════════════════════════════════════════════════════

# Create IP pool (temporary IPs for initial setup)
/ip pool add name=dhcp-k3s ranges=192.168.10.200-192.168.10.220 comment="K3s DHCP Pool"

# Create DHCP network
/ip dhcp-server network add address=192.168.10.0/24 gateway=192.168.10.1 dns-server=8.8.8.8,8.8.4.4 domain=zsel.opole.pl comment="K3s Network"

# Create DHCP server
/ip dhcp-server add name=dhcp-k3s interface=vlan-110 address-pool=dhcp-k3s disabled=no lease-time=10m comment="K3s DHCP Server"

# Static leases (for Mac Pro nodes - add after collecting MAC addresses)
/ip dhcp-server lease add address=192.168.10.11 mac-address=XX:XX:XX:XX:XX:01 server=dhcp-k3s comment="k3s-master-01"
/ip dhcp-server lease add address=192.168.10.12 mac-address=XX:XX:XX:XX:XX:02 server=dhcp-k3s comment="k3s-master-02"
/ip dhcp-server lease add address=192.168.10.13 mac-address=XX:XX:XX:XX:XX:03 server=dhcp-k3s comment="k3s-master-03"
/ip dhcp-server lease add address=192.168.10.14 mac-address=XX:XX:XX:XX:XX:04 server=dhcp-k3s comment="k3s-worker-01"
/ip dhcp-server lease add address=192.168.10.15 mac-address=XX:XX:XX:XX:XX:05 server=dhcp-k3s comment="k3s-worker-02"
/ip dhcp-server lease add address=192.168.10.16 mac-address=XX:XX:XX:XX:XX:06 server=dhcp-k3s comment="k3s-worker-03"
/ip dhcp-server lease add address=192.168.10.17 mac-address=XX:XX:XX:XX:XX:07 server=dhcp-k3s comment="k3s-worker-04"
/ip dhcp-server lease add address=192.168.10.18 mac-address=XX:XX:XX:XX:XX:08 server=dhcp-k3s comment="k3s-worker-05"
/ip dhcp-server lease add address=192.168.10.19 mac-address=XX:XX:XX:XX:XX:09 server=dhcp-k3s comment="k3s-worker-06"
```

---

### STEP 9: DNS Configuration

```routeros
# ═══════════════════════════════════════════════════════════════
# DNS SETTINGS
# ═══════════════════════════════════════════════════════════════

/ip dns set servers=8.8.8.8,8.8.4.4 allow-remote-requests=yes cache-size=4096KiB

# Test DNS:
/ping google.com count=5
# Should resolve and ping!
```

---

### STEP 10: NTP Configuration

```routeros
# ═══════════════════════════════════════════════════════════════
# NTP CLIENT (Time Synchronization)
# ═══════════════════════════════════════════════════════════════

/system ntp client set enabled=yes primary-ntp=pool.ntp.org secondary-ntp=time.google.com

# Verify time:
/system clock print
# Should show correct time after sync
```

---

### STEP 11: Firewall - INPUT Chain (Protect Router)

```routeros
# ═══════════════════════════════════════════════════════════════
# FIREWALL - INPUT CHAIN (Router Protection)
# ═══════════════════════════════════════════════════════════════

# Accept established/related connections
/ip firewall filter add chain=input connection-state=established,related action=accept comment="Accept Established/Related"

# Accept ICMP (ping)
/ip firewall filter add chain=input protocol=icmp action=accept comment="Accept ICMP"

# Accept SSH from Management VLAN only
/ip firewall filter add chain=input protocol=tcp dst-port=22 src-address=192.168.255.0/28 action=accept comment="SSH from Management"

# Accept WinBox from Management VLAN only
/ip firewall filter add chain=input protocol=tcp dst-port=8291 src-address=192.168.255.0/28 action=accept comment="WinBox from Management"

# Accept BGP from K3s masters
/ip firewall filter add chain=input protocol=tcp dst-port=179 src-address=192.168.10.11 action=accept comment="BGP from master-01"
/ip firewall filter add chain=input protocol=tcp dst-port=179 src-address=192.168.10.12 action=accept comment="BGP from master-02"
/ip firewall filter add chain=input protocol=tcp dst-port=179 src-address=192.168.10.13 action=accept comment="BGP from master-03"

# Accept DHCP requests
/ip firewall filter add chain=input protocol=udp dst-port=67 in-interface=vlan-110 action=accept comment="DHCP Requests"

# Drop everything else from WAN
/ip firewall filter add chain=input in-interface=ether1 action=drop comment="Drop WAN Input"

# Drop invalid packets
/ip firewall filter add chain=input connection-state=invalid action=drop comment="Drop Invalid"

# Drop all other input (default deny)
/ip firewall filter add chain=input action=drop comment="Drop Other Input"
```

---

### STEP 12: Firewall - FORWARD Chain (Inter-VLAN Routing)

```routeros
# ═══════════════════════════════════════════════════════════════
# FIREWALL - FORWARD CHAIN (Routing Control)
# ═══════════════════════════════════════════════════════════════

# Accept established/related
/ip firewall filter add chain=forward connection-state=established,related action=accept comment="Accept Established/Related"

# K3s (VLAN 110) → Internet: ALLOW
/ip firewall filter add chain=forward src-address=192.168.10.0/24 out-interface=ether1 action=accept comment="K3s to Internet"

# Management (VLAN 600) → Everywhere: ALLOW
/ip firewall filter add chain=forward src-address=192.168.255.0/28 action=accept comment="Management Full Access"

# K3s → Management: DENY (security)
/ip firewall filter add chain=forward src-address=192.168.10.0/24 dst-address=192.168.255.0/28 action=drop comment="Block K3s to Management"

# Drop invalid
/ip firewall filter add chain=forward connection-state=invalid action=drop comment="Drop Invalid"

# Drop all other forward
/ip firewall filter add chain=forward action=drop comment="Drop Other Forward"
```

---

### STEP 13: BGP Configuration (For MetalLB)

```routeros
# ═══════════════════════════════════════════════════════════════
# BGP CONFIGURATION (AS 65000)
# ═══════════════════════════════════════════════════════════════

# Enable routing
/routing bgp instance set default as=65000 router-id=192.168.10.1

# Configure BGP peers (K3s masters)
/routing bgp peer
add name=k3s-master-01 remote-address=192.168.10.11 remote-as=65001 ttl=default
add name=k3s-master-02 remote-address=192.168.10.12 remote-as=65001 ttl=default
add name=k3s-master-03 remote-address=192.168.10.13 remote-as=65001 ttl=default

# Advertise networks (optional - MetalLB will advertise to us)
# /routing bgp network add network=192.168.10.0/24

# Note: BGP peers will be DOWN until MetalLB is deployed!
```

---

### STEP 14: Advanced Security Features

```routeros
# ═══════════════════════════════════════════════════════════════
# ADVANCED SECURITY
# ═══════════════════════════════════════════════════════════════

# SSH Brute-Force Protection
/ip firewall filter add chain=input protocol=tcp dst-port=22 connection-state=new src-address-list=ssh_blacklist action=drop comment="SSH Blacklist"
/ip firewall filter add chain=input protocol=tcp dst-port=22 connection-state=new action=add-src-to-address-list address-list=ssh_stage1 address-list-timeout=1m
/ip firewall filter add chain=input protocol=tcp dst-port=22 connection-state=new src-address-list=ssh_stage1 action=add-src-to-address-list address-list=ssh_blacklist address-list-timeout=1d comment="SSH Brute-Force Protection"

# Port scan detection
/ip firewall filter add chain=input protocol=tcp psd=21,3s,3,1 action=add-src-to-address-list address-list=port_scanners address-list-timeout=2w comment="Port Scan Detection"
/ip firewall filter add chain=input protocol=tcp src-address-list=port_scanners action=drop comment="Drop Port Scanners"

# SYN Flood Protection
/ip firewall filter add chain=input protocol=tcp tcp-flags=syn connection-limit=30,32 action=drop comment="SYN Flood Protection"
```

---

### STEP 15: Monitoring & Logging

```routeros
# ═══════════════════════════════════════════════════════════════
# MONITORING SETUP
# ═══════════════════════════════════════════════════════════════

# Enable SNMP
/snmp set enabled=yes contact="admin@zsel.opole.pl" location="BCU Building - Main Rack"
/snmp community add name=public addresses=192.168.10.0/24,192.168.255.0/28 read-access=yes

# Logging
/system logging add topics=firewall,info action=memory prefix="FW: "
/system logging add topics=dhcp,info action=memory prefix="DHCP: "
/system logging add topics=bgp,info action=memory prefix="BGP: "
/system logging add topics=critical,error,warning action=memory

# Resource monitoring
/tool graphing interface add interface=ether1 comment="WAN Traffic"
/tool graphing interface add interface=vlan-110 comment="K3s Traffic"
/tool graphing interface add interface=vlan-600 comment="Management Traffic"

# Enable bandwidth test server
/tool bandwidth-server set enabled=yes
```

---

### STEP 16: Backup Configuration

```routeros
# ═══════════════════════════════════════════════════════════════
# BACKUP & EXPORT
# ═══════════════════════════════════════════════════════════════

# Create backup
/system backup save name=core-switch-01-initial

# Export configuration (human-readable)
/export file=core-switch-01-config

# Download files via WinBox: Files → core-switch-01-initial.backup, core-switch-01-config.rsc
```

---

## ✅ VERIFICATION CHECKLIST

### 1. Internet Connectivity
```routeros
/ping 8.8.8.8 count=10
/ping google.com count=10
# Expected: 0% packet loss
```

### 2. VLAN Configuration
```routeros
/interface vlan print
# Expected: vlan-110, vlan-600 visible
/interface bridge vlan print
# Expected: VLAN 110, 600 tagged on trunk ports
```

### 3. NAT Working
```routeros
/ip firewall nat print statistics
# Expected: Packets/bytes counter increasing
```

### 4. DHCP Server
```routeros
/ip dhcp-server lease print
# Expected: Will be empty until servers connected
```

### 5. DNS Resolution
```routeros
/ip dns cache print
# Expected: google.com resolved
```

### 6. Firewall Active
```routeros
/ip firewall filter print statistics
# Expected: Rules with packet counters
```

### 7. BGP Status
```routeros
/routing bgp peer print status
# Expected: Peers configured, state: idle (until MetalLB deployed)
```

### 8. Time Sync
```routeros
/system clock print
/system ntp client print
# Expected: Correct time, NTP status: synchronized
```

---

## 📊 PORT MAPPING

### WAN
- **ether1**: ISP Uplink (WAN)

### Management VLAN 600 (Untagged)
- **ether2**: Management laptop/workstation

### Trunk Ports (VLAN 110, 600 tagged)
- **sfp-sfpplus1**: Uplink to ACCESS-01 (10Gbps)
- **sfp-sfpplus2**: Uplink to ACCESS-02 (10Gbps)
- **sfp-sfpplus3**: Uplink to ACCESS-03 (10Gbps)
- **sfp-sfpplus4**: Uplink to ACCESS-04 (10Gbps)

### Reserved Ports
- **ether3-48**: Available for expansion

---

## 🔧 TROUBLESHOOTING

### Internet Not Working
```routeros
# Check DHCP client:
/ip dhcp-client print detail
# Should show: status=bound

# Check default route:
/ip route print
# Should have: 0.0.0.0/0 via <ISP_GW>

# Check NAT:
/ip firewall nat print
# Should have: srcnat, ether1, masquerade

# Test from router:
/ping 8.8.8.8
```

### VLAN Not Working
```routeros
# Check VLAN filtering enabled:
/interface bridge print
# Should show: vlan-filtering=yes

# Check VLAN membership:
/interface bridge vlan print

# Check trunk ports:
/interface bridge port print
```

### BGP Not Establishing
```routeros
# Check peers:
/routing bgp peer print status

# Check firewall (port 179):
/ip firewall filter print

# Note: BGP will be DOWN until MetalLB is deployed on K3s!
```

### DHCP Not Working
```routeros
# Check server status:
/ip dhcp-server print

# Check leases:
/ip dhcp-server lease print

# Check network config:
/ip dhcp-server network print

# Enable debugging:
/system logging add topics=dhcp,debug action=memory
```

---

## 📋 QUICK REFERENCE

| Parameter | Value |
|-----------|-------|
| **Hostname** | core-switch-01 |
| **Management IP** | 192.168.255.1/28 (VLAN 600) |
| **K3s Gateway** | 192.168.10.1/24 (VLAN 110) |
| **WAN Interface** | ether1 (DHCP or Static) |
| **BGP AS** | 65000 |
| **BGP Router ID** | 192.168.10.1 |
| **BGP Peers** | 192.168.10.11-13 (AS 65001) |
| **Trunk Ports** | sfp-sfpplus1-4 |
| **Admin Password** | YourStrongPassword123! |

---

## 🎯 NEXT STEPS

Po ukończeniu konfiguracji CORE switch:

1. ✅ Test Internet: `ping google.com`
2. ✅ Backup config: `/system backup save`
3. ✅ Przejdź do konfiguracji ACCESS-01
4. ⏸️ Serwery podłączaj DOPIERO po skonfigurowaniu wszystkich 5 switchy!

---

**Status:** 🟢 READY FOR PRODUCTION  
**Last Updated:** 2025-11-27
