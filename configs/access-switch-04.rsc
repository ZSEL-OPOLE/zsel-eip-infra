# ═══════════════════════════════════════════════════════════════
# ACCESS-SWITCH-04 - Complete Configuration
# Project: BCU ZSE Opole - Network Infrastructure
# Device: MikroTik CRS354-48G-4S+2Q+RM
# Role: Redundancy Switch (Backup NICs for all Mac Pro)
# Management IP: 192.168.255.14/28 (VLAN 600)
# Date: 2025-11-27
# ═══════════════════════════════════════════════════════════════

/system identity set name=access-switch-04
/system clock set time-zone-name=Europe/Warsaw
/user set admin password=ZSE-BCU-2025!SecureP@ss
/ip service disable telnet,ftp,www-ssl
/ip service set ssh port=22 disabled=no
/ip service set winbox port=8291 disabled=no

/interface bridge remove [find name=bridge]
/interface bridge add name=bridge vlan-filtering=no comment="Main VLAN Bridge"

/interface bridge port add bridge=bridge interface=ether48 pvid=600 comment="Management Port"
/interface bridge port add bridge=bridge interface=ether1 pvid=110 comment="Mac Pro 01 - NIC2 (backup)"
/interface bridge port add bridge=bridge interface=ether2 pvid=110 comment="Mac Pro 02 - NIC2 (backup)"
/interface bridge port add bridge=bridge interface=ether3 pvid=110 comment="Mac Pro 03 - NIC2 (backup)"
/interface bridge port add bridge=bridge interface=ether4 pvid=110 comment="Mac Pro 04 - NIC2 (backup)"
/interface bridge port add bridge=bridge interface=ether5 pvid=110 comment="Mac Pro 05 - NIC2 (backup)"
/interface bridge port add bridge=bridge interface=ether6 pvid=110 comment="Mac Pro 06 - NIC2 (backup)"
/interface bridge port add bridge=bridge interface=ether7 pvid=110 comment="Mac Pro 07 - NIC2 (backup)"
/interface bridge port add bridge=bridge interface=ether8 pvid=110 comment="Mac Pro 08 - NIC2 (backup)"
/interface bridge port add bridge=bridge interface=ether9 pvid=110 comment="Mac Pro 09 - NIC2 (backup)"
/interface bridge port add bridge=bridge interface=sfp-sfpplus1 comment="Trunk to CORE"

/interface vlan add name=vlan-600 vlan-id=600 interface=bridge comment="Management"

/interface bridge vlan add bridge=bridge tagged=bridge,sfp-sfpplus1 untagged=ether48 vlan-ids=600 comment="Management VLAN"
/interface bridge vlan add bridge=bridge tagged=bridge,sfp-sfpplus1 untagged=ether1,ether2,ether3,ether4,ether5,ether6,ether7,ether8,ether9 vlan-ids=110 comment="K3s VLAN"

/ip address remove [find address~"192.168.88"]
/ip address add address=192.168.255.14/28 interface=vlan-600 comment="Management IP"
/ip route add gateway=192.168.255.1 comment="Default Gateway to CORE"
/ip dns set servers=8.8.8.8,8.8.4.4 allow-remote-requests=no

/ip neighbor discovery-settings set discover-interface-list=all protocol=cdp,lldp,mndp

/ip firewall filter add chain=input connection-state=established,related action=accept comment="Accept Established/Related"
/ip firewall filter add chain=input protocol=icmp action=accept comment="Accept ICMP"
/ip firewall filter add chain=input protocol=tcp dst-port=22 src-address=192.168.255.0/28 action=accept comment="SSH from Management"
/ip firewall filter add chain=input protocol=tcp dst-port=8291 src-address=192.168.255.0/28 action=accept comment="WinBox from Management"
/ip firewall filter add chain=input connection-state=invalid action=drop comment="Drop Invalid"
/ip firewall filter add chain=input protocol=tcp dst-port=22 connection-state=new src-address-list=ssh_blacklist action=drop comment="SSH Blacklist"
/ip firewall filter add chain=input protocol=tcp dst-port=22 connection-state=new action=add-src-to-address-list address-list=ssh_stage1 address-list-timeout=1m
/ip firewall filter add chain=input protocol=tcp dst-port=22 connection-state=new src-address-list=ssh_stage1 action=add-src-to-address-list address-list=ssh_blacklist address-list-timeout=1d comment="SSH Brute-Force Protection"
/ip firewall filter add chain=input action=drop comment="Drop Other Input"

/system ntp client set enabled=yes primary-ntp=pool.ntp.org secondary-ntp=time.google.com

/snmp set enabled=yes contact="admin@zsel.opole.pl" location="BCU Building - ACCESS-04 (Redundancy)"
/snmp community add name=public addresses=192.168.255.0/28 read-access=yes

/system logging add topics=system,info action=memory
/system logging add topics=critical,error,warning action=memory

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

# Uncomment after verification:
# /interface bridge set bridge vlan-filtering=yes

# ═══════════════════════════════════════════════════════════════
# END - ACCESS-SWITCH-04
# Role: Redundancy (Backup NICs for active-backup bonding)
# Note: These ports normally show LOW traffic (backup interfaces)
# ═══════════════════════════════════════════════════════════════
