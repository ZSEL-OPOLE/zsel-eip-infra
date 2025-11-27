# ═══════════════════════════════════════════════════════════════
# MikroTik RouterOS Configuration Files - README
# Project: BCU ZSE Opole - Network Infrastructure
# Date: 2025-11-27
# ═══════════════════════════════════════════════════════════════

> **🔥 NOWOŚĆ:** Automatyczna weryfikacja topologii!  
> Zobacz: [AUTOMATION-TOPOLOGY-VERIFICATION.md](../AUTOMATION-TOPOLOGY-VERIFICATION.md)

## 📁 Zawartość Katalogu

Ten katalog zawiera **gotowe pliki konfiguracyjne RouterOS (.rsc)** dla wszystkich 5 switchy w infrastrukturze K3s:

| Plik | Urządzenie | Rola | Management IP |
|------|------------|------|---------------|
| `core-switch-01.rsc` | CORE-SWITCH-01 | Core router/gateway | 192.168.255.1/28 |
| `access-switch-01.rsc` | ACCESS-SWITCH-01 | Mac Pro 01-03 (masters) | 192.168.255.11/28 |
| `access-switch-02.rsc` | ACCESS-SWITCH-02 | Mac Pro 04-06 (workers) | 192.168.255.12/28 |
| `access-switch-03.rsc` | ACCESS-SWITCH-03 | Mac Pro 07-09 (workers) | 192.168.255.13/28 |
| `access-switch-04.rsc` | ACCESS-SWITCH-04 | Redundancy (backup NICs) | 192.168.255.14/28 |

---

## 🚀 Jak Używać (Import Method)

### Metoda 1: WinBox Import (Najłatwiejsza)

1. **Factory Reset urządzenia:**
   ```
   [System] → [Reset Configuration] → [No Default Configuration] → [Reset]
   ```

2. **Połącz się z urządzeniem:**
   ```
   - Laptop → ether48 (dla ACCESS switches)
   - Laptop → ether2 (dla CORE)
   - IP Laptop: 192.168.88.100/24
   - WinBox: Connect to 192.168.88.1
   ```

3. **Import pliku .rsc:**
   ```
   WinBox → [Files] → Drag & Drop plik .rsc
   [New Terminal] → Wpisz:
   /import core-switch-01.rsc
   ```

4. **Poczekaj na zakończenie importu** (kilka sekund)

5. **Zmień IP laptop** zgodnie z nowym management IP:
   ```powershell
   # Dla CORE:
   Remove-NetIPAddress -InterfaceAlias "Ethernet" -Confirm:$false
   New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.255.100 -PrefixLength 28 -DefaultGateway 192.168.255.1
   
   # Lub dla innych switchy podobnie (subnet 192.168.255.0/28)
   ```

6. **Reconnect via WinBox** (nowy IP: 192.168.255.x)

7. **Enable VLAN filtering:**
   ```routeros
   /interface bridge set bridge vlan-filtering=yes
   ```

8. **Backup config:**
   ```routeros
   /system backup save name=configured-device
   /export file=configured-device
   ```

---

### Metoda 2: Terminal Copy-Paste

1. **Połącz się przez WinBox/WebFig**

2. **Otwórz Terminal** ([New Terminal])

3. **Otwórz plik .rsc** w edytorze tekstu (np. Notepad++)

4. **Kopiuj całość** (Ctrl+A, Ctrl+C)

5. **Wklej w Terminal** (Ctrl+V lub prawy klik → Paste)

6. **Poczekaj na wykonanie** wszystkich komend

7. **Wykonaj kroki 5-8 z Metody 1**

---

## ⚙️ Kolejność Konfiguracji (WAŻNE!)

**Konfiguruj w tej kolejności** (aby uniknąć konfliktów IP):

```
Day 1:
1. CORE-SWITCH-01 (core-switch-01.rsc)
   - Test: ping google.com
   
Day 2:
2. ACCESS-SWITCH-01 (access-switch-01.rsc)
   - Test: ping 192.168.255.1, ping google.com
   
3. ACCESS-SWITCH-02 (access-switch-02.rsc)
   - Test: ping 192.168.255.1, ping google.com
   
4. ACCESS-SWITCH-03 (access-switch-03.rsc)
   - Test: ping 192.168.255.1, ping google.com
   
5. ACCESS-SWITCH-04 (access-switch-04.rsc)
   - Test: ping 192.168.255.1, ping google.com

Day 2 (End):
6. Verify all-to-all connectivity
   - Ping matrix: wszystkie switche ping siebie nawzajem
```

---

## 🔐 Domyślne Hasło (ZMIEŃ TO!)

Wszystkie pliki .rsc używają tego samego hasła:

```
Username: admin
Password: ZSE-BCU-2025!SecureP@ss
```

**⚠️ KRYTYCZNE: Zmień to hasło przed produkcją!**

```routeros
/user set admin password=TwojeMocneHaslo123!@#
```

---

## 📊 Architektura Sieci

### VLAN Configuration

| VLAN ID | Przeznaczenie | Sieć | Gateway |
|---------|---------------|------|---------|
| 110 | K3s Cluster | 192.168.10.0/24 | 192.168.10.1 |
| 600 | Management | 192.168.255.0/28 | 192.168.255.1 |

### Port Assignments

**CORE-SWITCH-01:**
- `ether1` = WAN (ISP uplink)
- `ether2` = Management (untagged VLAN 600)
- `sfp-sfpplus1-4` = Trunk to ACCESS switches (tagged 110, 600)

**ACCESS-SWITCH-01/02/03:**
- `ether1-3` = Mac Pro (untagged VLAN 110)
- `ether48` = Management (untagged VLAN 600)
- `sfp-sfpplus1` = Trunk to CORE (tagged 110, 600)

**ACCESS-SWITCH-04:**
- `ether1-9` = Mac Pro backup NICs (untagged VLAN 110)
- `ether48` = Management (untagged VLAN 600)
- `sfp-sfpplus1` = Trunk to CORE (tagged 110, 600)

---

## ✅ Verification Steps (After Each Switch)

### Quick Manual Verification (per switch)

```routeros
# 1. Test Internet
/ping 8.8.8.8 count=5
/ping google.com count=5

# 2. Check VLAN configuration
/interface vlan print
/interface bridge vlan print

# 3. Check IP addresses
/ip address print

# 4. Check default route
/ip route print

# 5. Check firewall
/ip firewall filter print statistics

# 6. Check NTP sync
/system clock print
/system ntp client print

# 7. Check LLDP neighbors (trunk connections)
/ip neighbor print detail

# 8. For CORE only - check DHCP
/ip dhcp-server lease print

# 8. For CORE only - check BGP (będzie DOWN do momentu MetalLB)
/routing bgp peer print status
```

### 🤖 Automated Full Network Verification

**Szybka weryfikacja całej topologii (wszystkie 5 switchy):**

```powershell
# Z laptopa podłączonego do Management VLAN 600:
cd C:\Users\kolod\Desktop\LKP\05_BCU\INFRA\zsel-eip-infra\scripts
.\Verify-NetworkTopology.ps1

# Z raportem HTML:
.\Verify-NetworkTopology.ps1 -ExportReport "C:\Reports\topology.html"
```

**Co sprawdza:**
- ✅ Dostępność wszystkich 5 switchy (ping test)
- ✅ Poprawność połączeń trunk (LLDP)
- ✅ Port mapping (czy właściwe kable w właściwych portach)
- ✅ Detekcja nieprawidłowych połączeń

**Więcej:** [AUTOMATION-TOPOLOGY-VERIFICATION.md](../AUTOMATION-TOPOLOGY-VERIFICATION.md)

---

## 🔧 Troubleshooting

### Problem: Nie mogę połączyć się po imporcie

**Rozwiązanie:**
```
1. Zmień IP laptop na 192.168.255.100/28
2. Gateway: 192.168.255.1
3. Reconnect do nowego IP (192.168.255.x)
4. Sprawdź czy VLAN filtering enabled (może być wyłączone)
```

### Problem: Brak Internetu na ACCESS switch

**Rozwiązanie:**
```routeros
# Sprawdź default route:
/ip route print
# Powinien być: 0.0.0.0/0 via 192.168.255.1

# Ping gateway:
/ping 192.168.255.1

# Sprawdź trunk port:
/interface ethernet monitor sfp-sfpplus1
# Powinno być: link-ok=yes
```

### Problem: VLAN nie działa

**Rozwiązanie:**
```routeros
# Sprawdź czy VLAN filtering włączony:
/interface bridge print
# Powinno być: vlan-filtering=yes

# Jeśli nie, włącz:
/interface bridge set bridge vlan-filtering=yes

# Sprawdź VLAN membership:
/interface bridge vlan print
```

---

## 📝 Modyfikacja Konfiguracji

### Zmiana Hasła Admin

```routeros
/user set admin password=NoweHaslo123!
```

### Dodanie Static DHCP Lease (na CORE)

```routeros
/ip dhcp-server lease add address=192.168.10.11 mac-address=AA:BB:CC:DD:EE:01 server=dhcp-k3s comment="k3s-master-01"
```

### Zmiana ISP Uplink (Static IP)

```routeros
# Usuń DHCP client:
/ip dhcp-client remove [find interface=ether1]

# Dodaj static IP:
/ip address add address=<ISP_IP>/29 interface=ether1 comment="ISP Static IP"
/ip route add gateway=<ISP_GW> comment="ISP Gateway"
```

---

## 🎯 Next Steps

Po skonfigurowaniu wszystkich 5 switchy:

1. ✅ **Network Complete** - Wszystkie switche skonfigurowane
2. ⏭️ **Physical Connections** - Podłącz trunk cables (fiber/DAC)
3. ⏭️ **Full Network Test** - Ping matrix (all-to-all)
4. ⏭️ **Mac Pro Setup** - Podłącz serwery do sieci
5. ⏭️ **DHCP MAC Collection** - Zbierz MAC addresses
6. ⏭️ **Static Leases** - Skonfiguruj static DHCP na CORE
7. ⏭️ **K3s Installation** - Follow [ZERO-TO-PRODUCTION.md](../ZERO-TO-PRODUCTION.md)

---

## 📚 Related Documentation

- [ZERO-TO-PRODUCTION.md](../ZERO-TO-PRODUCTION.md) - Complete deployment guide
- [NETWORK-CONFIG-INDEX.md](../NETWORK-CONFIG-INDEX.md) - Network architecture overview
- [MAC-PRO-UBUNTU-INSTALL.md](../MAC-PRO-UBUNTU-INSTALL.md) - Server installation guide
- [CONFIG-CORE-SWITCH-01.md](../CONFIG-CORE-SWITCH-01.md) - Detailed CORE configuration docs
- [CONFIG-ACCESS-01.md](../CONFIG-ACCESS-01.md) - Detailed ACCESS configuration docs

---

## ⚠️ Important Notes

1. **VLAN Filtering:** Zostaje wyłączone w .rsc aby nie rozłączyć połączenia podczas importu. Enable manually po imporcie!

2. **BGP Peers:** Będą w stanie DOWN/IDLE dopóki nie wdepożysz MetalLB na K3s. To normalne!

3. **DHCP Static Leases:** Są zakomentowane w core-switch-01.rsc. Odkomentuj po zebraniu MAC addresses.

4. **Password Security:** Zmień domyślne hasło natychmiast po pierwszym logowaniu!

5. **Backup:** Zawsze rób backup po każdej zmianie konfiguracji!

---

**Status:** 🟢 READY FOR DEPLOYMENT  
**Last Updated:** 2025-11-27  
**Author:** ZSE BCU Infrastructure Team
