# 📚 Network Configuration - Master Index

**Kompletne instrukcje konfiguracyjne dla wszystkich 5 switchy**  
**Projekt:** ZSEL K3s Cluster Infrastructure  
**Data:** 2025-11-27

> **🚀 Szybki Start:** Użyj gotowych plików .rsc → [configs/README.md](configs/README.md)  
> **🤖 Automatyczna Weryfikacja:** [AUTOMATION-TOPOLOGY-VERIFICATION.md](AUTOMATION-TOPOLOGY-VERIFICATION.md)

---

## 🎯 PLIK DOKUMENTACJI

Każdy switch ma dedykowany plik z PEŁNĄ konfiguracją:

| Switch | Plik | Rola | IP Address |
|--------|------|------|------------|
| **CORE-01** | [CONFIG-CORE-SWITCH-01.md](CONFIG-CORE-SWITCH-01.md) | Core router/gateway | 192.168.255.1/28 |
| **ACCESS-01** | [CONFIG-ACCESS-01.md](CONFIG-ACCESS-01.md) | Mac Pro 01-03 | 192.168.255.11/28 |
| **ACCESS-02** | [CONFIG-ACCESS-02.md](CONFIG-ACCESS-02.md) | Mac Pro 04-06 | 192.168.255.12/28 |
| **ACCESS-03** | [CONFIG-ACCESS-03.md](CONFIG-ACCESS-03.md) | Mac Pro 07-09 | 192.168.255.13/28 |
| **ACCESS-04** | [CONFIG-ACCESS-04.md](CONFIG-ACCESS-04.md) | Redundancy/backup | 192.168.255.14/28 |

---

## 🏗️ TOPOLOGIA FIZYCZNA

```
                                    [INTERNET]
                                        |
                                        | (ISP)
                                        |
                    ┌───────────────────┴────────────────────┐
                    │      CORE-SWITCH-01 (192.168.255.1)   │
                    │  - Internet gateway (NAT)              │
                    │  - VLAN routing (110, 600)             │
                    │  - BGP speaker (AS 65000)              │
                    │  - DHCP server                         │
                    │  - DNS forwarder                       │
                    └──┬─────────┬─────────┬─────────┬───────┘
                       │10Gbps   │10Gbps   │10Gbps   │10Gbps
         ┌─────────────┴────┐ ┌──┴─────┐ ┌─┴────────┐ ┌─┴─────────┐
         │  ACCESS-01       │ │ACCESS-02│ │ACCESS-03 │ │ACCESS-04  │
         │  (.11)           │ │ (.12)   │ │ (.13)    │ │ (.14)     │
         └─┬───┬───┬────────┘ └┬──┬──┬──┘ └┬──┬──┬───┘ └─┬─────────┘
           │   │   │           │  │  │     │  │  │       │(backup)
           │   │   │           │  │  │     │  │  │       │
        ┌──┴┐┌─┴┐┌─┴──┐     ┌──┴┐┌┴─┐┌┴──┐┌┴─┐┌┴─┐┌┴──┐   │
        │MP1││MP2││MP3│     │MP4││M5││M6││M7││M8││M9│   │
        │.11││.12││.13│     │.14││15││16││17││18││19│   │
        └─┬─┘└─┬─┘└─┬──┘     └──┬┘└┬─┘└┬──┘└┬─┘└┬─┘└┬──┘   │
          │    │    │           │  │   │    │   │   │      │
          └────┴────┴───────────┴──┴───┴────┴───┴───┴──────┘
                          (Backup interfaces)

MP = Mac Pro (K3s Node)
```

---

## 📊 ADDRESSING PLAN

### Management VLAN 600 (192.168.255.0/28)

| Device | IP Address | Interface | Purpose |
|--------|-----------|-----------|---------|
| CORE-01 | 192.168.255.1 | vlan-600 | Gateway |
| ACCESS-01 | 192.168.255.11 | vlan-600 | Management |
| ACCESS-02 | 192.168.255.12 | vlan-600 | Management |
| ACCESS-03 | 192.168.255.13 | vlan-600 | Management |
| ACCESS-04 | 192.168.255.14 | vlan-600 | Management |
| Laptop | 192.168.255.100 | - | Admin workstation |

**Available:** 192.168.255.2-10 (8 IPs reserved for expansion)

---

### K3s Cluster VLAN 110 (192.168.10.0/24)

#### Gateway
| Device | IP Address | Interface |
|--------|-----------|-----------|
| CORE-01 | 192.168.10.1 | vlan-110 |

#### K3s Masters
| Hostname | IP Address | MAC Address | Switch | Port |
|----------|-----------|-------------|--------|------|
| k3s-master-01 | 192.168.10.11 | XX:XX:XX:XX:XX:01 | ACCESS-01 | ether1 |
| k3s-master-02 | 192.168.10.12 | XX:XX:XX:XX:XX:02 | ACCESS-01 | ether2 |
| k3s-master-03 | 192.168.10.13 | XX:XX:XX:XX:XX:03 | ACCESS-01 | ether3 |

#### K3s Workers
| Hostname | IP Address | MAC Address | Switch | Port |
|----------|-----------|-------------|--------|------|
| k3s-worker-01 | 192.168.10.14 | XX:XX:XX:XX:XX:04 | ACCESS-02 | ether1 |
| k3s-worker-02 | 192.168.10.15 | XX:XX:XX:XX:XX:05 | ACCESS-02 | ether2 |
| k3s-worker-03 | 192.168.10.16 | XX:XX:XX:XX:XX:06 | ACCESS-02 | ether3 |
| k3s-worker-04 | 192.168.10.17 | XX:XX:XX:XX:XX:07 | ACCESS-03 | ether1 |
| k3s-worker-05 | 192.168.10.18 | XX:XX:XX:XX:XX:08 | ACCESS-03 | ether2 |
| k3s-worker-06 | 192.168.10.19 | XX:XX:XX:XX:XX:09 | ACCESS-03 | ether3 |

#### MetalLB Pools
| Pool | IP Range | Purpose |
|------|----------|---------|
| PROD | 192.168.10.20 - 192.168.10.51 | Production LoadBalancers (32 IPs) |
| DEV | 192.168.10.101 - 192.168.10.150 | Development LoadBalancers (50 IPs) |

#### DHCP Pool (Temporary)
| Pool | IP Range | Purpose |
|------|----------|---------|
| dhcp-k3s | 192.168.10.200 - 192.168.10.220 | Initial Mac Pro setup (21 IPs) |

---

## 🔀 ROUTING & BGP

### Static Routes
| Network | Gateway | Interface | Purpose |
|---------|---------|-----------|---------|
| 0.0.0.0/0 | ISP Gateway | ether1 | Default route (Internet) |
| 192.168.10.0/24 | - | vlan-110 | K3s cluster (directly connected) |
| 192.168.255.0/28 | - | vlan-600 | Management (directly connected) |

### BGP Configuration
| Parameter | CORE-01 (MikroTik) | K3s Masters (MetalLB) |
|-----------|-------------------|----------------------|
| AS Number | 65000 | 65001 |
| Router ID | 192.168.10.1 | 192.168.10.11-13 |
| Peers | 192.168.10.11-13 | 192.168.10.1 |
| Advertised Networks | - | MetalLB pools (.20-.51, .101-.150) |

**BGP Purpose:** MetalLB advertises LoadBalancer IPs to CORE router via BGP

---

## 🔥 FIREWALL RULES

### CORE-SWITCH-01 Firewall

#### INPUT Chain (Protect Router)
| Rule | Action | Source | Destination | Protocol | Port | Comment |
|------|--------|--------|-------------|----------|------|---------|
| 1 | ACCEPT | Any | Any | - | - | Established/Related |
| 2 | ACCEPT | Any | Any | ICMP | - | Ping |
| 3 | ACCEPT | 192.168.255.0/28 | Any | TCP | 22 | SSH from Management |
| 4 | ACCEPT | 192.168.255.0/28 | Any | TCP | 8291 | WinBox from Management |
| 5 | ACCEPT | 192.168.10.11-13 | Any | TCP | 179 | BGP from K3s masters |
| 6 | ACCEPT | 192.168.10.0/24 | Any | UDP | 67 | DHCP requests |
| 7 | DROP | ether1 | Any | - | - | Drop WAN input |
| 8 | DROP | Any | Any | - | - | Drop invalid |
| 9 | DROP | Any | Any | - | - | Drop other input |

#### FORWARD Chain (Inter-VLAN Routing)
| Rule | Action | Source | Destination | Interface | Comment |
|------|--------|--------|-------------|-----------|---------|
| 1 | ACCEPT | Any | Any | - | Established/Related |
| 2 | ACCEPT | 192.168.10.0/24 | Any | ether1 | K3s to Internet |
| 3 | ACCEPT | 192.168.255.0/28 | Any | - | Management full access |
| 4 | DROP | 192.168.10.0/24 | 192.168.255.0/28 | - | Block K3s → Management |
| 5 | DROP | Any | Any | - | Drop invalid |
| 6 | DROP | Any | Any | - | Drop other forward |

#### NAT Rules
| Chain | Action | Source | Out-Interface | Comment |
|-------|--------|--------|---------------|---------|
| srcnat | MASQUERADE | Any | ether1 | Internet NAT |

---

### ACCESS Switches Firewall

#### INPUT Chain (All Access Switches)
| Rule | Action | Source | Destination | Protocol | Port | Comment |
|------|--------|--------|-------------|----------|------|---------|
| 1 | ACCEPT | Any | Any | - | - | Established/Related |
| 2 | ACCEPT | Any | Any | ICMP | - | Ping |
| 3 | ACCEPT | 192.168.255.0/28 | Any | TCP | 22 | SSH from Management |
| 4 | ACCEPT | 192.168.255.0/28 | Any | TCP | 8291 | WinBox from Management |
| 5 | DROP | Any | Any | - | - | Drop invalid |
| 6 | DROP | Any | Any | - | - | Drop other input |

**Note:** Access switches są L2 only (pure switching), nie potrzebują FORWARD chain.

---

## 🔌 PORT USAGE SUMMARY

### CORE-SWITCH-01
| Port | VLAN | Purpose | Connected To |
|------|------|---------|--------------|
| ether1 | - | WAN | ISP Router (untagged) |
| ether2 | 600 | Management | Admin laptop (untagged) |
| sfp-sfpplus1 | 110, 600 | Trunk | ACCESS-01 (tagged) |
| sfp-sfpplus2 | 110, 600 | Trunk | ACCESS-02 (tagged) |
| sfp-sfpplus3 | 110, 600 | Trunk | ACCESS-03 (tagged) |
| sfp-sfpplus4 | 110, 600 | Trunk | ACCESS-04 (tagged) |

### ACCESS-01
| Port | VLAN | Purpose | Connected To |
|------|------|---------|--------------|
| ether1 | 110 | K3s | Mac Pro 01 - NIC1 (untagged) |
| ether2 | 110 | K3s | Mac Pro 02 - NIC1 (untagged) |
| ether3 | 110 | K3s | Mac Pro 03 - NIC1 (untagged) |
| ether48 | 600 | Management | Admin laptop (untagged) |
| sfp-sfpplus1 | 110, 600 | Trunk | CORE-01 (tagged) |

### ACCESS-02
| Port | VLAN | Purpose | Connected To |
|------|------|---------|--------------|
| ether1 | 110 | K3s | Mac Pro 04 - NIC1 (untagged) |
| ether2 | 110 | K3s | Mac Pro 05 - NIC1 (untagged) |
| ether3 | 110 | K3s | Mac Pro 06 - NIC1 (untagged) |
| ether48 | 600 | Management | Admin laptop (untagged) |
| sfp-sfpplus1 | 110, 600 | Trunk | CORE-01 (tagged) |

### ACCESS-03
| Port | VLAN | Purpose | Connected To |
|------|------|---------|--------------|
| ether1 | 110 | K3s | Mac Pro 07 - NIC1 (untagged) |
| ether2 | 110 | K3s | Mac Pro 08 - NIC1 (untagged) |
| ether3 | 110 | K3s | Mac Pro 09 - NIC1 (untagged) |
| ether48 | 600 | Management | Admin laptop (untagged) |
| sfp-sfpplus1 | 110, 600 | Trunk | CORE-01 (tagged) |

### ACCESS-04 (Redundancy)
| Port | VLAN | Purpose | Connected To |
|------|------|---------|--------------|
| ether1 | 110 | K3s Backup | Mac Pro 01 - NIC2 (untagged) |
| ether2 | 110 | K3s Backup | Mac Pro 02 - NIC2 (untagged) |
| ether3 | 110 | K3s Backup | Mac Pro 03 - NIC2 (untagged) |
| ether4 | 110 | K3s Backup | Mac Pro 04 - NIC2 (untagged) |
| ether5 | 110 | K3s Backup | Mac Pro 05 - NIC2 (untagged) |
| ether6 | 110 | K3s Backup | Mac Pro 06 - NIC2 (untagged) |
| ether7 | 110 | K3s Backup | Mac Pro 07 - NIC2 (untagged) |
| ether8 | 110 | K3s Backup | Mac Pro 08 - NIC2 (untagged) |
| ether9 | 110 | K3s Backup | Mac Pro 09 - NIC2 (untagged) |
| ether48 | 600 | Management | Admin laptop (untagged) |
| sfp-sfpplus1 | 110, 600 | Trunk | CORE-01 (tagged) |

---

## 📝 KONFIGURACJA KROK PO KROKU

### Dzień 1: Core Switch (6-8 godzin)

1. **Przygotowanie** (30 min)
   - Rozpakuj CORE-SWITCH-01
   - Podłącz ISP cable → ether1
   - Podłącz laptop → ether2
   - Laptop: Static IP 192.168.88.100/24

2. **Basic Configuration** (1h)
   - Login: http://192.168.88.1
   - Change password
   - Set hostname
   - Configure system services

3. **Internet Setup** (1h)
   - DHCP client na ether1 (lub static IP)
   - NAT masquerade
   - Test: `ping google.com`

4. **VLAN Configuration** (2h)
   - Create VLANs 110, 600
   - Configure bridge VLAN filtering
   - Set IP addresses
   - Default gateway setup

5. **DHCP Server** (1h)
   - Create DHCP pool dla VLAN 110
   - Configure network settings
   - Prepare static leases (MAC → IP mapping)

6. **Firewall & Security** (2h)
   - INPUT chain rules
   - FORWARD chain rules
   - SSH brute-force protection
   - Port scan detection

7. **BGP Configuration** (30 min)
   - Configure AS 65000
   - Add BGP peers (K3s masters)
   - Note: Peers will be DOWN until MetalLB deployed

8. **Monitoring** (30 min)
   - Enable SNMP
   - Configure logging
   - Setup NTP

9. **Backup** (15 min)
   - `/system backup save`
   - `/export file=...`
   - Download configs

**Checkpoint:** Internet działa, VLANs configured, firewall active

---

### Dzień 2: Access Switches (6-8 godzin)

**Sequential configuration (avoid IP conflicts!):**

1. **ACCESS-01** (1.5h)
   - Follow [CONFIG-ACCESS-01.md](CONFIG-ACCESS-01.md)
   - Change IP: 192.168.88.1 → 192.168.255.11
   - Connect trunk → CORE sfp-sfpplus1
   - Test: `ping 192.168.255.1`, `ping google.com`

2. **ACCESS-02** (1.5h)
   - Follow [CONFIG-ACCESS-02.md](CONFIG-ACCESS-02.md)
   - Change IP: 192.168.88.1 → 192.168.255.12
   - Connect trunk → CORE sfp-sfpplus2
   - Test connectivity

3. **ACCESS-03** (1.5h)
   - Follow [CONFIG-ACCESS-03.md](CONFIG-ACCESS-03.md)
   - Change IP: 192.168.88.1 → 192.168.255.13
   - Connect trunk → CORE sfp-sfpplus3
   - Test connectivity

4. **ACCESS-04** (1.5h)
   - Follow [CONFIG-ACCESS-04.md](CONFIG-ACCESS-04.md)
   - Change IP: 192.168.88.1 → 192.168.255.14
   - Connect trunk → CORE sfp-sfpplus4
   - Test connectivity

5. **Full Network Test** (1h)
   - Ping matrix: All switches ping each other
   - Internet test from all switches
   - VLAN verification
   - Trunk port verification

**Checkpoint:** All 5 switches reachable, VLANs active, Internet working

---

### Dzień 3: Verification & Documentation (2h)

1. **Network Verification** (1h)
   - Connectivity tests (all-to-all)
   - VLAN tests (correct tagging)
   - Firewall tests (rules active)
   - BGP ready (peers configured)

2. **Documentation Update** (30 min)
   - Document actual IP addresses
   - Update MAC addresses (if collected)
   - Create network diagram
   - Password documentation

3. **Backup All Configs** (30 min)
   - Download all `.backup` files
   - Download all `.rsc` files
   - Store in secure location
   - Test restore procedure

**Status:** 🎉 Network infrastructure 100% ready for servers!

---

## ✅ VERIFICATION CHECKLIST

### Pre-Mac Pro Connection

- [ ] All 5 switches powered ON and stable
- [ ] All management IPs reachable:
  - [ ] 192.168.255.1 (CORE-01)
  - [ ] 192.168.255.11 (ACCESS-01)
  - [ ] 192.168.255.12 (ACCESS-02)
  - [ ] 192.168.255.13 (ACCESS-03)
  - [ ] 192.168.255.14 (ACCESS-04)
- [ ] Internet working from all switches: `ping google.com`
- [ ] All trunk ports UP (10Gbps link)
- [ ] VLAN 110 configured on all switches
- [ ] VLAN 600 configured on all switches
- [ ] DHCP server ready on CORE (VLAN 110)
- [ ] BGP configured (peers DOWN - OK, waiting for MetalLB)
- [ ] Firewall rules active on CORE
- [ ] All configs backed up

### Post-Mac Pro Connection

- [ ] All 9 Mac Pro получили DHCP IP (192.168.10.200+)
- [ ] All Mac Pro can ping gateway (192.168.10.1)
- [ ] All Mac Pro can ping Internet (8.8.8.8)
- [ ] DNS working on Mac Pro (ping google.com)
- [ ] MAC addresses collected for static DHCP leases
- [ ] Static IPs assigned (192.168.10.11-19)
- [ ] Bonding working on all Mac Pro (both NICs UP)
- [ ] Failover test passed (primary → backup works)

---

## 🔧 QUICK TROUBLESHOOTING

### Cannot Ping Between Switches

**Check:**
```routeros
# On problematic switch:
/interface bridge vlan print
# Verify VLAN 600 tagged on trunk port

/interface ethernet monitor sfp-sfpplus1
# Verify: link-ok=yes, rate=10Gbps

/ip route print
# Verify: default route via 192.168.255.1
```

### No Internet from Access Switch

**Check:**
```routeros
# Ping gateway:
/ping 192.168.255.1
# If fails → trunk problem

# Ping Internet:
/ping 8.8.8.8
# If fails → check default route

# Check NAT on CORE:
ssh admin@192.168.255.1
/ip firewall nat print statistics
# Verify: packets increasing
```

### DHCP Not Working

**Check on CORE:**
```routeros
/ip dhcp-server print
# Verify: dhcp-k3s, interface=vlan-110, disabled=no

/ip dhcp-server lease print
# Check if Mac Pro MAC addresses visible

# Enable debug:
/system logging add topics=dhcp,debug action=memory
/log print
```

### BGP Not Establishing

**This is NORMAL until MetalLB is deployed!**

```routeros
# On CORE:
/routing bgp peer print status
# Expected: state=idle or connect (until K3s + MetalLB ready)

# BGP will establish only after:
# 1. K3s cluster installed
# 2. MetalLB deployed with BGP speaker
# 3. MetalLB configured with AS 65001
```

---

## 📋 PASSWORD REFERENCE

**⚠️ CRITICAL: Store this securely!**

| Device | Username | Password | IP Address |
|--------|----------|----------|------------|
| CORE-01 | admin | YourStrongPassword123! | 192.168.255.1 |
| ACCESS-01 | admin | YourStrongPassword123! | 192.168.255.11 |
| ACCESS-02 | admin | YourStrongPassword123! | 192.168.255.12 |
| ACCESS-03 | admin | YourStrongPassword123! | 192.168.255.13 |
| ACCESS-04 | admin | YourStrongPassword123! | 192.168.255.14 |

**⚠️ ZMIEŃ HASŁO przed produkcją!**

---

## 🎯 NEXT STEPS

Po ukończeniu konfiguracji sieci:

1. ✅ **Network Complete** - All 5 switches configured ✅
2. ⏭️ **Mac Pro Setup** - Follow [MAC-PRO-UBUNTU-INSTALL.md](MAC-PRO-UBUNTU-INSTALL.md)
3. ⏭️ **Node Configuration** - Use `mac-pro-ubuntu-installer.sh`
4. ⏭️ **K3s Installation** - Follow [ZERO-TO-PRODUCTION.md](ZERO-TO-PRODUCTION.md) Day 5
5. ⏭️ **MetalLB Deployment** - BGP will establish automatically
6. ⏭️ **Applications** - ArgoCD, FreeIPA, Keycloak, etc.

---

**Status:** 📚 Complete Configuration Guide  
**Last Updated:** 2025-11-27  
**Ready for:** Production Deployment 🚀
