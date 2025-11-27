# 🎯 ACCESS-SWITCH-03 - Pełna Konfiguracja

**Model:** MikroTik CRS354-48G-4S+2Q+RM  
**Rola:** Access switch (Mac Pro 07-09 connectivity)  
**Lokalizacja:** Rack z Mac Pro 07-09

---

## 📋 ADDRESSING

### Management IP (VLAN 600)
```
Interface: vlan-600
IP Address: 192.168.255.13/28
VLAN ID: 600
Gateway: 192.168.255.1 (CORE)
DNS: 8.8.8.8, 8.8.4.4
```

### Connected Devices (VLAN 110 - Untagged)
```
ether1 → Mac Pro 07 (k3s-worker-04) - 192.168.10.17
ether2 → Mac Pro 08 (k3s-worker-05) - 192.168.10.18
ether3 → Mac Pro 09 (k3s-worker-06) - 192.168.10.19

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

**⚠️ IMPORTANT:** Configure this switch AFTER ACCESS-02!

**Physical Connection:**
```
[Laptop] ─── ether48 ─── [ACCESS-03]
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
/system identity set name=access-switch-03
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

# Mac Pro ports (VLAN 110 - untagged)
/interface bridge port add bridge=bridge interface=ether1 pvid=110 comment="Mac Pro 07 - worker-04"
/interface bridge port add bridge=bridge interface=ether2 pvid=110 comment="Mac Pro 08 - worker-05"
/interface bridge port add bridge=bridge interface=ether3 pvid=110 comment="Mac Pro 09 - worker-06"

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

# VLAN 110 - K3s
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

/ip address remove [find address~"192.168.88"]
/ip address add address=192.168.255.13/28 interface=vlan-600 comment="Management IP"
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

/snmp set enabled=yes contact="admin@zsel.opole.pl" location="BCU Building - Rack with Mac Pro 07-09"
/snmp community add name=public addresses=192.168.255.0/28 read-access=yes

/system logging add topics=system,info action=memory
/system logging add topics=critical,error,warning action=memory

/tool graphing interface add interface=ether1 comment="Mac Pro 07"
/tool graphing interface add interface=ether2 comment="Mac Pro 08"
/tool graphing interface add interface=ether3 comment="Mac Pro 09"
/tool graphing interface add interface=sfp-sfpplus1 comment="Uplink to CORE"
```

---

### STEP 9: Backup Configuration

```routeros
/system backup save name=access-switch-03-initial
/export file=access-switch-03-config
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

# 5. Check time sync
/system clock print
```

---

## 📊 PORT MAPPING

### Access Ports (VLAN 110 - K3s Untagged)
- **ether1**: Mac Pro 07 (k3s-worker-04) - 192.168.10.17
- **ether2**: Mac Pro 08 (k3s-worker-05) - 192.168.10.18
- **ether3**: Mac Pro 09 (k3s-worker-06) - 192.168.10.19

### Management Port (VLAN 600 - Untagged)
- **ether48**: Management laptop

### Trunk Port (VLAN 110, 600 - Tagged)
- **sfp-sfpplus1**: Uplink to CORE-SWITCH-01

---

## 📋 QUICK REFERENCE

| Parameter | Value |
|-----------|-------|
| **Hostname** | access-switch-03 |
| **Management IP** | 192.168.255.13/28 |
| **Gateway** | 192.168.255.1 |
| **Connected Devices** | Mac Pro 07-09 (K3s workers) |
| **VLAN 110 Ports** | ether1-3 |
| **Trunk Port** | sfp-sfpplus1 |
| **Admin Password** | YourStrongPassword123! |

---

## 🎯 NEXT STEPS

1. ✅ Test connectivity: `ping 192.168.255.1`
2. ✅ Backup config
3. ✅ Disconnect from laptop
4. ✅ Connect to CORE: sfp-sfpplus1 → CORE sfp-sfpplus3
5. ⏸️ DO NOT connect Mac Pro yet
6. ✅ Proceed to ACCESS-04 configuration

---

**Status:** 🟢 READY  
**Last Updated:** 2025-11-27
