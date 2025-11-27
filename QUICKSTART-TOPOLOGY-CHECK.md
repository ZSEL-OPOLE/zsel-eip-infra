# 🚀 Quick Start - Weryfikacja Topologii Sieci

**Czas wykonania:** 2 minuty  
**Cel:** Sprawdzenie czy wszystkie 5 switchy są poprawnie połączone

---

## ⚡ Ultra-szybki Start

```powershell
# 1. Zainstaluj moduł (jednorazowo)
Install-Module -Name Posh-SSH -Force -Scope CurrentUser

# 2. Podłącz laptop do Management VLAN 600 (dowolny port ether48)
# Ustaw IP: 192.168.255.100/28

# 3. Uruchom weryfikację
cd C:\Users\kolod\Desktop\LKP\05_BCU\INFRA\zsel-eip-infra\scripts
.\Verify-NetworkTopology.ps1
```

**Oczekiwany rezultat:**
```
✓ TOPOLOGIA PRAWIDŁOWA - Sieć gotowa do użytku!
Switche osiągalne: 5/5
Prawidłowe połączenia: 8
```

---

## 📋 Minimalna Konfiguracja Laptop

### Windows 11 (GUI)

1. **Settings** → **Network & Internet** → **Ethernet** → **Edit IP assignment**
2. Wybierz **Manual**
3. Ustaw:
   ```
   IP address:    192.168.255.100
   Subnet prefix: 28
   Gateway:       192.168.255.1
   DNS:           8.8.8.8
   ```

### PowerShell (Admin)

```powershell
# Usuń stary IP (jeśli był)
Remove-NetIPAddress -InterfaceAlias "Ethernet" -Confirm:$false -ErrorAction SilentlyContinue

# Ustaw nowy IP
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.255.100 -PrefixLength 28 -DefaultGateway 192.168.255.1

# Ustaw DNS
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 8.8.8.8,8.8.4.4

# Test
ping 192.168.255.1
```

---

## 🔍 Co Sprawdzić Przed Uruchomieniem?

```powershell
# 1. Czy laptop ma poprawny IP?
ipconfig
# Oczekiwane: 192.168.255.100, Mask: 255.255.255.240

# 2. Czy CORE jest dostępny?
ping 192.168.255.1

# 3. Czy Posh-SSH jest zainstalowany?
Get-Module -ListAvailable -Name Posh-SSH
```

---

## 📊 Interpretacja Wyników

### ✅ Sukces
```
✓ TOPOLOGIA PRAWIDŁOWA - Sieć gotowa do użytku!
```
→ Możesz podłączać Mac Pro servery! 🎉

### ⚠️ Częściowy Sukces
```
✗ BRAKUJĄCE POŁĄCZENIA:
  CORE-SWITCH-01 [sfp-sfpplus3] -/→ ACCESS-SWITCH-03 [sfp-sfpplus1]
```
→ Kabel trunk między CORE i ACCESS-03 nie jest podłączony

### ❌ Switch Offline
```
Testing ACCESS-SWITCH-02 (192.168.255.12)... ✗ Brak połączenia
```
→ Switch jest wyłączony LUB konfiguracja nie została zaimportowana

---

## 🛠️ Najczęstsze Problemy

### "Moduł Posh-SSH nie jest zainstalowany"
```powershell
Install-Module -Name Posh-SSH -Force -Scope CurrentUser
```

### "Cannot connect to 192.168.255.1"
```powershell
# Sprawdź IP laptop
ipconfig

# Jeśli nie ma 192.168.255.100/28:
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.255.100 -PrefixLength 28
```

### "SSH failed for all switches"
```powershell
# Sprawdź hasło (domyślne)
.\Verify-NetworkTopology.ps1 -Password "ZSE-BCU-2025!SecureP@ss"
```

### "No LLDP neighbors found"
```powershell
# Odczekaj 90 sekund po podłączeniu kabli
Start-Sleep -Seconds 90
.\Verify-NetworkTopology.ps1
```

---

## 📚 Pełna Dokumentacja

Szczegóły w: [AUTOMATION-TOPOLOGY-VERIFICATION.md](AUTOMATION-TOPOLOGY-VERIFICATION.md)

---

**⏱️ Ostateczna Checklist (30 sekund):**

- [ ] Laptop podłączony do ether48
- [ ] IP laptop = 192.168.255.100/28
- [ ] `ping 192.168.255.1` działa
- [ ] Posh-SSH zainstalowany
- [ ] Odczekano 60s od podłączenia kabli trunk
- [ ] Uruchomiono: `.\Verify-NetworkTopology.ps1`
- [ ] Wynik: `✓ TOPOLOGIA PRAWIDŁOWA`

🎉 **Gotowe! Sieć zweryfikowana!**
