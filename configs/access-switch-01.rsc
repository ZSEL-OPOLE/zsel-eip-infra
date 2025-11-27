# ═══════════════════════════════════════════════════════════════
# ACCESS-SWITCH-01 - Complete Configuration
# Project: BCU ZSE Opole - Network Infrastructure
# Device: MikroTik CRS354-48G-4S+2Q+RM
# Role: Access Switch (Mac Pro 01-03 - K3s Masters)
# Management IP: 192.168.255.11/28 (VLAN 600)
# Date: 2025-11-27
# ═══════════════════════════════════════════════════════════════

# USAGE:
# 1. Factory reset device
# 2. Connect laptop to ether48 (192.168.88.100/24)
# 3. Login via WinBox (192.168.88.1)
# 4. Import this file or paste via Terminal

# ═══════════════════════════════════════════════════════════════
# PART 1: SYSTEM BASICS
# ═══════════════════════════════════════════════════════════════

/system identity set name=access-switch-01
/system clock set time-zone-name=Europe/Warsaw

# Change admin password (SAME as CORE!)
/user set admin password=ZSE-BCU-2025!SecureP@ss

# Disable insecure services
/ip service disable telnet,ftp,www-ssl
/ip service set ssh port=22 disabled=no
/ip service set winbox port=8291 disabled=no

# ═══════════════════════════════════════════════════════════════
# PART 2: BRIDGE CONFIGURATION (VLAN-Aware)
# ═══════════════════════════════════════════════════════════════

# Remove default configuration
/interface bridge remove [find name=bridge]

# Create VLAN-aware bridge
/interface bridge add name=bridge vlan-filtering=no comment="Main VLAN Bridge"

# Add management port
/interface bridge port add bridge=bridge interface=ether48 pvid=600 comment="Management Port"

# Add Mac Pro ports (K3s VLAN 110)
/interface bridge port add bridge=bridge interface=ether1 pvid=110 comment="Mac Pro 01 - k3s-master-01"
/interface bridge port add bridge=bridge interface=ether2 pvid=110 comment="Mac Pro 02 - k3s-master-02"
/interface bridge port add bridge=bridge interface=ether3 pvid=110 comment="Mac Pro 03 - k3s-master-03"

# Add trunk port (uplink to CORE)
/interface bridge port add bridge=bridge interface=sfp-sfpplus1 comment="Trunk to CORE"

# ═══════════════════════════════════════════════════════════════
# PART 3: VLAN CONFIGURATION
# ═══════════════════════════════════════════════════════════════

# Create VLAN interface (Management only)
/interface vlan add name=vlan-600 vlan-id=600 interface=bridge comment="Management"

# Configure Bridge VLANs
/interface bridge vlan add bridge=bridge tagged=bridge,sfp-sfpplus1 untagged=ether48 vlan-ids=600 comment="Management VLAN"
/interface bridge vlan add bridge=bridge tagged=bridge,sfp-sfpplus1 untagged=ether1,ether2,ether3 vlan-ids=110 comment="K3s VLAN"

# ═══════════════════════════════════════════════════════════════
# PART 4: IP ADDRESSING
# ═══════════════════════════════════════════════════════════════

# Remove default IP
/ip address remove [find address~"192.168.88"]

# Management IP
/ip address add address=192.168.255.11/28 interface=vlan-600 comment="Management IP"

# Default gateway (to CORE)
/ip route add gateway=192.168.255.1 comment="Default Gateway to CORE"

# DNS servers
/ip dns set servers=8.8.8.8,8.8.4.4 allow-remote-requests=no

# ═══════════════════════════════════════════════════════════════
# PART 4.5: LLDP (Link Layer Discovery Protocol)
# ═══════════════════════════════════════════════════════════════

# Enable LLDP for automatic neighbor discovery
/ip neighbor discovery-settings set discover-interface-list=all protocol=cdp,lldp,mndp

# ═══════════════════════════════════════════════════════════════
# PART 5: FIREWALL - INPUT CHAIN (Switch Protection)
# ═══════════════════════════════════════════════════════════════

# Accept established/related
/ip firewall filter add chain=input connection-state=established,related action=accept comment="Accept Established/Related"

# Accept ICMP
/ip firewall filter add chain=input protocol=icmp action=accept comment="Accept ICMP"

# Accept SSH from Management VLAN
/ip firewall filter add chain=input protocol=tcp dst-port=22 src-address=192.168.255.0/28 action=accept comment="SSH from Management"

# Accept WinBox from Management VLAN
/ip firewall filter add chain=input protocol=tcp dst-port=8291 src-address=192.168.255.0/28 action=accept comment="WinBox from Management"

# Drop invalid
/ip firewall filter add chain=input connection-state=invalid action=drop comment="Drop Invalid"

# SSH Brute-Force Protection
/ip firewall filter add chain=input protocol=tcp dst-port=22 connection-state=new src-address-list=ssh_blacklist action=drop comment="SSH Blacklist"
/ip firewall filter add chain=input protocol=tcp dst-port=22 connection-state=new action=add-src-to-address-list address-list=ssh_stage1 address-list-timeout=1m
/ip firewall filter add chain=input protocol=tcp dst-port=22 connection-state=new src-address-list=ssh_stage1 action=add-src-to-address-list address-list=ssh_blacklist address-list-timeout=1d comment="SSH Brute-Force Protection"

# Drop all other input
/ip firewall filter add chain=input action=drop comment="Drop Other Input"

# ═══════════════════════════════════════════════════════════════
# PART 6: NTP CONFIGURATION
# ═══════════════════════════════════════════════════════════════

/system ntp client set enabled=yes primary-ntp=pool.ntp.org secondary-ntp=time.google.com

# ═══════════════════════════════════════════════════════════════
# PART 7: MONITORING (SNMP + Logging)
# ═══════════════════════════════════════════════════════════════

# Enable SNMP
/snmp set enabled=yes contact="admin@zsel.opole.pl" location="BCU Building - ACCESS-01"
/snmp community add name=public addresses=192.168.255.0/28 read-access=yes

# Logging
/system logging add topics=system,info action=memory
/system logging add topics=critical,error,warning action=memory

# Interface monitoring
/tool graphing interface add interface=ether1 comment="Mac Pro 01"
/tool graphing interface add interface=ether2 comment="Mac Pro 02"
/tool graphing interface add interface=ether3 comment="Mac Pro 03"
/tool graphing interface add interface=sfp-sfpplus1 comment="Uplink to CORE"

# ═══════════════════════════════════════════════════════════════
# PART 8: ENABLE VLAN FILTERING (LAST STEP!)
# ═══════════════════════════════════════════════════════════════

# WARNING: After enabling, reconnect laptop to ether48 with 192.168.255.100/28
# Uncomment after verifying configuration:
# /interface bridge set bridge vlan-filtering=yes

# ═══════════════════════════════════════════════════════════════
# VERIFICATION COMMANDS
# ═══════════════════════════════════════════════════════════════

# /ping 192.168.255.1 count=5
# /ping 8.8.8.8 count=5
# /interface vlan print
# /interface bridge vlan print
# /interface bridge port print

# ═══════════════════════════════════════════════════════════════
# BACKUP CONFIGURATION
# ═══════════════════════════════════════════════════════════════

# /system backup save name=access-switch-01-initial
# /export file=access-switch-01-config

# ═══════════════════════════════════════════════════════════════
# END OF CONFIGURATION
# Device: ACCESS-SWITCH-01
# Connected: Mac Pro 01-03 (K3s Masters)
# Next: Disconnect laptop, connect trunk to CORE sfp-sfpplus1
# ═══════════════════════════════════════════════════════════════
