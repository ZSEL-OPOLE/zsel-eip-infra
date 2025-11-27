# ═══════════════════════════════════════════════════════════════
# CORE-SWITCH-01 - Complete Configuration
# Project: BCU ZSE Opole - Network Infrastructure
# Device: MikroTik CRS354-48G-4S+2Q+RM
# Role: Core L3 Switch (K3s Gateway, NAT, BGP, DHCP)
# Management IP: 192.168.255.1/28 (VLAN 600)
# Date: 2025-11-27
# ═══════════════════════════════════════════════════════════════

# USAGE:
# 1. Factory reset device
# 2. Connect via WinBox (192.168.88.1)
# 3. Import this file: [System] → [Scripts] → Import
# 4. Or paste via Terminal (New Terminal → paste all)

# ═══════════════════════════════════════════════════════════════
# PART 1: SYSTEM BASICS
# ═══════════════════════════════════════════════════════════════

/system identity set name=core-switch-01
/system clock set time-zone-name=Europe/Warsaw

# Change admin password (MODIFY THIS!)
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

# Add all LAN ports (ether2-48) to bridge
/interface bridge port add bridge=bridge interface=ether2 pvid=600 comment="Management Port"
:for i from=3 to=48 do={
    /interface bridge port add bridge=bridge interface=("ether".$i) pvid=1
}

# Add SFP+ trunk ports (uplinks to access switches)
/interface bridge port add bridge=bridge interface=sfp-sfpplus1 comment="Trunk to ACCESS-01"
/interface bridge port add bridge=bridge interface=sfp-sfpplus2 comment="Trunk to ACCESS-02"
/interface bridge port add bridge=bridge interface=sfp-sfpplus3 comment="Trunk to ACCESS-03"
/interface bridge port add bridge=bridge interface=sfp-sfpplus4 comment="Trunk to ACCESS-04"

# ═══════════════════════════════════════════════════════════════
# PART 3: VLAN CONFIGURATION (K3s + Management)
# ═══════════════════════════════════════════════════════════════

# Create VLAN interfaces
/interface vlan add name=vlan-110 vlan-id=110 interface=bridge comment="K3s Cluster"
/interface vlan add name=vlan-600 vlan-id=600 interface=bridge comment="Management"

# Configure Bridge VLANs (tagging)
/interface bridge vlan add bridge=bridge tagged=bridge,sfp-sfpplus1,sfp-sfpplus2,sfp-sfpplus3,sfp-sfpplus4 untagged=ether2 vlan-ids=600 comment="Management VLAN"
/interface bridge vlan add bridge=bridge tagged=bridge,sfp-sfpplus1,sfp-sfpplus2,sfp-sfpplus3,sfp-sfpplus4 vlan-ids=110 comment="K3s VLAN"

# ═══════════════════════════════════════════════════════════════
# PART 4: IP ADDRESSING
# ═══════════════════════════════════════════════════════════════

# Remove default IP
/ip address remove [find address~"192.168.88"]

# Management IP (VLAN 600)
/ip address add address=192.168.255.1/28 interface=vlan-600 comment="Management IP"

# K3s Gateway (VLAN 110)
/ip address add address=192.168.10.1/24 interface=vlan-110 comment="K3s Gateway"

# ═══════════════════════════════════════════════════════════════
# PART 5: INTERNET CONNECTION (ISP Uplink)
# ═══════════════════════════════════════════════════════════════

# DHCP Client on WAN (most common)
/ip dhcp-client add interface=ether1 disabled=no use-peer-dns=yes use-peer-ntp=yes comment="ISP Uplink"

# If static IP provided by ISP, use this instead:
# /ip address add address=<ISP_IP>/29 interface=ether1 comment="ISP Static IP"
# /ip route add gateway=<ISP_GATEWAY> comment="ISP Gateway"

# DNS servers (if not using DHCP DNS)
/ip dns set servers=8.8.8.8,8.8.4.4 allow-remote-requests=yes cache-size=4096KiB

# ═══════════════════════════════════════════════════════════════
# PART 6: NAT CONFIGURATION (Internet Sharing)
# ═══════════════════════════════════════════════════════════════

/ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade comment="Internet NAT"

# ═══════════════════════════════════════════════════════════════
# PART 7: DHCP SERVER (K3s VLAN 110)
# ═══════════════════════════════════════════════════════════════

# IP Pool (temporary IPs for initial setup)
/ip pool add name=dhcp-k3s ranges=192.168.10.200-192.168.10.220 comment="K3s DHCP Pool"

# DHCP Network
/ip dhcp-server network add address=192.168.10.0/24 gateway=192.168.10.1 dns-server=8.8.8.8,8.8.4.4 domain=zsel.opole.pl comment="K3s Network"

# DHCP Server
/ip dhcp-server add name=dhcp-k3s interface=vlan-110 address-pool=dhcp-k3s disabled=no lease-time=10m comment="K3s DHCP Server"

# Static DHCP Leases (add MAC addresses after collecting from servers)
# /ip dhcp-server lease add address=192.168.10.11 mac-address=XX:XX:XX:XX:XX:01 server=dhcp-k3s comment="k3s-master-01"
# /ip dhcp-server lease add address=192.168.10.12 mac-address=XX:XX:XX:XX:XX:02 server=dhcp-k3s comment="k3s-master-02"
# /ip dhcp-server lease add address=192.168.10.13 mac-address=XX:XX:XX:XX:XX:03 server=dhcp-k3s comment="k3s-master-03"
# /ip dhcp-server lease add address=192.168.10.14 mac-address=XX:XX:XX:XX:XX:04 server=dhcp-k3s comment="k3s-worker-01"
# /ip dhcp-server lease add address=192.168.10.15 mac-address=XX:XX:XX:XX:XX:05 server=dhcp-k3s comment="k3s-worker-02"
# /ip dhcp-server lease add address=192.168.10.16 mac-address=XX:XX:XX:XX:XX:06 server=dhcp-k3s comment="k3s-worker-03"
# /ip dhcp-server lease add address=192.168.10.17 mac-address=XX:XX:XX:XX:XX:07 server=dhcp-k3s comment="k3s-worker-04"
# /ip dhcp-server lease add address=192.168.10.18 mac-address=XX:XX:XX:XX:XX:08 server=dhcp-k3s comment="k3s-worker-05"
# /ip dhcp-server lease add address=192.168.10.19 mac-address=XX:XX:XX:XX:XX:09 server=dhcp-k3s comment="k3s-worker-06"

# ═══════════════════════════════════════════════════════════════
# PART 8: FIREWALL - INPUT CHAIN (Router Protection)
# ═══════════════════════════════════════════════════════════════

# Accept established/related
/ip firewall filter add chain=input connection-state=established,related action=accept comment="Accept Established/Related"

# Accept ICMP
/ip firewall filter add chain=input protocol=icmp action=accept comment="Accept ICMP"

# Accept SSH from Management VLAN
/ip firewall filter add chain=input protocol=tcp dst-port=22 src-address=192.168.255.0/28 action=accept comment="SSH from Management"

# Accept WinBox from Management VLAN
/ip firewall filter add chain=input protocol=tcp dst-port=8291 src-address=192.168.255.0/28 action=accept comment="WinBox from Management"

# Accept BGP from K3s masters
/ip firewall filter add chain=input protocol=tcp dst-port=179 src-address=192.168.10.11 action=accept comment="BGP from master-01"
/ip firewall filter add chain=input protocol=tcp dst-port=179 src-address=192.168.10.12 action=accept comment="BGP from master-02"
/ip firewall filter add chain=input protocol=tcp dst-port=179 src-address=192.168.10.13 action=accept comment="BGP from master-03"

# Accept DHCP requests
/ip firewall filter add chain=input protocol=udp dst-port=67 in-interface=vlan-110 action=accept comment="DHCP Requests"

# Drop WAN input
/ip firewall filter add chain=input in-interface=ether1 action=drop comment="Drop WAN Input"

# Drop invalid
/ip firewall filter add chain=input connection-state=invalid action=drop comment="Drop Invalid"

# SSH Brute-Force Protection
/ip firewall filter add chain=input protocol=tcp dst-port=22 connection-state=new src-address-list=ssh_blacklist action=drop comment="SSH Blacklist"
/ip firewall filter add chain=input protocol=tcp dst-port=22 connection-state=new action=add-src-to-address-list address-list=ssh_stage1 address-list-timeout=1m
/ip firewall filter add chain=input protocol=tcp dst-port=22 connection-state=new src-address-list=ssh_stage1 action=add-src-to-address-list address-list=ssh_blacklist address-list-timeout=1d comment="SSH Brute-Force Protection"

# Port scan detection
/ip firewall filter add chain=input protocol=tcp psd=21,3s,3,1 action=add-src-to-address-list address-list=port_scanners address-list-timeout=2w comment="Port Scan Detection"
/ip firewall filter add chain=input protocol=tcp src-address-list=port_scanners action=drop comment="Drop Port Scanners"

# SYN Flood Protection
/ip firewall filter add chain=input protocol=tcp tcp-flags=syn connection-limit=30,32 action=drop comment="SYN Flood Protection"

# Drop all other input
/ip firewall filter add chain=input action=drop comment="Drop Other Input"

# ═══════════════════════════════════════════════════════════════
# PART 9: FIREWALL - FORWARD CHAIN (Inter-VLAN Routing)
# ═══════════════════════════════════════════════════════════════

# Accept established/related
/ip firewall filter add chain=forward connection-state=established,related action=accept comment="Accept Established/Related"

# K3s to Internet
/ip firewall filter add chain=forward src-address=192.168.10.0/24 out-interface=ether1 action=accept comment="K3s to Internet"

# Management full access
/ip firewall filter add chain=forward src-address=192.168.255.0/28 action=accept comment="Management Full Access"

# Block K3s to Management (security)
/ip firewall filter add chain=forward src-address=192.168.10.0/24 dst-address=192.168.255.0/28 action=drop comment="Block K3s to Management"

# Drop invalid
/ip firewall filter add chain=forward connection-state=invalid action=drop comment="Drop Invalid"

# Drop all other forward
/ip firewall filter add chain=forward action=drop comment="Drop Other Forward"

# ═══════════════════════════════════════════════════════════════
# PART 10: BGP CONFIGURATION (MetalLB Integration)
# ═══════════════════════════════════════════════════════════════

# Enable BGP instance
/routing bgp instance set default as=65000 router-id=192.168.10.1

# Add BGP peers (K3s masters with MetalLB)
/routing bgp peer add name=k3s-master-01 remote-address=192.168.10.11 remote-as=65001 ttl=default
/routing bgp peer add name=k3s-master-02 remote-address=192.168.10.12 remote-as=65001 ttl=default
/routing bgp peer add name=k3s-master-03 remote-address=192.168.10.13 remote-as=65001 ttl=default

# Note: BGP peers will be DOWN until MetalLB is deployed on K3s cluster

# ═══════════════════════════════════════════════════════════════
# PART 11: LLDP (LINK LAYER DISCOVERY PROTOCOL)
# ═══════════════════════════════════════════════════════════════

# Enable LLDP for automatic neighbor discovery
/ip neighbor discovery-settings set discover-interface-list=all protocol=cdp,lldp,mndp

# ═══════════════════════════════════════════════════════════════
# PART 12: NTP CONFIGURATION
# ═══════════════════════════════════════════════════════════════

/system ntp client set enabled=yes primary-ntp=pool.ntp.org secondary-ntp=time.google.com

# ═══════════════════════════════════════════════════════════════
# PART 13: MONITORING (SNMP + Logging)
# ═══════════════════════════════════════════════════════════════

# Enable SNMP
/snmp set enabled=yes contact="admin@zsel.opole.pl" location="BCU Building - Core Switch"
/snmp community add name=public addresses=192.168.10.0/24,192.168.255.0/28 read-access=yes

# Logging
/system logging add topics=firewall,info action=memory prefix="FW: "
/system logging add topics=dhcp,info action=memory prefix="DHCP: "
/system logging add topics=bgp,info action=memory prefix="BGP: "
/system logging add topics=critical,error,warning action=memory

# Interface monitoring
/tool graphing interface add interface=ether1 comment="WAN Traffic"
/tool graphing interface add interface=vlan-110 comment="K3s Traffic"
/tool graphing interface add interface=vlan-600 comment="Management Traffic"

# Bandwidth test server
/tool bandwidth-server set enabled=yes

# ═══════════════════════════════════════════════════════════════
# PART 14: ENABLE VLAN FILTERING (LAST STEP!)
# ═══════════════════════════════════════════════════════════════

# WARNING: This will enable VLAN filtering and may disconnect you!
# Make sure you have access via VLAN 600 before enabling!

# After verifying everything works, uncomment:
# /interface bridge set bridge vlan-filtering=yes

# ═══════════════════════════════════════════════════════════════
# VERIFICATION COMMANDS
# ═══════════════════════════════════════════════════════════════

# After configuration, verify:
# /ping 8.8.8.8 count=5
# /ping google.com count=5
# /interface vlan print
# /interface bridge vlan print
# /ip firewall nat print statistics
# /routing bgp peer print status

# ═══════════════════════════════════════════════════════════════
# BACKUP CONFIGURATION
# ═══════════════════════════════════════════════════════════════

# After successful configuration:
# /system backup save name=core-switch-01-initial
# /export file=core-switch-01-config

# ═══════════════════════════════════════════════════════════════
# END OF CONFIGURATION
# Device: CORE-SWITCH-01
# Status: Ready for production (after VLAN filtering enabled)
# Next: Configure ACCESS switches (01-04)
# ═══════════════════════════════════════════════════════════════
