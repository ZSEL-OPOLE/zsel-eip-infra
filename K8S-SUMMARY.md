# ☸️ Kubernetes Summary - Ujednolicona Architektura

**Data aktualizacji:** 27 listopada 2025  
**Status:** ✅ Struktura ujednolicona - 1 klaster K3s

---

## ✅ Co zostało zrobione?

### 1. Dodano VLAN 110 do `vlans-master.yaml`
```yaml
vlans:
  kubernetes:
    vlan_id: 110
    subnet: "192.168.10.0/24"
    gateway: "192.168.10.1"
    
    nodes:
      masters: [192.168.10.11-13]  # 3 control plane nodes
      workers: [192.168.10.14-19]  # 6 worker nodes
    
    metallb:
      prod: 192.168.10.20-.51   (32 IPs)
      dev:  192.168.10.101-.150 (50 IPs)
```

### 2. Zaktualizowano BGP Configuration
```yaml
bgp:
  peers:
    - k3s-master-01: 192.168.10.11 (było: 10.20.0.11)
    - k3s-master-02: 192.168.10.12
    - k3s-master-03: 192.168.10.13
  
  advertised_networks:
    - 192.168.10.20/27   (MetalLB PROD)
    - 192.168.10.101/26  (MetalLB DEV)
```

### 3. Stworzono dokumentację
- **`docs/K8S-CLUSTER-ARCHITECTURE.md`** - kompletny opis klastra
- **Zaktualizowano README.md** (zsel-eip-infra) - dodano sekcję VLAN 110
- **Zaktualizowano README.md** (zsel-eip-gitops) - opis 1 klastra

### 4. Walidacja ✅
```bash
python scripts/validate-config.py
# Result: ALL VALIDATIONS PASSED
# VLANs: 30 (było: 29)
# BGP Peers: 3 (poprawne adresy IP)
```

---

## 📊 Obecna Architektura

### 1 Klaster K3s = 9 Węzłów

```
┌─────────────────────────────────────────────────────┐
│  VLAN 110: K3s Cluster (192.168.10.0/24)          │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Control Plane (HA etcd):                          │
│  ├── k3s-master-01  .11  (etcd leader)            │
│  ├── k3s-master-02  .12  (etcd member)            │
│  └── k3s-master-03  .13  (etcd member)            │
│                                                     │
│  Workers (specialized):                             │
│  ├── k3s-worker-01  .14  [education]              │
│  ├── k3s-worker-02  .15  [education]              │
│  ├── k3s-worker-03  .16  [devops]                 │
│  ├── k3s-worker-04  .17  [ai-ml]                  │
│  ├── k3s-worker-05  .18  [analytics]              │
│  └── k3s-worker-06  .19  [storage]                │
│                                                     │
│  MetalLB:                                           │
│  ├── PROD:  .20-.51   (32 IPs)                    │
│  └── DEV:   .101-.150 (50 IPs)                    │
│                                                     │
│  Total: 216 cores, 1728 GB RAM, 72 TB storage     │
└─────────────────────────────────────────────────────┘
```

### Networking
```
CCR2216-BCU-01 (AS 65000, 192.168.255.1)
       │
       │ BGP Peering
       ├── k3s-master-01 (AS 65001, 192.168.10.11)
       ├── k3s-master-02 (AS 65001, 192.168.10.12)
       └── k3s-master-03 (AS 65001, 192.168.10.13)
                │
                └── MetalLB Advertises:
                    ├── 192.168.10.20/27  (PROD pool)
                    └── 192.168.10.101/26 (DEV pool)
```

---

## 🔗 Powiązane Repozytoria

### 1. **zsel-eip-infra** (Network Configuration)
```
Purpose: VLAN, QoS, BGP dla MikroTik
Status:  ✅ Zaktualizowane (VLAN 110 added)
Files:
  ├── common/vlans-master.yaml          (VLAN 110 config)
  ├── docs/K8S-CLUSTER-ARCHITECTURE.md  (kompletny opis)
  └── README.md                          (zaktualizowany)
```

### 2. **zsel-eip-gitops** (Kubernetes Manifests)
```
Purpose: ArgoCD manifests (39 apps, 47 namespaces)
Status:  ✅ Zaktualizowane (README opisuje 1 klaster)
Files:
  ├── apps/*/manifests/               (39 aplikacji)
  ├── sealed-secrets/                 (50+ encrypted secrets)
  └── README.md                       (zaktualizowany)
```

### 3. **zsel-eip-tf-module-k8s-*** (Terraform Modules)
```
Purpose: Terraform modules dla K8s (namespaces, RBAC, network policies)
Status:  ⚠️  UWAGA - używają MikroTik provider (błąd)
Modules:
  ├── zsel-eip-tf-module-k8s-argocd           (ArgoCD deployment)
  ├── zsel-eip-tf-module-k8s-namespaces       (namespace management)
  ├── zsel-eip-tf-module-k8s-network-policies (Zero Trust policies)
  └── zsel-eip-tf-module-k8s-rbac             (RBAC roles)

TODO: Zmienić provider z 'terraform-routeros' na 'hashicorp/kubernetes'
```

### 4. **zsel-eip-ansible** (Infrastructure Automation)
```
Purpose: Ansible playbooks dla K3s installation
Status:  🔄 Do sprawdzenia (czy używa VLAN 110?)
Files:
  └── playbooks/01-install-k3s.yml.old
```

---

## ⚠️ Uwagi & Ostrzeżenia

### 1. Terraform Modules K8s używają złego providera
**Problem:** Moduły `zsel-eip-tf-module-k8s-*` używają `terraform-routeros/routeros` provider  
**Powinno być:** `hashicorp/kubernetes` provider  
**Impact:** Moduły nie będą działać dopóki nie zmienisz providera  
**Fix:** 
```hcl
# W każdym module main.tf zamień:
terraform {
  required_providers {
    routeros = {  # ❌ ZŁY
      source  = "terraform-routeros/routeros"
      version = ">= 1.92"
    }
  }
}

# NA:
terraform {
  required_providers {
    kubernetes = {  # ✅ POPRAWNY
      source  = "hashicorp/kubernetes"
      version = ">= 2.30"
    }
  }
}
```

### 2. MAC Adresy do uzupełnienia
W `vlans-master.yaml` są placeholdery:
```yaml
mac: "CHANGE_ME_MAC_MASTER_01"
mac: "CHANGE_ME_MAC_MASTER_02"
# ... itd.
```

**TODO:** Zebrac MAC adresy z 9 Mac Pro M2 Ultra:
```bash
# Na każdym węźle:
ip link show | grep ether
# Lub:
ifconfig | grep ether
```

### 3. Pozostałe TODO
- [ ] Zebrać MAC adresy 9 węzłów
- [ ] Poprawić Terraform modules K8s (zmienić provider)
- [ ] Przetestować deployment VLAN 110 na CCR2216-BCU-01
- [ ] Przetestować BGP peering (MetalLB ↔ MikroTik)
- [ ] Skonfigurować K3s na węzłach (instalacja via Ansible?)

---

## 📚 Dokumentacja

### Główne pliki:
1. **`zsel-eip-infra/docs/K8S-CLUSTER-ARCHITECTURE.md`**  
   → Kompletny opis klastra (9 węzłów, VLAN, BGP, storage, aplikacje)

2. **`zsel-eip-infra/common/vlans-master.yaml`**  
   → Single source of truth (VLAN 110 config)

3. **`zsel-eip-gitops/README.md`**  
   → Opis 39 aplikacji, deployment workflow

### Diagramy:
- `zsel-eip-dokumentacja/diagramy/network/k3s-architecture.mmd`  
- `zsel-eip-dokumentacja/diagramy/network/k3s-services-detailed.mmd`

---

## ✅ Status

**Struktura sieciowa:** ✅ Ujednolicona (VLAN 110 dodany)  
**BGP Configuration:** ✅ Poprawione (192.168.10.x)  
**Dokumentacja:** ✅ Zaktualizowana  
**Walidacja:** ✅ Passed (30 VLANs, 3 BGP peers)  
**Terraform Modules:** ⚠️ Wymagają poprawy (zmiana providera)

---

**Next Steps:**
1. Zebrać MAC adresy węzłów → uzupełnić `vlans-master.yaml`
2. Poprawić Terraform modules K8s (provider)
3. Deploy VLAN 110 na CCR2216-BCU-01
4. Test BGP peering
5. Deploy K3s na węzłach

---

**Kontakt:** DevOps Team <devops@zsel.opole.pl>
