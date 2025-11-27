# ☸️ Kubernetes Cluster Architecture - ZSEL BCU

**JEDEN KLASTER K3S** - 9 × Mac Pro M2 Ultra  
**Lokalizacja:** CPD Serwerownia BCU  
**Data:** 27 listopada 2025

---

## 📋 Architektura Klastra

### Hardware

```text
9 × Mac Pro M2 Ultra (2023)
├── CPU:     24-core Apple Silicon M2 Ultra (ARM64)
├── RAM:     192 GB unified memory
├── Storage: 8 TB NVMe SSD (per node)
└── Network: 2× 10 Gbps Ethernet (OM4 fiber to Core Switch)

Total Resources:
- 216 CPU cores
- 1728 GB RAM
- 72 TB local storage (Longhorn distributed)
- 150 TB NAS storage (QNAP via NFS)
```

### Topologia

```text
Control Plane (HA):
├── k3s-master-01  192.168.10.11  (etcd leader candidate)
├── k3s-master-02  192.168.10.12  (etcd member)
└── k3s-master-03  192.168.10.13  (etcd member)

Worker Nodes (Specialized):
├── k3s-worker-01  192.168.10.14  [education]    → Moodle, BBB, NextCloud
├── k3s-worker-02  192.168.10.15  [education]    → Mattermost, OnlyOffice
├── k3s-worker-03  192.168.10.16  [devops]       → GitLab, Harbor, Portainer
├── k3s-worker-04  192.168.10.17  [ai-ml]        → Ollama, JupyterHub, Qdrant
├── k3s-worker-05  192.168.10.18  [analytics]    → Zabbix, Prometheus, Grafana
└── k3s-worker-06  192.168.10.19  [storage]      → Longhorn, MinIO
```

---

## 🌐 Adresacja Sieciowa

### VLAN Structure (Kubernetes Dedicated)

**OBECNIE BRAK W vlans-master.yaml - DO DODANIA!**

| VLAN ID | Name              | Subnet           | Gateway       | Purpose           | Devices          |
|---------|-------------------|------------------|---------------|-------------------|------------------|
| **10** | K3s-Masters | 192.168.10.0/24 | 192.168.10.1 | Control Plane | 3 masters |
| **20** | K3s-Workers | 192.168.10.0/24 | 192.168.10.1 | Worker Nodes | 6 workers |
| **30** | K3s-MetalLB-PROD | 192.168.30.0/24 | - | LoadBalancer Pool | LoadBalancer IPs |
| **31** | K3s-MetalLB-DEV | 192.168.31.0/24 | - | DEV LoadBalancer | DEV environment |
| **32** | K3s-MetalLB-ADM | 192.168.32.0/24 | - | Admin LoadBalancer | Admin services |
| **40** | K3s-Storage | 192.168.40.0/24 | 192.168.40.1 | Longhorn iSCSI/NFS | Storage replication |
| **50** | K3s-VPN | 192.168.50.0/24 | 192.168.50.1 | WireGuard VPN | Remote access (100 users) |

**UWAGA:** W dokumentacji jest różna adresacja:
- `ARCHITEKTURA_CHMURY_AI.md`: 192.168.10.0/24 (jeden VLAN dla wszystkich)
- `03-VLAN-ADDRESSING.md`: VLAN 10=masters (10.10.10.0/24), VLAN 20=workers (10.10.20.0/24), etc.

**ZALECENIE:** Uproszczona struktura (jak w ARCHITEKTURA_CHMURY_AI.md):
```
VLAN 110: 192.168.10.0/24 - K3s Cluster (masters + workers)
  ├── .1        Gateway (CCR-BCU-01)
  ├── .11-.13   Masters (3)
  ├── .14-.19   Workers (6)
  ├── .20-.100  MetalLB pool PROD
  ├── .101-.150 MetalLB pool DEV
  └── .200-.254 Reserved (WireGuard, management)
```

---

## 🔗 BGP Configuration (MetalLB)

### Router → K3s Peering

**MikroTik CCR2216-BCU-01:**
```
AS: 65000
Router ID: 192.168.255.1 (management)

Peers:
├── k3s-master-01  10.20.0.11  AS 65001  (TODO: Replace with actual IP)
├── k3s-master-02  10.20.0.12  AS 65001
└── k3s-master-03  10.20.0.13  AS 65001

Advertised Networks:
├── 10.22.0.0/24   MetalLB PROD pool
├── 10.12.0.0/24   MetalLB DEV pool
├── 10.32.0.0/24   MetalLB ADM pool
└── 10.20.0.0/22   K3s services network
```

**UWAGA:** BGP configuration w `vlans-master.yaml` używa adresów 10.20.0.x, ale w VLAN structure nie ma takiej sieci!

**ZALECENIE:** Uproszczenie BGP do jednego pool:
```yaml
bgp:
  instance:
    as: 65000
    router_id: "192.168.255.1"
  
  peers:
    - name: "k3s-master-01"
      remote_address: "192.168.10.11"  # Zgodne z VLAN 110
      remote_as: 65001
    
    - name: "k3s-master-02"
      remote_address: "192.168.10.12"
      remote_as: 65001
    
    - name: "k3s-master-03"
      remote_address: "192.168.10.13"
      remote_as: 65001
  
  advertised_networks:
    - network: "192.168.10.20/27"  # .20-.51 = 32 IPs dla LoadBalancer PROD
      comment: "MetalLB LoadBalancer pool (Production)"
    
    - network: "192.168.10.101/26"  # .101-.150 = 50 IPs dla DEV
      comment: "MetalLB LoadBalancer pool (Development)"
```

---

## 💾 Storage Architecture

### Longhorn Distributed Storage
```
Total: 40 TB usable (3× replicas)
├── Tier 1 (Critical): 10 TB  - PostgreSQL, FreeIPA, Keycloak
├── Tier 2 (Standard): 20 TB  - Moodle, GitLab, Harbor, Mattermost
└── Tier 3 (Bulk):     10 TB  - Backups, logs, media

Replication: 3× (HA for critical services)
Snapshots: Daily incremental (S3 backup to MinIO)
Network: VLAN 40 (192.168.40.0/24) - iSCSI + NFS
```

### QNAP NAS (External)
```
Model: TS-h1277AXU-RP
Capacity: 150 TB usable (RAIDZ2)
IP: 192.168.20.10 (VLAN 20 - NAS)
Protocols: NFS, iSCSI
Purpose:
  ├── NextCloud storage (100 TB)
  ├── BigBlueButton recordings (30 TB)
  ├── Moodle course files (15 TB)
  └── Backup destination (5 TB)
```

---

## 🔐 Security & Access

### Network Policies (Zero Trust)
```
Default: DENY ALL

Allowed:
├── Ingress: Only from Traefik (LoadBalancer)
├── Egress: DNS (CoreDNS), external APIs (whitelist)
├── Inter-namespace: Explicit allow only (280 policies total)
└── Management: SSH/kubectl from VLAN 500 (admin) only

Blocked:
├── Labs (VLAN 208-246) → K3s cluster
├── WiFi (VLAN 300-303) → K3s cluster
└── Students → Control Plane (VLAN 110)
```

### WireGuard VPN (VLAN 50)
```
Subnet: 192.168.50.0/24
Server: 192.168.50.1 (runs on k3s-worker-03)
Clients: 100 concurrent
Purpose: Remote admin access (teachers, IT staff)
Routes: Full access to VLAN 500 (admin), read-only to K3s
```

### FreeIPA Integration
```
LDAP: ldap://freeipa.zsel.opole.pl
Base DN: dc=zsel,dc=opole,dc=pl
Users: 1030 (900 students + 100 teachers + 30 admin)
Groups:
  ├── cn=k8s-cluster-admins  → ClusterRole: admin-full
  ├── cn=k8s-developers      → ClusterRole: developer
  └── cn=k8s-viewers         → ClusterRole: viewer

SSO: Keycloak (25 apps integrated via OIDC/SAML)
```

---

## 📊 Applications (39 Total)

### Core Infrastructure (Wave 10)
| App | Namespace | Replicas | Resources | LoadBalancer IP |
|-----|-----------|----------|-----------|-----------------|
| MetalLB | core-network | - | 512Mi, 500m | - |
| Traefik | core-network | 2 | 2Gi, 1 CPU | 192.168.10.20 |
| FreeIPA | core-freeipa | 2 | 16Gi, 8 CPU | 192.168.10.21 |
| Keycloak | core-keycloak | 2 | 8Gi, 4 CPU | 192.168.10.22 |
| Longhorn | storage-system | DaemonSet | 36Gi, 18 CPU | - |
| CoreDNS | kube-system | 2 | 512Mi, 250m | - |

### Education (Wave 25)
| App | Namespace | Replicas | Resources | LoadBalancer IP |
|-----|-----------|----------|-----------|-----------------|
| Moodle | edu-moodle | 3 | 16Gi, 8 CPU | 192.168.10.30 |
| BigBlueButton | edu-bbb | 3 | 96Gi, 24 CPU | 192.168.10.31 |
| NextCloud | edu-nextcloud | 2 | 8Gi, 4 CPU | 192.168.10.32 |
| Mattermost | edu-mattermost | 2 | 16Gi, 4 CPU | 192.168.10.33 |
| OnlyOffice | edu-onlyoffice | 2 | 32Gi, 8 CPU | 192.168.10.34 |
| Etherpad | edu-etherpad | 2 | 8Gi, 2 CPU | 192.168.10.35 |
| Calibre-Web | edu-calibre | 1 | 4Gi, 1 CPU | 192.168.10.36 |

### DevOps (Wave 30)
| App | Namespace | Replicas | Resources | LoadBalancer IP |
|-----|-----------|----------|-----------|-----------------|
| GitLab | devops-gitlab | 1 | 32Gi, 8 CPU | 192.168.10.40 |
| Harbor | devops-harbor | 1 | 24Gi, 6 CPU | 192.168.10.41 |
| Portainer | admin-portainer | 1 | 4Gi, 1 CPU | 192.168.10.42 |

### AI/ML (Wave 40)
| App | Namespace | Replicas | Resources | LoadBalancer IP |
|-----|-----------|----------|-----------|-----------------|
| Ollama | ai-ml-ollama | 1 | 64Gi, 8 CPU | 192.168.10.50 |
| JupyterHub | ai-ml-jupyter | 1 | 16Gi, 2 CPU | 192.168.10.51 |
| Qdrant | ai-ml-qdrant | 2 | 64Gi, 8 CPU | 192.168.10.52 |

**TOTAL:** 39 apps, 47 namespaces, ~720 GB RAM, ~204 CPU cores

---

## 🚀 Deployment Process

### GitOps with ArgoCD
```
1. Git Push → GitHub (zsel-eip-gitops)
2. ArgoCD detects change (2-minute poll)
3. Sync waves (0 → 40):
   Wave 0:  ArgoCD Root (App-of-Apps)
   Wave 5:  Sealed Secrets Controller
   Wave 10: Core Infrastructure (6 apps)
   Wave 15: Security & Monitoring (10 apps)
   Wave 20: Databases (2 apps)
   Wave 25: Education (8 apps)
   Wave 30: DevOps + Communication (5 apps)
   Wave 40: AI/ML (3 apps)
4. Health checks & rollback if failed
5. Prometheus metrics + Grafana dashboards
```

### CI/CD Pipeline (GitHub Actions)
```
Stage 1: Pre-Validation (syntax, linting)
Stage 2: Security Scan (Trivy, kubesec, Gitleaks)
Stage 3: Quality Checks (kubeconform, OPA)
Stage 4: DEV Deployment + integration tests
Stage 5: Manual approval gate (PROD only, 2/3 approvers)
Stage 6: PROD Deployment (progressive sync)
Stage 7: Post-Validation (E2E, performance, security)
```

---

## 📈 Monitoring & Observability

### Metrics (Prometheus)
```
Targets: 300+
├── 9 Mac Pro nodes (Node Exporter)
├── 39 applications (ServiceMonitor)
├── 57 MikroTik devices (SNMP Exporter)
└── Kubernetes internals (kube-state-metrics)

Retention: 30 days (200 GB storage)
Scrape interval: 2 minutes
Alerting: Mattermost webhooks
```

### Logs (Loki)
```
Retention: 2 years (RODO compliance)
Storage: 500 GB
Collectors: Promtail (DaemonSet on 9 nodes)
Query: {namespace="edu-moodle"} |= "error"
```

### Infrastructure (Zabbix)
```
Hosts: 66 total
├── 9 Mac Pro M2 Ultra nodes
├── 57 MikroTik routers/switches
└── 39 application health checks

Alerting: Email + Mattermost
Dashboard: 24/7 NOC display (VLAN 110)
```

---

## 🔄 Backup & Disaster Recovery

### 4-Layer Strategy
```
1. Cluster State (Velero):
   - Daily full backup (etcd + manifests)
   - Hourly incremental
   - Retention: 90 days

2. Persistent Volumes (Longhorn):
   - Hourly snapshots
   - S3 backup to MinIO
   - Retention: 30 days

3. Databases (pg_dump/mysqldump):
   - Every 6 hours
   - Encrypted backups to QNAP NAS
   - Retention: 90 days

4. Offsite Replication:
   - Daily rsync to secondary location
   - 100 Mbps WireGuard tunnel
   - Retention: 1 year
```

### RTO/RPO
```
RTO (Recovery Time Objective): 4 hours
RPO (Recovery Point Objective): 6 hours

Recovery Procedure:
1. Restore etcd from Velero backup (30 min)
2. Restore PVCs from Longhorn snapshots (1 hour)
3. Restore databases from dumps (2 hours)
4. Verify health checks (30 min)
```

---

## 🐛 Troubleshooting

### Common Issues

**1. Pod in CrashLoopBackOff**
```bash
kubectl describe pod <name> -n <namespace>
kubectl logs <name> -n <namespace> --previous
```

**2. PVC Pending**
```bash
kubectl get pvc -A | grep Pending
kubectl describe pvc <name> -n <namespace>
# Check: Longhorn operational, storage available
```

**3. LoadBalancer IP not assigned**
```bash
kubectl get svc -A | grep Pending
kubectl logs -n core-network -l app.kubernetes.io/name=metallb
# Check: BGP peering up (MikroTik ↔ MetalLB)
```

**4. DNS resolution fails**
```bash
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup google.com
kubectl logs -n kube-system -l k8s-app=kube-dns
```

**5. Ingress not accessible**
```bash
kubectl get ingress -A
kubectl logs -n core-network -l app.kubernetes.io/name=traefik
# Check: Traefik pod running, LoadBalancer IP assigned
```

### Health Checks
```bash
# Cluster status
kubectl get nodes -o wide
kubectl cluster-info

# All applications
kubectl get applications -n argocd

# Pods not running
kubectl get pods -A | findstr -v "Running\|Completed"

# Storage
kubectl get pvc -A | findstr "Pending"
kubectl get sc

# Network
kubectl get svc -A | findstr "LoadBalancer"
kubectl get networkpolicies -A
```

---

## 📞 Contact & Support

**Organization:** Zespół Szkół Elektronicznych i Logistycznych w Opolu  
**Team:** DevOps & Infrastructure  
**Email:** devops@zsel.opole.pl  
**GitHub:** https://github.com/zsel-opole/zsel-eip-gitops

**Emergency Contact:**
- On-call: +48 XXX XXX XXX
- Mattermost: @devops-team (24/7)

---

## 🔗 Related Documentation

| Document | Location | Description |
|----------|----------|-------------|
| GitOps Repository | `zsel-eip-gitops/` | ArgoCD manifests (39 apps) |
| Network Config | `zsel-eip-infra/` | VLAN, QoS, BGP (Terraform) |
| PFU Specification | `zsel-eip-dokumentacja/` | Program Funkcjonalno-Użytkowy |
| Architecture Diagrams | `zsel-eip-dokumentacja/diagramy/` | Mermaid diagrams |

---

**Status:** ✅ Production Ready (1 klaster K3s)  
**Last updated:** 27 listopada 2025  
**Version:** 1.0.0
