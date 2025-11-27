# 🖥️ Aktualna Infrastruktura - Stan Rzeczywisty

**Data:** 27 listopada 2025  
**Status:** 🟡 Infrastruktura początkowa (testowa)

---

## ✅ Co FAKTYCZNIE mamy:

### Network Infrastructure
```
Switche:
├── 4× CRS354 (Gigabit, ~48 portów per switch)
├── 3× CRS324 (SFP+, 24 porty per switch)
└── 2× cAP (Access Points WiFi)

Total: 9 urządzeń sieciowych
```

### Compute Infrastructure
```
Serwery:
└── 9× Mac Pro M2 Ultra (obecnie macOS → do migracji na Ubuntu)
    ├── CPU: 24-core Apple Silicon M2 Ultra
    ├── RAM: 192 GB unified memory
    └── Storage: 8 TB NVMe SSD
```

---

## 🔄 Różnice vs Dokumentacja

### Było w PFU 2.7 (docelowo):
- 57 urządzeń MikroTik
- 15 pracowni (VLAN 208-246)
- 4 piętra z WiFi
- 48 kamer CCTV

### Jest TERAZ (start):
- 9 urządzeń MikroTik
- **BRAK** pracowni (jeszcze nie działają)
- 2 Access Points (minimalna pokrycie WiFi)
- **BRAK** kamer (na razie)

---

## 🎯 Co możemy zrobić TERAZ:

### Phase 1: Core Infrastructure (TERAZ - 1-2 tygodnie)

#### Priorytet 1: Kubernetes Cluster
```
Cel: Uruchomić 1 klaster K3s na 9 Mac Pro

Hardware ready:
✅ 9× Mac Pro M2 Ultra (po konwersji na Ubuntu)

Network needed:
✅ 4× CRS354 (wystarczą do startu)
✅ 1× router (CCR lub CRS324 z routingiem)

VLANs needed (uproszczone):
- VLAN 110: K3s Cluster (192.168.10.0/24)
- VLAN 600: Management (192.168.255.0/28)
- VLAN 1: Internet uplink (default)

Timeline: 3-5 dni
```

#### Priorytet 2: Basic Services (2-3 dni)
```
Uruchomić podstawowe aplikacje:
✅ FreeIPA (LDAP/DNS/CA)
✅ Keycloak (SSO)
✅ Moodle (LMS dla nauczycieli)
✅ NextCloud (cloud storage)
✅ Prometheus + Grafana (monitoring)

Nie potrzeba: pracownie, WiFi dla studentów, CCTV
```

#### Priorytet 3: Network Monitoring (1 dzień)
```
Zabbix/Prometheus dla:
✅ 9× MikroTik devices
✅ 9× Mac Pro (K3s nodes)
✅ Core services health

To już da pełny obraz infrastruktury
```

---

## 📋 Uproszczona konfiguracja vlans-master.yaml

### Minimalna wersja (tylko K8s + management):

```yaml
vlans:
  # === KLASTER KUBERNETES - VLAN 110 ===
  kubernetes:
    vlan_id: 110
    subnet: "192.168.10.0/24"
    gateway: "192.168.10.1"
    dhcp_pool: "192.168.10.200-192.168.10.254"
    description: "K3s Cluster - 9× Mac Pro M2 Ultra"
    
    nodes:
      masters:
        - hostname: "k3s-master-01"
          ip: "192.168.10.11"
          mac: "CHANGE_ME"
        - hostname: "k3s-master-02"
          ip: "192.168.10.12"
          mac: "CHANGE_ME"
        - hostname: "k3s-master-03"
          ip: "192.168.10.13"
          mac: "CHANGE_ME"
      
      workers:
        - hostname: "k3s-worker-01"
          ip: "192.168.10.14"
          mac: "CHANGE_ME"
        - hostname: "k3s-worker-02"
          ip: "192.168.10.15"
          mac: "CHANGE_ME"
        - hostname: "k3s-worker-03"
          ip: "192.168.10.16"
          mac: "CHANGE_ME"
        - hostname: "k3s-worker-04"
          ip: "192.168.10.17"
          mac: "CHANGE_ME"
        - hostname: "k3s-worker-05"
          ip: "192.168.10.18"
          mac: "CHANGE_ME"
        - hostname: "k3s-worker-06"
          ip: "192.168.10.19"
          mac: "CHANGE_ME"
    
    metallb:
      prod:
        range: "192.168.10.20-192.168.10.51"
        count: 32

  # === ZARZĄDZANIE - VLAN 600 ===
  management:
    vlan_id: 600
    subnet: "192.168.255.0/28"
    gateway: "192.168.255.1"
    description: "Zarządzanie infrastrukturą"
    
    devices:
      - name: "crs354-01"
        ip: "192.168.255.2"
      - name: "crs354-02"
        ip: "192.168.255.3"
      - name: "crs354-03"
        ip: "192.168.255.4"
      - name: "crs354-04"
        ip: "192.168.255.5"
      - name: "crs324-01"
        ip: "192.168.255.6"
      - name: "crs324-02"
        ip: "192.168.255.7"
      - name: "crs324-03"
        ip: "192.168.255.8"
      - name: "cap-01"
        ip: "192.168.255.9"
      - name: "cap-02"
        ip: "192.168.255.10"

bgp:
  instance:
    as: 65000
    router_id: "192.168.255.1"
  
  peers:
    - name: "k3s-master-01"
      remote_address: "192.168.10.11"
      remote_as: 65001
    - name: "k3s-master-02"
      remote_address: "192.168.10.12"
      remote_as: 65001
    - name: "k3s-master-03"
      remote_address: "192.168.10.13"
      remote_as: 65001
  
  advertised_networks:
    - network: "192.168.10.20/27"
      comment: "MetalLB LoadBalancer pool"
```

---

## 🚀 Quick Start Plan (3-5 dni):

### Dzień 1: Ubuntu na Mac Pro (6-8 godzin)
```bash
# Instrukcja: MAC-PRO-UBUNTU-INSTALL.md
1. Przygotuj USB bootable (Ubuntu 24.04 ARM64)
2. Boot z USB na każdym Mac Pro
3. Instalacja Ubuntu (automated via preseed)
4. Network config (VLAN 110)
5. Weryfikacja (SSH, hostname, MAC address)

Output: 9× Mac Pro z Ubuntu 24.04 ARM64
```

### Dzień 2: Network Configuration (4-6 godzin)
```bash
# Minimal Terraform config
1. Stwórz VLAN 110 (K8s) + VLAN 600 (management)
2. Configure BGP (1 router ↔ 3 masters)
3. Test connectivity (ping, SSH)
4. Configure CRS354/CRS324 (basic VLAN trunking)

Output: Network ready dla K3s
```

### Dzień 3: K3s Installation (4-6 godzin)
```bash
# Ansible playbook
1. Install K3s masters (HA etcd)
2. Install K3s workers (join cluster)
3. Verify cluster (kubectl get nodes)
4. Install MetalLB (BGP speaker)
5. Test LoadBalancer (dummy service)

Output: K3s cluster operational
```

### Dzień 4: Core Services (6-8 godzin)
```bash
# ArgoCD deployment
1. Install ArgoCD (GitOps controller)
2. Deploy FreeIPA (LDAP/DNS)
3. Deploy Keycloak (SSO)
4. Deploy Prometheus + Grafana (monitoring)
5. Deploy Longhorn (storage)

Output: Basic services running
```

### Dzień 5: Verification & Documentation (4 godziny)
```bash
1. Test wszystkich services (health checks)
2. Configure Grafana dashboards
3. Setup Zabbix monitoring (9 nodes + 9 switches)
4. Document network topology (as-built)
5. Backup configuration

Output: Production-ready infrastructure (minimal)
```

---

## 🔄 Rozbudowa w przyszłości:

### Phase 2: Expand Network (gdy kupisz więcej hardware)
- Dodaj pracownie (VLAN 208-246)
- Dodaj WiFi dla studentów (VLAN 300-303)
- Dodaj CCTV (VLAN 501)

### Phase 3: More Applications
- Moodle z pełną integracją
- BigBlueButton (video conferencing)
- GitLab (DevOps platform)
- Ollama + JupyterHub (AI/ML)

### Phase 4: Full PFU Compliance
- 57 urządzeń MikroTik
- 15 pracowni
- QoS policies
- Advanced firewall rules

---

## ✅ Co możesz zrobić TERAZ:

1. **Przeczytaj:** `MAC-PRO-UBUNTU-INSTALL.md` (zaraz stworzę)
2. **Zbierz:** MAC addresses z 9× Mac Pro (przed wipe)
3. **Przygotuj:** USB bootable Ubuntu 24.04 ARM64
4. **Plan:** 3-5 dni na full deployment (K3s + basic services)

**Gotowy na instrukcję instalacji Ubuntu?** 🚀
