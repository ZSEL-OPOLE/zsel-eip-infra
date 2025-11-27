# 🎯 ACCESS-SWITCH-04 - Pełna Konfiguracja

**Model:** MikroTik CRS354-48G-4S+2Q+RM  
**Rola:** Access switch (Redundancy/backup for Mac Pro bonding)  
**Lokalizacja:** Central rack (redundancy switch)

---

## 📋 ADDRESSING

### Management IP (VLAN 600)
```
Interface: vlan-600
IP Address: 192.168.255.14/28
VLAN ID: 600
Gateway: 192.168.255.1 (CORE)
DNS: 8.8.8.8, 8.8.4.4
```

### Connected Devices (VLAN 110 - Untagged)
```
ether1 → Mac Pro 01 - NIC2 (backup interface)
ether2 → Mac Pro 02 - NIC2 (backup interface)
ether3 → Mac Pro 03 - NIC2 (backup interface)
ether4 → Mac Pro 04 - NIC2 (backup interface)
ether5 → Mac Pro 05 - NIC2 (backup interface)
ether6 → Mac Pro 06 - NIC2 (backup interface)
ether7 → Mac Pro 07 - NIC2 (backup interface)
ether8 → Mac Pro 08 - NIC2 (backup interface)
ether9 → Mac Pro 09 - NIC2 (backup interface)

Purpose: Backup interface for active-backup bonding
Status: Normally DOWN (backup), UP only if primary fails
```

### Uplink to Core
```
sfp-sfpplus1 → CORE-SWITCH-01 (trunk port)
VLANs: 110 (K3s), 600 (Management) - tagged
```

---

## 🔧 COMPLETE CONFIGURATION

### STEP 1: Initial Setup (Factory Default)

**⚠️ IMPORTANT:** Configure this switch AFTER ACCESS-03!

**Physical Connection:**
```
[Laptop] ─── ether48 ─── [ACCESS-04]
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
Password: <EMPTY>
```

---

### STEP 2: Basic System Configuration

```routeros
# ═══════════════════════════════════════════════════════════════
# SYSTEM IDENTITY & SECURITY
# ═══════════════════════════════════════════════════════════════

/user set admin password=YourStrongPassword123!
/system identity set name=access-switch-04
/ip service disable telnet,ftp,www-ssl
/ip service set ssh disabled=no port=22
/ip service set winbox disabled=no port=8291
/system clock set time-zone-name=Europe/Warsaw
```

---

### STEP 3: Bridge Configuration

```routeros
# ═══════════════════════════════════════════════════════════════
# BRIDGE SETUP (VLAN-aware)
# ═══════════════════════════════════════════════════════════════

/interface bridge remove [find name=bridge]
/interface bridge add name=bridge vlan-filtering=yes comment="Main VLAN Bridge"

# Management port
/interface bridge port add bridge=bridge interface=ether48 pvid=600 comment="Management Port"

# Mac Pro backup ports (VLAN 110 - untagged)
/interface bridge port add bridge=bridge interface=ether1 pvid=110 comment="Mac Pro 01 - NIC2 (backup)"
/interface bridge port add bridge=bridge interface=ether2 pvid=110 comment="Mac Pro 02 - NIC2 (backup)"
/interface bridge port add bridge=bridge interface=ether3 pvid=110 comment="Mac Pro 03 - NIC2 (backup)"
/interface bridge port add bridge=bridge interface=ether4 pvid=110 comment="Mac Pro 04 - NIC2 (backup)"
/interface bridge port add bridge=bridge interface=ether5 pvid=110 comment="Mac Pro 05 - NIC2 (backup)"
/interface bridge port add bridge=bridge interface=ether6 pvid=110 comment="Mac Pro 06 - NIC2 (backup)"
/interface bridge port add bridge=bridge interface=ether7 pvid=110 comment="Mac Pro 07 - NIC2 (backup)"
/interface bridge port add bridge=bridge interface=ether8 pvid=110 comment="Mac Pro 08 - NIC2 (backup)"
/interface bridge port add bridge=bridge interface=ether9 pvid=110 comment="Mac Pro 09 - NIC2 (backup)"

# Uplink to CORE (trunk)
/interface bridge port add bridge=bridge interface=sfp-sfpplus1 comment="Trunk to CORE"
```

---

### STEP 4: VLAN Configuration

```routeros
# ═══════════════════════════════════════════════════════════════
# VLAN INTERFACES
# ═══════════════════════════════════════════════════════════════

/interface vlan add name=vlan-600 vlan-id=600 interface=bridge comment="Management"

# ═══════════════════════════════════════════════════════════════
# BRIDGE VLAN FILTERING
# ═══════════════════════════════════════════════════════════════

# VLAN 600 - Management
/interface bridge vlan add bridge=bridge tagged=bridge,sfp-sfpplus1 untagged=ether48 vlan-ids=600 comment="Management VLAN"

# VLAN 110 - K3s (all Mac Pro backup ports)
/interface bridge vlan add bridge=bridge tagged=bridge,sfp-sfpplus1 untagged=ether1,ether2,ether3,ether4,ether5,ether6,ether7,ether8,ether9 vlan-ids=110 comment="K3s VLAN"

# Enable VLAN filtering
/interface bridge set bridge vlan-filtering=yes
```

---

### STEP 5: IP Addressing

```routeros
# ═══════════════════════════════════════════════════════════════
# IP ADDRESS & DEFAULT GATEWAY
# ═══════════════════════════════════════════════════════════════

/ip address remove [find address~"192.168.88"]
/ip address add address=192.168.255.14/28 interface=vlan-600 comment="Management IP"
/ip route add gateway=192.168.255.1 comment="Default Gateway to CORE"
/ip dns set servers=8.8.8.8,8.8.4.4 allow-remote-requests=no
```

---

### STEP 6: NTP Configuration

```routeros
/system ntp client set enabled=yes primary-ntp=pool.ntp.org secondary-ntp=time.google.com
```

---

### STEP 7: Firewall Configuration

```routeros
# ═══════════════════════════════════════════════════════════════
# FIREWALL - INPUT CHAIN
# ═══════════════════════════════════════════════════════════════

/ip firewall filter add chain=input connection-state=established,related action=accept comment="Accept Established/Related"
/ip firewall filter add chain=input protocol=icmp action=accept comment="Accept ICMP"
/ip firewall filter add chain=input protocol=tcp dst-port=22 src-address=192.168.255.0/28 action=accept comment="SSH from Management"
/ip firewall filter add chain=input protocol=tcp dst-port=8291 src-address=192.168.255.0/28 action=accept comment="WinBox from Management"
/ip firewall filter add chain=input connection-state=invalid action=drop comment="Drop Invalid"
/ip firewall filter add chain=input action=drop comment="Drop Other Input"

# ═══════════════════════════════════════════════════════════════
# SSH BRUTE-FORCE PROTECTION
# ═══════════════════════════════════════════════════════════════

/ip firewall filter add chain=input protocol=tcp dst-port=22 connection-state=new src-address-list=ssh_blacklist action=drop comment="SSH Blacklist"
/ip firewall filter add chain=input protocol=tcp dst-port=22 connection-state=new action=add-src-to-address-list address-list=ssh_stage1 address-list-timeout=1m
/ip firewall filter add chain=input protocol=tcp dst-port=22 connection-state=new src-address-list=ssh_stage1 action=add-src-to-address-list address-list=ssh_blacklist address-list-timeout=1d comment="SSH Brute-Force Protection"
```

---

### STEP 8: Monitoring

```routeros
# ═══════════════════════════════════════════════════════════════
# MONITORING SETUP
# ═══════════════════════════════════════════════════════════════

/snmp set enabled=yes contact="admin@zsel.opole.pl" location="BCU Building - Redundancy Switch"
/snmp community add name=public addresses=192.168.255.0/28 read-access=yes

/system logging add topics=system,info action=memory
/system logging add topics=critical,error,warning action=memory

# Monitor all Mac Pro backup interfaces
/tool graphing interface add interface=ether1 comment="Mac Pro 01 Backup"
/tool graphing interface add interface=ether2 comment="Mac Pro 02 Backup"
/tool graphing interface add interface=ether3 comment="Mac Pro 03 Backup"
/tool graphing interface add interface=ether4 comment="Mac Pro 04 Backup"
/tool graphing interface add interface=ether5 comment="Mac Pro 05 Backup"
/tool graphing interface add interface=ether6 comment="Mac Pro 06 Backup"
/tool graphing interface add interface=ether7 comment="Mac Pro 07 Backup"
/tool graphing interface add interface=ether8 comment="Mac Pro 08 Backup"
/tool graphing interface add interface=ether9 comment="Mac Pro 09 Backup"
/tool graphing interface add interface=sfp-sfpplus1 comment="Uplink to CORE"
```

---

### STEP 9: Backup Configuration

```routeros
/system backup save name=access-switch-04-initial
/export file=access-switch-04-config
```

---

## ✅ VERIFICATION CHECKLIST

```routeros
# 1. Ping CORE
/ping 192.168.255.1 count=10

# 2. Ping Internet
/ping 8.8.8.8 count=10
/ping google.com count=10

# 3. Check VLANs
/interface vlan print
/interface bridge vlan print

# 4. Check default route
/ip route print

# 5. Check all ports in bridge
/interface bridge port print

# 6. Check time sync
/system clock print
```

---

## 📊 PORT MAPPING

### Backup Ports (VLAN 110 - K3s Untagged)
- **ether1**: Mac Pro 01 - NIC2 (backup) - 192.168.10.11
- **ether2**: Mac Pro 02 - NIC2 (backup) - 192.168.10.12
- **ether3**: Mac Pro 03 - NIC2 (backup) - 192.168.10.13
- **ether4**: Mac Pro 04 - NIC2 (backup) - 192.168.10.14
- **ether5**: Mac Pro 05 - NIC2 (backup) - 192.168.10.15
- **ether6**: Mac Pro 06 - NIC2 (backup) - 192.168.10.16
- **ether7**: Mac Pro 07 - NIC2 (backup) - 192.168.10.17
- **ether8**: Mac Pro 08 - NIC2 (backup) - 192.168.10.18
- **ether9**: Mac Pro 09 - NIC2 (backup) - 192.168.10.19

**Note:** These ports are normally DOWN (backup interface in bond). They will activate ONLY if primary interface fails.

### Management Port (VLAN 600 - Untagged)
- **ether48**: Management laptop

### Trunk Port (VLAN 110, 600 - Tagged)
- **sfp-sfpplus1**: Uplink to CORE-SWITCH-01

---

## 🔌 BONDING ARCHITECTURE

### How Active-Backup Works

```
Mac Pro 01:
├── NIC1 (primary) → ACCESS-01 ether1 [ACTIVE - Traffic flows here]
└── NIC2 (backup)  → ACCESS-04 ether1 [STANDBY - No traffic unless NIC1 fails]

If NIC1 or ACCESS-01 fails:
├── NIC1 (primary) → ACCESS-01 ether1 [DOWN]
└── NIC2 (backup)  → ACCESS-04 ether1 [BECOMES ACTIVE - Takes over immediately]
```

### Expected Interface Status

**Normal operation (all primary links working):**
```routeros
/interface ethernet monitor ether1-9
# Expected: link-ok=yes, but LOW traffic (backup interfaces)
```

**When primary fails:**
```routeros
# Corresponding ether port will show HIGH traffic
# Example: If ACCESS-01 ether1 fails, ACCESS-04 ether1 becomes active
```

### Verify Bonding on Mac Pro

```bash
# On each Mac Pro (Ubuntu):
cat /proc/net/bonding/bond0

# Expected output:
# Bonding Mode: fault-tolerance (active-backup)
# Primary Slave: <interface1>
# Currently Active Slave: <interface1>  ← Should be primary
# MII Status: up
# 
# Slave Interface: <interface1>
# MII Status: up  ← Primary link OK
# 
# Slave Interface: <interface2>
# MII Status: up  ← Backup link OK (but not active)
```

### Failover Test

```bash
# On Mac Pro (Ubuntu):
# Disable primary interface:
sudo ip link set <primary_interface> down

# Check bond status:
cat /proc/net/bonding/bond0
# Expected: Currently Active Slave: <interface2> (switched to backup!)

# Test connectivity:
ping 192.168.10.1
# Should still work!

# Re-enable primary:
sudo ip link set <primary_interface> up

# Bond should switch back to primary after few seconds
```

---

## 📋 QUICK REFERENCE

| Parameter | Value |
|-----------|-------|
| **Hostname** | access-switch-04 |
| **Management IP** | 192.168.255.14/28 |
| **Gateway** | 192.168.255.1 |
| **Role** | Redundancy/backup switch |
| **Connected Devices** | All 9 Mac Pro (backup NICs) |
| **VLAN 110 Ports** | ether1-9 (backup interfaces) |
| **Trunk Port** | sfp-sfpplus1 |
| **Admin Password** | YourStrongPassword123! |

---

## 🎯 NEXT STEPS

1. ✅ Test connectivity: `ping 192.168.255.1`
2. ✅ Backup config
3. ✅ Disconnect from laptop
4. ✅ Connect to CORE: sfp-sfpplus1 → CORE sfp-sfpplus4
5. ✅ **Verify all 5 switches pingable from each other**
6. ✅ **Network infrastructure complete!**
7. 🎉 **Ready to connect Mac Pro servers!**

---

## 🔧 TROUBLESHOOTING

### Backup Interface Shows High Traffic (Should Be Low)

**Problem:** ether1-9 showing high traffic when all primaries are UP

**Solution:**
```bash
# On affected Mac Pro, check bonding:
cat /proc/net/bonding/bond0

# If backup is active instead of primary:
sudo ip link set bond0 down
sudo ip link set bond0 up
# This will re-initialize bonding and prefer primary
```

### Failover Not Working

**Problem:** Primary interface fails, but backup doesn't take over

**Check on switch:**
```routeros
# Verify backup port is UP:
/interface ethernet monitor ether<X>
# Expected: link-ok=yes

# Check VLAN membership:
/interface bridge port print where interface=ether<X>
# Expected: pvid=110, bridge=bridge
```

**Check on Mac Pro:**
```bash
# Verify both interfaces in bond:
ip link show bond0
# Should list both slave interfaces

# Check bonding mode:
cat /sys/class/net/bond0/bonding/mode
# Expected: active-backup 1
```

---

**Status:** 🟢 READY (Redundancy Switch)  
**Last Updated:** 2025-11-27
