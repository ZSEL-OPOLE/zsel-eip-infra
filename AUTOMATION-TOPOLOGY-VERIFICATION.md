# Automatyczna Weryfikacja Topologii Sieci K3s

## 📋 Przegląd

System automatycznej weryfikacji wykorzystuje **LLDP (Link Layer Discovery Protocol)** do wykrywania sąsiadów i weryfikacji poprawności połączeń trunk między switchami. Dzięki temu możesz **w 30 sekund** upewnić się, że wszystkie 5 switchy są poprawnie podłączone zgodnie z planem.

## 🎯 Co weryfikujemy?

✅ **Dostępność wszystkich 5 switchy** (ping test)  
✅ **Poprawność połączeń trunk** (LLDP discovery)  
✅ **Port mapping** (czy kabel wchodzi we właściwy port)  
✅ **Identyfikacja urządzeń** (czy właściwy switch jest podłączony)  
✅ **Detekcja nieoczekiwanych połączeń**  
✅ **Kompletność topologii**

## 🔧 Wymagania

### 1. Instalacja modułu Posh-SSH

```powershell
# Sprawdź czy masz moduł
Get-Module -ListAvailable -Name Posh-SSH

# Jeśli brak, zainstaluj (wymaga uprawnień administratora)
Install-Module -Name Posh-SSH -Force -Scope CurrentUser

# Zaimportuj moduł
Import-Module Posh-SSH
```

### 2. Przygotowanie laptopa

**KROK 1:** Podłącz laptop do dowolnego portu **ether48** (Management) na dowolnym switchu

**KROK 2:** Ustaw statyczny IP na karcie sieciowej:
```
IP:      192.168.255.100
Maska:   255.255.255.240  (czyli /28)
Gateway: 192.168.255.1
DNS:     8.8.8.8, 8.8.4.4
```

**KROK 3:** Sprawdź łączność z CORE:
```powershell
ping 192.168.255.1
```

### 3. Zaczekaj na LLDP discovery

⚠️ **WAŻNE:** Po podłączeniu kabli trunk odczekaj **60-90 sekund** przed uruchomieniem weryfikacji!

LLDP wymaga czasu na wykrycie sąsiadów. Możesz sprawdzić status na dowolnym switchu:

```routeros
# Zaloguj się przez WinBox lub SSH
/ip neighbor print detail

# Powinieneś zobaczyć listę sąsiadów
```

## 🚀 Podstawowe użycie

### Scenariusz 1: Szybka weryfikacja (tylko terminal)

```powershell
cd C:\Users\kolod\Desktop\LKP\05_BCU\INFRA\zsel-eip-infra\scripts
.\Verify-NetworkTopology.ps1
```

**Output przykład:**
```
═══════════════════════════════════════════════════════════════
  Network Topology Verification - K3s Infrastructure
═══════════════════════════════════════════════════════════════

[1/5] Sprawdzanie wymagań...
✓ Moduł Posh-SSH dostępny

[2/5] Wczytywanie oczekiwanej topologii...
✓ Topologia wczytana (8 oczekiwanych połączeń)

[3/5] Testowanie połączenia z switchami...
  Testing CORE-SWITCH-01 (192.168.255.1)... ✓ (3ms)
  Testing ACCESS-SWITCH-01 (192.168.255.11)... ✓ (2ms)
  Testing ACCESS-SWITCH-02 (192.168.255.12)... ✓ (2ms)
  Testing ACCESS-SWITCH-03 (192.168.255.13)... ✓ (2ms)
  Testing ACCESS-SWITCH-04 (192.168.255.14)... ✓ (2ms)

[4/5] Zbieranie danych LLDP...
  Connecting to CORE-SWITCH-01... ✓
  Collecting LLDP neighbors from CORE-SWITCH-01... ✓ (4 neighbors)
  Connecting to ACCESS-SWITCH-01... ✓
  Collecting LLDP neighbors from ACCESS-SWITCH-01... ✓ (1 neighbors)
  [...]

[5/5] Weryfikacja topologii...

═══════════════════════════════════════════════════════════════
  WYNIKI WERYFIKACJI
═══════════════════════════════════════════════════════════════

Switche osiągalne: 5/5
Prawidłowe połączenia: 8
Brakujące połączenia: 0
Nieoczekiwane połączenia: 0

✓ PRAWIDŁOWE POŁĄCZENIA:
  CORE-SWITCH-01 [sfp-sfpplus1] ←→ ACCESS-SWITCH-01 [sfp-sfpplus1]
  CORE-SWITCH-01 [sfp-sfpplus2] ←→ ACCESS-SWITCH-02 [sfp-sfpplus1]
  CORE-SWITCH-01 [sfp-sfpplus3] ←→ ACCESS-SWITCH-03 [sfp-sfpplus1]
  CORE-SWITCH-01 [sfp-sfpplus4] ←→ ACCESS-SWITCH-04 [sfp-sfpplus1]
  ACCESS-SWITCH-01 [sfp-sfpplus1] ←→ CORE-SWITCH-01 [sfp-sfpplus1]
  [...]

═══════════════════════════════════════════════════════════════
  ✓ TOPOLOGIA PRAWIDŁOWA - Sieć gotowa do użytku!
═══════════════════════════════════════════════════════════════
```

### Scenariusz 2: Weryfikacja z raportem HTML

```powershell
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
.\Verify-NetworkTopology.ps1 -ExportReport "C:\Reports\topology-$timestamp.html"
```

Otworzy się piękny raport HTML z:
- 📊 Podsumowanie (ile switchy online, ile połączeń OK)
- 🌐 Tabela dostępności każdego switcha
- ✅ Lista prawidłowych połączeń
- ❌ Lista brakujących połączeń (jeśli są)
- ⚠️ Lista nieoczekiwanych połączeń

### Scenariusz 3: Własne hasło

```powershell
.\Verify-NetworkTopology.ps1 -Username "admin" -Password "MojeHaslo123!"
```

## 📁 Pliki w systemie

```
zsel-eip-infra/
├── configs/
│   ├── core-switch-01.rsc          ← LLDP enabled
│   ├── access-switch-01.rsc        ← LLDP enabled
│   ├── access-switch-02.rsc        ← LLDP enabled
│   ├── access-switch-03.rsc        ← LLDP enabled
│   ├── access-switch-04.rsc        ← LLDP enabled
│   └── README.md
└── scripts/
    ├── Verify-NetworkTopology.ps1  ← Główny skrypt
    └── expected-topology.json       ← Oczekiwana topologia
```

## 🎨 Przykładowe scenariusze

### A) Pierwszy deploy - dzień 1

```powershell
# 1. Import core-switch-01.rsc do CORE
# (WinBox: Files → drag-drop → New Terminal → /import core-switch-01.rsc)

# 2. Zmień IP laptopa na 192.168.255.100/28

# 3. Test CORE
ping 192.168.255.1

# 4. Import access-switch-01.rsc do ACCESS-01
# 5. Podłącz trunk SFP+ między CORE (sfp-sfpplus1) ←→ ACCESS-01 (sfp-sfpplus1)
# 6. Zaczekaj 60 sekund

# 7. Weryfikacja po pierwszym switchu
.\Verify-NetworkTopology.ps1

# Output: 2/5 switchy online, 2/8 połączenia OK (CORE ←→ ACCESS-01)
```

### B) Deploy wszystkich switchy - dzień 2

```powershell
# Po zaimportowaniu wszystkich 5 .rsc i podłączeniu wszystkich trunk:

# 1. Zaczekaj 90 sekund
Start-Sleep -Seconds 90

# 2. Pełna weryfikacja z raportem
.\Verify-NetworkTopology.ps1 -ExportReport "C:\Reports\topology-final.html"

# Oczekiwany output:
# Switche osiągalne: 5/5
# Prawidłowe połączenia: 8
# Brakujące połączenia: 0
# ✓ TOPOLOGIA PRAWIDŁOWA
```

### C) Troubleshooting - znalezienie błędów

```powershell
.\Verify-NetworkTopology.ps1

# Przykład outputu z problemem:
# Switche osiągalne: 5/5
# Prawidłowe połączenia: 6
# Brakujące połączenia: 2
#
# ✗ BRAKUJĄCE POŁĄCZENIA:
#   CORE-SWITCH-01 [sfp-sfpplus3] -/→ ACCESS-SWITCH-03 [sfp-sfpplus1]
#   ACCESS-SWITCH-03 [sfp-sfpplus1] -/→ CORE-SWITCH-01 [sfp-sfpplus3]

# Diagnoza: Kabel trunk ACCESS-03 ←→ CORE nie jest podłączony lub SFP+ martwy
```

### D) Wykrywanie nieprawidłowych połączeń

```powershell
.\Verify-NetworkTopology.ps1

# Przykład outputu z błędnym kablem:
# ⚠ NIEOCZEKIWANE POŁĄCZENIA:
#   CORE-SWITCH-01 [sfp-sfpplus2] ←→ ACCESS-SWITCH-03 [sfp-sfpplus1]
#
# Oczekiwane:
#   CORE-SWITCH-01 [sfp-sfpplus2] ←→ ACCESS-SWITCH-02 [sfp-sfpplus1]

# Diagnoza: Kabel z ACCESS-03 jest podłączony do portu ACCESS-02 na CORE
```

## 🔍 Ręczna weryfikacja LLDP (bez skryptu)

Jeśli wolisz sprawdzić ręcznie przez WinBox lub SSH:

```routeros
# Zaloguj się do CORE-SWITCH-01

# Sprawdź wszystkich sąsiadów
/ip neighbor print detail

# Oczekiwany output:
# 0   interface=sfp-sfpplus1 identity="ACCESS-SWITCH-01" interface-name="sfp-sfpplus1"
# 1   interface=sfp-sfpplus2 identity="ACCESS-SWITCH-02" interface-name="sfp-sfpplus1"
# 2   interface=sfp-sfpplus3 identity="ACCESS-SWITCH-03" interface-name="sfp-sfpplus1"
# 3   interface=sfp-sfpplus4 identity="ACCESS-SWITCH-04" interface-name="sfp-sfpplus1"

# Sprawdź konkretny port
/ip neighbor print where interface=sfp-sfpplus1

# Sprawdź czy LLDP działa
/ip neighbor discovery-settings print
# discover-interface-list: all
# protocol: cdp,lldp,mndp
```

## 📊 Interpretacja wyników

### ✅ Sukces (100% poprawne)

```
Switche osiągalne: 5/5
Prawidłowe połączenia: 8
Brakujące połączenia: 0
Nieoczekiwane połączenia: 0

✓ TOPOLOGIA PRAWIDŁOWA - Sieć gotowa do użytku!
```

**Akcja:** Możesz przejść do podłączania Mac Pro serverów! 🎉

---

### ⚠️ Częściowy sukces (some connections missing)

```
Switche osiągalne: 5/5
Prawidłowe połączenia: 6
Brakujące połączenia: 2
Nieoczekiwane połączenia: 0

✗ TOPOLOGIA NIEPRAWIDŁOWA - Sprawdź brakujące połączenia!

✗ BRAKUJĄCE POŁĄCZENIA:
  CORE-SWITCH-01 [sfp-sfpplus4] -/→ ACCESS-SWITCH-04 [sfp-sfpplus1]
  ACCESS-SWITCH-04 [sfp-sfpplus1] -/→ CORE-SWITCH-01 [sfp-sfpplus4]
```

**Diagnoza:**
- Kabel trunk między CORE i ACCESS-04 nie jest podłączony
- LUB moduł SFP+ jest martwy
- LUB port jest disabled

**Akcja:**
1. Sprawdź fizyczne połączenie kabla
2. Sprawdź czy SFP+ świeci się (LED)
3. Sprawdź status portu: `/interface print where name=sfp-sfpplus4`
4. Sprawdź czy port nie jest disabled: `/interface enable sfp-sfpplus4`

---

### ❌ Switch offline

```
Switche osiągalne: 4/5
Prawidłowe połączenia: 6
Brakujące połączenia: 2

Testing CORE-SWITCH-01 (192.168.255.1)... ✓ (3ms)
Testing ACCESS-SWITCH-01 (192.168.255.11)... ✓ (2ms)
Testing ACCESS-SWITCH-02 (192.168.255.12)... ✓ (2ms)
Testing ACCESS-SWITCH-03 (192.168.255.13)... ✗ Brak połączenia
Testing ACCESS-SWITCH-04 (192.168.255.14)... ✓ (2ms)
```

**Diagnoza:**
- ACCESS-SWITCH-03 jest offline
- LUB konfiguracja nie została zaimportowana
- LUB trunk cable między CORE i ACCESS-03 jest odłączony

**Akcja:**
1. Sprawdź czy ACCESS-03 jest włączony (LED power)
2. Podłącz laptop bezpośrednio do ACCESS-03 ether48
3. Sprawdź czy ma IP 192.168.255.13: WinBox → IP → Addresses
4. Sprawdź czy trunk jest podłączony: WinBox → Interfaces

---

### 🔀 Nieprawidłowe połączenie (wrong port)

```
Switche osiągalne: 5/5
Prawidłowe połączenia: 6
Brakujące połączenia: 2
Nieoczekiwane połączenia: 2

⚠ NIEOCZEKIWANE POŁĄCZENIA:
  CORE-SWITCH-01 [sfp-sfpplus2] ←→ ACCESS-SWITCH-03 [sfp-sfpplus1]
  CORE-SWITCH-01 [sfp-sfpplus3] ←→ ACCESS-SWITCH-02 [sfp-sfpplus1]

✗ BRAKUJĄCE POŁĄCZENIA:
  CORE-SWITCH-01 [sfp-sfpplus2] -/→ ACCESS-SWITCH-02 [sfp-sfpplus1]
  CORE-SWITCH-01 [sfp-sfpplus3] -/→ ACCESS-SWITCH-03 [sfp-sfpplus1]
```

**Diagnoza:**
- Kable są zamienione: ACCESS-02 i ACCESS-03 mają porty na CORE podłączone na odwrót
- Switch z sfp2 powinien być ACCESS-02, ale jest ACCESS-03

**Akcja:**
1. Zamień kable na CORE:
   - Odłącz kabel z sfp-sfpplus2
   - Odłącz kabel z sfp-sfpplus3
   - Podłącz ACCESS-02 do sfp-sfpplus2
   - Podłącz ACCESS-03 do sfp-sfpplus3
2. Zaczekaj 60 sekund (LLDP rediscovery)
3. Uruchom weryfikację ponownie

## 🛠️ Troubleshooting

### Problem: "Moduł Posh-SSH nie jest zainstalowany"

```powershell
# Rozwiązanie 1: Install dla bieżącego użytkownika
Install-Module -Name Posh-SSH -Force -Scope CurrentUser

# Rozwiązanie 2: Install globalnie (wymaga admin)
Install-Module -Name Posh-SSH -Force

# Rozwiązanie 3: Ręczny import
Import-Module Posh-SSH
```

### Problem: "Cannot connect to 192.168.255.1"

**Sprawdź:**
1. Czy laptop ma IP 192.168.255.100/28?
   ```powershell
   ipconfig
   # Powinieneś zobaczyć: 192.168.255.100, Mask: 255.255.255.240
   ```

2. Czy kabel jest podłączony do ether48 (Management)?

3. Czy CORE ma poprawny IP?
   ```routeros
   # Na CORE przez WinBox:
   /ip address print
   # Powinieneś zobaczyć: 192.168.255.1/28 interface=vlan-600
   ```

### Problem: "SSH failed" dla wszystkich switchy

**Możliwe przyczyny:**
1. **Nieprawidłowe hasło:**
   ```powershell
   .\Verify-NetworkTopology.ps1 -Password "TwojeHaslo"
   ```

2. **SSH disabled na switchach:**
   ```routeros
   # Na każdym switchu:
   /ip service print
   # ssh powinno być enabled
   
   # Jeśli disabled:
   /ip service enable ssh
   ```

3. **Firewall blokuje SSH:**
   ```routeros
   # Sprawdź regułę firewall:
   /ip firewall filter print
   # Powinna być reguła: src-address=192.168.255.0/28 dst-port=22 action=accept
   ```

### Problem: "No LLDP neighbors found"

**Rozwiązanie:**
1. Zaczekaj dłużej (90 sekund zamiast 60)
2. Sprawdź czy LLDP jest enabled:
   ```routeros
   /ip neighbor discovery-settings print
   # protocol: cdp,lldp,mndp
   # discover-interface-list: all
   ```

3. Sprawdź czy porty trunk są UP:
   ```routeros
   /interface print where name~"sfp"
   # Wszystkie sfp-sfpplus powinny mieć status R (running)
   ```

4. Sprawdź czy kable są poprawnie podłączone (LED świeci)

### Problem: expected-topology.json not found

```powershell
# Skrypt używa domyślnej topologii wbudowanej w kod
# Ale możesz ręcznie skopiować expected-topology.json do katalogu scripts/

# Sprawdź czy plik istnieje:
Test-Path "C:\Users\kolod\Desktop\LKP\05_BCU\INFRA\zsel-eip-infra\scripts\expected-topology.json"

# Jeśli FALSE, skopiuj z repozytorium
```

## 📋 Checklist przed weryfikacją

- [ ] **Posh-SSH zainstalowany:** `Get-Module -ListAvailable -Name Posh-SSH`
- [ ] **Laptop w Management VLAN:** IP = 192.168.255.100/28
- [ ] **Wszystkie 5 switchy włączone:** LEDs power ON
- [ ] **Wszystkie .rsc zaimportowane:** 5× import completed
- [ ] **VLAN filtering enabled:** `/interface bridge set bridge vlan-filtering=yes`
- [ ] **Trunk cables podłączone:** 4× SFP+ DAC/Fiber cables
- [ ] **LLDP discovery czas:** Odczekano 60-90 sekund
- [ ] **Ping CORE działa:** `ping 192.168.255.1`

## 🎯 Kiedy uruchamiać weryfikację?

### ✅ Day 1 - Po imporcie CORE + ACCESS-01
```powershell
.\Verify-NetworkTopology.ps1
# Oczekiwane: 2/5 switchy, 2/8 połączeń
```

### ✅ Day 2 - Po każdym dodaniu switcha
```powershell
# Po ACCESS-02:
.\Verify-NetworkTopology.ps1
# Oczekiwane: 3/5 switchy, 4/8 połączeń

# Po ACCESS-03:
.\Verify-NetworkTopology.ps1
# Oczekiwane: 4/5 switchy, 6/8 połączeń

# Po ACCESS-04:
.\Verify-NetworkTopology.ps1 -ExportReport "C:\Reports\topology-final.html"
# Oczekiwane: 5/5 switchy, 8/8 połączeń ✓
```

### ✅ Przed podłączeniem Mac Pro
```powershell
# Ostateczna weryfikacja przed serwerami
.\Verify-NetworkTopology.ps1 -ExportReport "C:\Reports\topology-before-servers.html"

# MUSI pokazać:
# ✓ TOPOLOGIA PRAWIDŁOWA - Sieć gotowa do użytku!
```

### ✅ Po zmianach w okablowaniu
```powershell
# Jeśli zmieniłeś kable trunk lub SFP+ moduły:
Start-Sleep -Seconds 90  # Odczekaj LLDP discovery
.\Verify-NetworkTopology.ps1
```

## 🚀 Quick Reference

```powershell
# 1. PODSTAWOWA WERYFIKACJA
cd C:\Users\kolod\Desktop\LKP\05_BCU\INFRA\zsel-eip-infra\scripts
.\Verify-NetworkTopology.ps1

# 2. Z RAPORTEM HTML
.\Verify-NetworkTopology.ps1 -ExportReport "C:\Reports\topology.html"

# 3. WŁASNE HASŁO
.\Verify-NetworkTopology.ps1 -Password "MojeHaslo"

# 4. WSZYSTKIE PARAMETRY
.\Verify-NetworkTopology.ps1 `
    -Username "admin" `
    -Password "ZSE-BCU-2025!SecureP@ss" `
    -ExpectedTopologyFile ".\expected-topology.json" `
    -ExportReport "C:\Reports\topology-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
```

## 📚 Związane dokumenty

- `configs/README.md` - Import .rsc files workflow
- `NETWORK-CONFIG-INDEX.md` - Architektura sieci
- `ZERO-TO-PRODUCTION.md` - Pełny deployment timeline
- `expected-topology.json` - Definicja oczekiwanej topologii

## 💡 Pro Tips

1. **Zawsze zapisuj raport HTML** po finalnej weryfikacji - przyda się do dokumentacji
2. **Uruchamiaj weryfikację regularnie** - nawet jeśli "nic się nie zmieniło"
3. **Używaj skryptu przed każdym maintenance** - upewnij się że wracasz do dobrej topologii
4. **Trzymaj laptop w VLAN 600** - możesz się podłączyć do dowolnego ether48 na dowolnym switchu
5. **Etykietuj kable** - po weryfikacji oznacz każdy kabel trunk (np. "CORE-sfp1 ←→ ACCESS-01-sfp1")

## ❓ FAQ

**Q: Ile trwa pełna weryfikacja?**  
A: 30-60 sekund dla wszystkich 5 switchy (zależy od SSH response time)

**Q: Czy mogę uruchomić skrypt z Windows bez PowerShell?**  
A: Nie, wymaga PowerShell 5.1+ i Posh-SSH module

**Q: Czy mogę zmodyfikować expected-topology.json?**  
A: Tak, jeśli zmienisz fizyczną topologię (inne porty SFP+), edytuj JSON

**Q: Co jeśli mam tylko 3 switche zamiast 5?**  
A: Skrypt pokaże 2 switche offline - to normalne, dopóki nie dodasz pozostałych

**Q: Czy mogę użyć tego do weryfikacji 57-switch BCU network?**  
A: Tak, ale musisz rozszerzyć `expected-topology.json` i dodać nowe IP do `$switches` array

---

**🎓 Stworzone przez:** ZSE-BCU Infrastructure Team  
**📅 Data:** 2025-01-27  
**📌 Wersja:** 1.0  
**🔧 Dla:** K3s Infrastructure (5 switches, 9 Mac Pro servers)
