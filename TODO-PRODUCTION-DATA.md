# 📋 TODO: Production Data Collection

**Status:** 🔴 CRITICAL - Required before deployment  
**Deadline:** Before Terraform apply to CCR2216-BCU-01

---

## ✅ Co już jest gotowe:

- [x] Struktura VLAN (30 VLANs w vlans-master.yaml)
- [x] BGP configuration (3 peers, MetalLB pools)
- [x] Generator Terraform (działa poprawnie)
- [x] Dokumentacja (K8S-CLUSTER-ARCHITECTURE.md)
- [x] Walidacja (wszystkie testy passed)

---

## 🔴 KRYTYCZNE - Do zebrania PRZED deployment:

### 1. MAC Adresy 9 × Mac Pro M2 Ultra

**Wymagane:** 9 MAC addresses (3 masters + 6 workers)

**Jak zebrać:**
```bash
# Na każdym Mac Pro (macOS):
ifconfig en0 | grep ether
# Lub:
networksetup -listallhardwareports | grep -A 2 Ethernet

# Jeśli już mają Linux:
ip link show | grep ether
```

**Co uzupełnić w `vlans-master.yaml`:**
```yaml
kubernetes:
  nodes:
    masters:
      - hostname: "k3s-master-01"
        ip: "192.168.10.11"
        mac: "CHANGE_ME_MAC_MASTER_01"  # ← UZUPEŁNIĆ!
      
      - hostname: "k3s-master-02"
        ip: "192.168.10.12"
        mac: "CHANGE_ME_MAC_MASTER_02"  # ← UZUPEŁNIĆ!
      
      - hostname: "k3s-master-03"
        ip: "192.168.10.13"
        mac: "CHANGE_ME_MAC_MASTER_03"  # ← UZUPEŁNIĆ!
    
    workers:
      - hostname: "k3s-worker-01"
        ip: "192.168.10.14"
        mac: "CHANGE_ME_MAC_WORKER_01"  # ← UZUPEŁNIĆ!
      
      # ... (pozostałe 5 workers)
```

**Format MAC:** `aa:bb:cc:dd:ee:ff` (lowercase, colon-separated)

---

### 2. ISP Gateway IP (z umowy OSTE)

**Wymagane:** IP bramy internetowej od OSTE

**Gdzie użyte:**
- BGP peering (jeśli router ma BGP z ISP)
- Default route w MikroTik
- Firewall rules (allow outbound)

**Obecny placeholder:** Sprawdź w aktualnej konfiguracji CCR2216-BCU-01:
```routeros
/ip route print
# Szukaj default route (0.0.0.0/0)
```

---

### 3. Obecna konfiguracja CCR2216-BCU-01

**Wymagane:** Backup aktualnej konfiguracji przed zmianami

**Jak wykonać:**
```routeros
# Na MikroTik CCR2216-BCU-01:
/export file=backup-before-k8s-$(date +%Y%m%d)

# Lub przez SSH:
ssh admin@192.168.255.1 "/export" > backup-$(date +%Y%m%d).rsc
```

**Gdzie zapisać:** `zsel-eip-network/configs/backups/`

---

## 🟡 WAŻNE - Do zebrania przed pełnym deployment:

### 4. Hostname verification

**Sprawdź czy Mac Pro mają poprawne hostnames:**
```bash
# Na każdym węźle:
hostname
# Expected: k3s-master-01, k3s-master-02, ..., k3s-worker-06
```

**Jeśli nie:**
```bash
# macOS:
sudo scutil --set HostName k3s-master-01
sudo scutil --set LocalHostName k3s-master-01
sudo scutil --set ComputerName k3s-master-01

# Linux:
sudo hostnamectl set-hostname k3s-master-01
```

---

### 5. Network connectivity test

**Test przed konfiguracją VLAN 110:**

```bash
# Z laptopa w sieci zarządzania (VLAN 600):
ping 192.168.255.1  # CCR2216-BCU-01
ssh admin@192.168.255.1

# Z każdego Mac Pro (jeśli mają tymczasowe IP):
ping 192.168.255.1  # Uplink do routera
ping 8.8.8.8        # Internet connectivity
```

---

### 6. K3s installation readiness

**Sprawdź czy Mac Pro są gotowe na K3s:**

```bash
# macOS (jeśli będzie używany jako host):
# K3s NIE DZIAŁA natywnie na macOS!
# Potrzebujesz Linux VM lub bare-metal Linux na Mac Pro

# Opcje:
# A) Zainstaluj Linux bare-metal (Ubuntu Server 22.04 ARM64)
# B) Użyj Parallels/VMware z Linux VM (nieoptymalne)
# C) Użyj containerd natywnie (wymaga konfiguracji)

# Linux (zalecane - Ubuntu Server 22.04):
uname -a  # Sprawdź kernel (>=5.15)
free -h   # Sprawdź RAM
df -h     # Sprawdź storage
```

---

## 🟢 OPCJONALNE - Nice to have:

### 7. Serial numbers & Asset tags

**Do inventory w Zabbix/documentation:**
```bash
# macOS:
system_profiler SPHardwareDataType | grep "Serial Number"

# Linux:
sudo dmidecode -s system-serial-number
```

---

### 8. Performance baseline

**Test przed produkcją:**
```bash
# CPU benchmark:
sysbench cpu --threads=24 run

# Memory bandwidth:
sysbench memory --threads=24 run

# Disk I/O (NVMe):
fio --name=randwrite --ioengine=libaio --rw=randwrite --bs=4k \
    --numjobs=4 --size=4g --runtime=60 --time_based --group_reporting
```

---

## 📝 Workflow po zebraniu danych:

### Krok 1: Uzupełnij vlans-master.yaml
```bash
cd zsel-eip-infra
code common/vlans-master.yaml
# Zmień wszystkie "CHANGE_ME_MAC_*" na prawdziwe MAC addressy
```

### Krok 2: Regeneruj Terraform
```bash
python scripts/generate-terraform.py
# Sprawdź output: prod-values-generated.auto.tfvars
```

### Krok 3: Backup obecnej konfiguracji
```bash
ssh admin@192.168.255.1 "/export" > ../zsel-eip-network/configs/backups/ccr-bcu-01-backup-$(date +%Y%m%d).rsc
```

### Krok 4: Plan deployment (DRY RUN)
```bash
cd ../zsel-eip-tf-infra/environments/networking-prod
cp prod-values.auto.tfvars prod-values-OLD.backup
mv ../../../zsel-eip-infra/prod-values-generated.auto.tfvars prod-values.auto.tfvars

terraform plan  # Przejrzyj zmiany!
```

### Krok 5: Apply (PRODUKCJA)
```bash
# UWAGA: To zmieni konfigurację routera!
terraform apply

# Monitoruj logi:
ssh admin@192.168.255.1
/log print follow
```

### Krok 6: Verify BGP
```bash
# Na MikroTik:
/routing bgp peer print
/routing bgp advertisements print

# Na K3s (po instalacji MetalLB):
kubectl get pods -n metallb-system
kubectl logs -n metallb-system -l component=speaker
```

---

## ⚠️ OSTRZEŻENIA:

1. **VLAN 110 deployment spowoduje:**
   - Restart interfejsów na CCR2216-BCU-01
   - Możliwa krótka przerwa w dostępie (2-5 sekund)
   - Mac Pro mogą stracić połączenie (jeśli są w innym VLAN)

2. **BGP peering wymaga:**
   - K3s zainstalowany na all 3 masters
   - MetalLB zainstalowany i skonfigurowany
   - Firewall rules zezwalające na BGP (TCP 179)

3. **Rollback plan:**
   ```bash
   # Jeśli coś pójdzie źle:
   terraform destroy  # Usuń nowe VLANy
   
   # Przywróć backup:
   scp backup-YYYYMMDD.rsc admin@192.168.255.1:/
   ssh admin@192.168.255.1 "/import backup-YYYYMMDD.rsc"
   ```

---

## 📞 Kontakt w razie problemów:

**DevOps Team:** devops@zsel.opole.pl  
**Emergency:** +48 XXX XXX XXX  
**Mattermost:** @devops-team (24/7)

---

**Status tracking:**
- [ ] MAC addresses collected (0/9)
- [ ] ISP gateway documented
- [ ] Backup created
- [ ] Hostnames verified
- [ ] Network connectivity tested
- [ ] K3s installation readiness checked
- [ ] vlans-master.yaml updated
- [ ] Terraform regenerated
- [ ] Dry-run executed
- [ ] Production deployment scheduled

**Next review:** [DATE]
