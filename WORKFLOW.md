# Workflow Guide - ZSEL Infrastructure Management

## 📋 Overview

Ten dokument opisuje proces zarządzania konfiguracją sieciową ZSEL Opole.

**Podstawowa zasada:** Edit 1 plik YAML → Run generator → Deploy

---

## 🎯 Quick Reference

```bash
# 1. EDYTUJ konfigurację
code common/vlans-master.yaml

# 2. GENERUJ Terraform
python scripts/generate-terraform.py

# 3. WDRÓŻ zmiany
cd zsel-eip-tf-infra/environments/networking-prod
terraform validate
terraform plan
terraform apply
```

---

## 📁 Struktura Plików

### Source of Truth (YAML)
```
common/vlans-master.yaml (324 linie)
├── vlans:
│   ├── dydactic (4× VLAN 101-104)
│   ├── tv (1× VLAN 110)
│   ├── labs (15× VLAN 208-246)  ← NUMERY SAL!
│   ├── wifi (4× VLAN 300-303)
│   ├── servers (2× VLAN 400-401)
│   ├── admin (1× VLAN 500)
│   ├── cctv (1× VLAN 501)
│   └── management (1× VLAN 600)
├── qos_policies: (PFU 2.7)
├── firewall_rules:
├── bgp: (MetalLB)
└── devices: (57× MikroTik)
```

### Generator (Python)
```
scripts/generate-terraform.py (280 linii)
├── load_yaml() → parse YAML
├── generate_vlans() → 29 VLANs
├── generate_qos() → 23 reguły QoS
├── generate_bgp() → 3 peery BGP
└── main() → zapisz prod-values-generated.auto.tfvars
```

### Terraform Config (Auto-generated)
```
zsel-eip-tf-infra/environments/networking-prod/
└── prod-values.auto.tfvars (325 linii, auto-generated)
    ├── mikrotik_host, mikrotik_username
    ├── vlans = { ... } (29 VLANs)
    ├── queue_simple = { ... } (23 QoS)
    ├── bgp_instances, bgp_peers, bgp_networks
    └── # DO NOT EDIT MANUALLY!
```

---

## 🔄 Proces Zmian

### 1️⃣ Dodawanie Nowego VLANu (Pracownia)

**Scenariusz:** Dodaj nową pracownię w sali 47 (Piętro III)

```bash
# KROK 1: Edytuj YAML
code common/vlans-master.yaml
```

Dodaj w sekcji `vlans.labs`:
```yaml
    - sala: 47
      vlan_id: 247
      subnet: "10.47.0.0/16"
      gateway: "10.47.0.1"
      dhcp_pool: "10.47.1.51-10.47.254.254"
      lease_time: "4h"
      floor: "P3"
      type: "fixed"
      ports: 32
      kpd: "KPD-P3-47"
      description: "Pracownia 47 - Piętro III"
```

```bash
# KROK 2: Generuj Terraform
python scripts/generate-terraform.py

# Output:
# ✅ GENERATION COMPLETE
# VLANs generated: 30 (było 29, teraz +1)

# KROK 3: Review
diff prod-values.auto.tfvars prod-values-generated.auto.tfvars

# KROK 4: Backup & Activate
mv prod-values.auto.tfvars prod-values-$(date +%Y%m%d-%H%M).backup
mv prod-values-generated.auto.tfvars prod-values.auto.tfvars

# KROK 5: Validate
terraform validate

# KROK 6: Plan (dry-run)
terraform plan -out=tfplan

# KROK 7: Apply
terraform apply tfplan
```

---

### 2️⃣ Modyfikacja QoS (Zmiana Limitu)

**Scenariusz:** Zwiększ przepustowość pracowni z 60M → 100M

```bash
# KROK 1: Edytuj YAML
code common/vlans-master.yaml
```

Zmień sekcję `qos_policies.labs`:
```yaml
qos_policies:
  labs:
    max_limit: "100M/100M"      # było: 60M/60M
    burst_limit: "120M/120M"    # było: 80M/80M
    burst_threshold: "80M/80M"  # było: 50M/50M
    burst_time: "30s"
    priority: 3
    comment: "PFU 2.7 UPGRADED - Pracownie 100 Mbps"
```

```bash
# KROK 2-7: Jak wyżej (generate → backup → validate → plan → apply)
python scripts/generate-terraform.py
# ... (j.w.)
```

---

### 3️⃣ Dodawanie WiFi na Nowym Piętrze

**Scenariusz:** Dodaj WiFi na piętrze P4 (VLAN 304)

```bash
# KROK 1: Edytuj YAML - sekcja vlans.wifi
```

```yaml
    - floor: "P4"
      vlan_id: 304
      subnet: "10.100.5.0/24"
      gateway: "10.100.5.1"
      dhcp_pool: "10.100.5.51-10.100.5.250"
      lease_time: "2h"
      ssid: "ZSE_Student"
      description: "WiFi uczniowska - Piętro IV"
```

```bash
# KROK 2: Generator automatycznie doda QoS dla WiFi P4
python scripts/generate-terraform.py
```

---

### 4️⃣ Zmiana Adresacji (Subnet)

**Scenariusz:** Zmień subnet sali 8 z 10.8.0.0/16 → 10.108.0.0/16

⚠️ **UWAGA:** Wymaga rekonfiguracji wszystkich urządzeń w tej sali!

```bash
# KROK 1: Edytuj YAML
code common/vlans-master.yaml
```

Zmień w `vlans.labs`:
```yaml
    - sala: 8
      vlan_id: 208
      subnet: "10.108.0.0/16"        # ZMIANA!
      gateway: "10.108.0.1"          # ZMIANA!
      dhcp_pool: "10.108.1.51-10.108.254.254"  # ZMIANA!
```

```bash
# KROK 2: Generate → Terraform pokaże DESTRUCT + CREATE
python scripts/generate-terraform.py
terraform plan  # REVIEW CAREFULLY! Będzie downtime!

# KROK 3: Komunikacja z userami
# Wysłać info do nauczycieli: "Sala 8 offline 10:00-10:15"

# KROK 4: Apply (w oknie maintenance)
terraform apply
```

---

## 🧪 Testowanie Przed Wdrożeniem

### Dry-run (Plan)
```bash
terraform plan -out=tfplan
# Review output:
# - Zielone (+) = nowe zasoby
# - Żółte (~) = modyfikacje
# - Czerwone (-) = usunięcia
```

### Validate Syntax
```bash
terraform validate
# Success! The configuration is valid.
```

### Diff Generator Output
```bash
diff -u prod-values.auto.tfvars prod-values-generated.auto.tfvars | less
```

---

## 🔍 Sprawdzanie Stanu

### Ile VLANów w konfiguracji?
```bash
grep -c '  "[0-9]*"' zsel-eip-tf-infra/environments/networking-prod/prod-values.auto.tfvars
# Output: 29
```

### Jakie sale są skonfigurowane?
```bash
grep 'lab-' common/vlans-master.yaml | grep sala:
# Output:
# - sala: 8
# - sala: 9
# - sala: 23
# ...
```

### Sprawdź QoS dla konkretnej sali
```bash
python3 << EOF
import yaml
with open('common/vlans-master.yaml') as f:
    cfg = yaml.safe_load(f)
    for lab in cfg['vlans']['labs']:
        if lab['sala'] == 8:
            print(f"Sala 8: {lab['subnet']}, QoS: {cfg['qos_policies']['labs']['max_limit']}")
EOF
```

---

## 🚨 Troubleshooting

### Problem: Generator nie działa
```bash
# Check Python version (requires 3.7+)
python --version

# Install dependencies
pip install pyyaml

# Run with verbose output
python -v scripts/generate-terraform.py
```

### Problem: Terraform validate fails
```bash
# Check Terraform version
terraform version
# Requires: >= 1.0

# Re-initialize
cd zsel-eip-tf-infra/environments/networking-prod
terraform init

# Check provider versions
terraform providers
```

### Problem: YAML syntax error
```bash
# Validate YAML
python -c "import yaml; yaml.safe_load(open('common/vlans-master.yaml'))"

# Use YAML linter
yamllint common/vlans-master.yaml
```

---

## 📊 Monitoring Po Wdrożeniu

### 1. Sprawdź połączenie z core router
```bash
ping 192.168.255.1
```

### 2. Sprawdź VLANy na MikroTik (via SSH)
```bash
ssh admin@192.168.255.1 -p 2222
/interface vlan print
```

### 3. Sprawdź QoS queues
```bash
ssh admin@192.168.255.1 -p 2222
/queue simple print
```

### 4. Sprawdź BGP peering (MetalLB)
```bash
ssh admin@192.168.255.1 -p 2222
/routing bgp peer print status
```

---

## ✅ Checklist Wdrożenia

Przed `terraform apply` sprawdź:

- [ ] Backup aktualnej konfiguracji utworzony
- [ ] `terraform validate` przeszedł pomyślnie
- [ ] `terraform plan` przejrzany (zrozumiane wszystkie zmiany)
- [ ] Okno maintenance uzgodnione (jeśli breaking changes)
- [ ] Team powiadomiony (Slack/email)
- [ ] Rollback plan przygotowany

Po `terraform apply` sprawdź:

- [ ] Ping do core router działa
- [ ] VLANy utworzone (`/interface vlan print`)
- [ ] QoS rules działają (`/queue simple print`)
- [ ] BGP peering up (jeśli dotyczy)
- [ ] Testy connectivity z end devices

---

## 📝 Best Practices

### 1. Zawsze używaj generatora
```bash
# ✅ DOBRZE
vim common/vlans-master.yaml
python scripts/generate-terraform.py

# ❌ ŹLE - nigdy nie edytuj ręcznie!
vim prod-values.auto.tfvars
```

### 2. Commituj YAML, nie Terraform config
```bash
git add common/vlans-master.yaml
git commit -m "feat: add VLAN 247 for lab room 47"

# prod-values.auto.tfvars jest w .gitignore (auto-generated)
```

### 3. Review przed apply
```bash
terraform plan | tee plan-$(date +%Y%m%d-%H%M).txt
less plan-*.txt  # Review offline
```

### 4. Incremental changes
```bash
# ✅ DOBRZE - po kolei
1. Dodaj VLAN 247 → apply
2. Dodaj VLAN 248 → apply

# ❌ ŹLE - wszystko naraz
Dodaj VLAN 247, 248, 249, zmień QoS, zmień BGP → apply (chaos!)
```

---

## 🔗 Related Documentation

- **PFU 2.7:** `zsel-eip-dokumentacja/architektura/pfu.md`
- **Network Docs:** `zsel-eip-network/docs/VLAN-ROUTING-FIREWALL.md`
- **Terraform Modules:** `zsel-eip-tf-module-mikrotik-*/README.md`
- **Ansible Playbooks:** `zsel-eip-ansible/playbooks/`

---

**Last updated:** 2025-11-27
