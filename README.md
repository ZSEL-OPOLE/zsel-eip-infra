# zsel-eip-infra

Infrastructure as Code - Terraform configuration with YAML-driven generator

> **🔐 Security:** This repository implements comprehensive security controls. See [SECURITY-SETUP.md](SECURITY-SETUP.md)  
> **🤝 Contributing:** Read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting PRs  
> **🛡️ Security Policy:** Report vulnerabilities via [SECURITY.md](SECURITY.md)

## 📋 Overview

Centralized configuration management for ZSEL Opole network infrastructure:
- **57 MikroTik devices** (5× CCR2216, 6× CRS518, 16× CRS354, 13× CRS326, 1× CRS328, 16× cAP)
- **29 VLANs** (PFU 2.7 compliant)
- **Single source of truth**: `common/vlans-master.yaml`
- **Automatic Terraform generation**: `scripts/generate-terraform.py`

**Organization:** https://github.com/zsel-opole

---

## 📁 Repository Structure

```
zsel-eip-infra/
├── common/
│   └── vlans-master.yaml           # Single source of truth (YAML)
├── scripts/
│   └── generate-terraform.py       # Terraform generator
└── zsel-eip-tf-infra/
    └── environments/
        └── networking-prod/
            └── prod-values.auto.tfvars  # Auto-generated Terraform config
```

---

## 🚀 Quick Start

### 1. Edit Configuration (Single File!)
```bash
# Edit YAML source of truth
code common/vlans-master.yaml
```

### 2. Generate Terraform Configuration
```bash
# Run generator
python scripts/generate-terraform.py

# Output: zsel-eip-tf-infra/environments/networking-prod/prod-values-generated.auto.tfvars
```

### 3. Activate & Validate
```bash
cd zsel-eip-tf-infra/environments/networking-prod

# Backup old config (if exists)
mv prod-values.auto.tfvars prod-values-OLD.backup

# Activate new config
mv prod-values-generated.auto.tfvars prod-values.auto.tfvars

# Validate
terraform validate

# Plan deployment
terraform plan
```

---

## 🔒 Security & Code Quality

This repository implements **enterprise-grade security** with 4-layer defense architecture:

| Layer | Enforcement Point | Tools | When It Runs |
|-------|------------------|-------|--------------|
| **1. Local** | Pre-commit hooks | 30+ checks (secrets, syntax, style) | Before `git commit` |
| **2. CI/CD** | GitHub Actions | 18 automated jobs | On PR & push |
| **3. Branch** | Protection rules | Required reviews + passing checks | Before merge |
| **4. Organization** | GitHub policies | Global defaults | Always |

### 🚀 Quick Security Setup (10 minutes)

```powershell
# 1. Install pre-commit framework
pip install pre-commit

# 2. Install hooks (one-time)
cd C:\Users\kolod\Desktop\LKP\05_BCU\INFRA\zsel-eip-infra
pre-commit install
pre-commit install --hook-type commit-msg

# 3. Test installation
pre-commit run --all-files

# ✅ Done! All commits now automatically validated
```

### 📚 Security Documentation

- **[SECURITY-SETUP.md](SECURITY-SETUP.md)** - Complete setup guide with verification tests
- **[SECURITY.md](SECURITY.md)** - Security policy & vulnerability reporting process
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Development workflow & code standards
- **[CODEOWNERS](CODEOWNERS)** - Automatic PR reviewer assignment

### 🛡️ What Gets Checked

**Secret Scanning:**
- Hardcoded passwords, API keys, tokens
- AWS credentials, private keys
- RouterOS passwords, connection strings

**Code Security:**
- PowerShell: PSScriptAnalyzer, credential detection
- Python: Bandit (security), Safety (vulnerabilities)
- Terraform: TFSec, Checkov, TFLint

**Code Quality:**
- Python: Black (formatting), Flake8 (linting), Pylint (quality)
- YAML: yamllint, schema validation
- Markdown: markdownlint, broken link check

**Repository Hygiene:**
- File size limits (10MB max)
- Merge conflict detection
- Trailing whitespace, line endings
- Commit message conventions

### ⚠️ Before Your First Commit

1. **Read the guides:**
   - [CONTRIBUTING.md](CONTRIBUTING.md) - How to contribute
   - [SECURITY.md](SECURITY.md) - Security requirements

2. **Install tools:**
   ```powershell
   # Pre-commit framework
   pip install pre-commit
   
   # PowerShell (if editing .ps1 files)
   Install-Module -Name PSScriptAnalyzer -Scope CurrentUser
   
   # Python (if editing .py files)
   pip install black flake8 pylint bandit
   
   # Terraform (if editing .tf files)
   choco install tflint terraform-docs
   ```

3. **Configure Git:**
   ```powershell
   # Set commit signature (optional but recommended)
   git config user.name "Your Name"
   git config user.email "your.email@zsel.opole.pl"
   
   # Enable GPG signing (optional)
   git config commit.gpgsign true
   ```

4. **Test your setup:**
   ```powershell
   # Create test file with intentional issue
   echo "password = 'admin123'" > test.txt
   git add test.txt
   git commit -m "test: verify pre-commit hooks"
   
   # ✅ Should BLOCK commit with secret detection error
   rm test.txt
   ```

### 🔐 Security Features

- ✅ **Secret scanning** - TruffleHog, GitLeaks, detect-secrets
- ✅ **Dependency scanning** - Dependabot, Safety (Python)
- ✅ **Code analysis** - PSScriptAnalyzer, Bandit, TFSec
- ✅ **Vulnerability reporting** - Private email channel
- ✅ **Branch protection** - Required reviews + status checks
- ✅ **Automated testing** - Pester (PowerShell), pytest (Python)
- ✅ **Code owners** - Automatic reviewer assignment
- ✅ **Issue templates** - Standardized bug/feature/security reports
- ✅ **PR templates** - 50+ item checklist

### 📊 Security Monitoring

GitHub Actions run automatically on:
- Every push to `main` or `develop`
- Every pull request
- Daily at 2:00 AM UTC (security scans)

View results: [Actions tab](../../actions)

---

## 📊 Network Structure (PFU 2.7 Compliant)

### VLANs Overview (30 total)

| VLAN Range | Count | Purpose | Addressing |
|------------|-------|---------|------------|
| **101-104** | 4 | Sale dydaktyczne (per piętro) | `192.168.[1-4].0/24` |
| **110** | 1 | **Klaster Kubernetes (K3s)** | `192.168.10.0/24` |
| **208-246** | 15 | **Pracownie uczniowskie** (sale 8,9,23-31,41-46) | `10.[NR_SALI].0.0/16` |
| **300-303** | 4 | WiFi uczniowska (per piętro) | `10.100.[1-4].0/24` |
| **400-401** | 2 | Serwery uczniowskie | `10.200.[100,200].0/24` |
| **500** | 1 | Sieć administracyjna | `172.20.20.0/24` |
| **501** | 1 | Kamery CCTV | `172.21.1.0/24` |
| **600** | 1 | Zarządzanie infrastrukturą | `192.168.255.0/28` |

### VLAN 110: Kubernetes Cluster (K3s)

**Architektura: 1 klaster K3s - 9 × Mac Pro M2 Ultra**

```
Control Plane (HA etcd):
├── k3s-master-01  192.168.10.11  (etcd leader candidate)
├── k3s-master-02  192.168.10.12  (etcd member)
└── k3s-master-03  192.168.10.13  (etcd member)

Worker Nodes (specialized workloads):
├── k3s-worker-01  192.168.10.14  [education]   → Moodle, BBB, NextCloud
├── k3s-worker-02  192.168.10.15  [education]   → Mattermost, OnlyOffice
├── k3s-worker-03  192.168.10.16  [devops]      → GitLab, Harbor
├── k3s-worker-04  192.168.10.17  [ai-ml]       → Ollama, JupyterHub
├── k3s-worker-05  192.168.10.18  [analytics]   → Prometheus, Grafana
└── k3s-worker-06  192.168.10.19  [storage]     → Longhorn, MinIO

MetalLB LoadBalancer Pools:
├── PROD:  192.168.10.20-.51   (32 IPs)
└── DEV:   192.168.10.101-.150 (50 IPs)

Total: 216 CPU cores, 1728 GB RAM, 72 TB storage, 39 apps
```

**BGP:** CCR2216-BCU-01 (AS 65000) ↔ K3s (AS 65001) - 3 peers

### VLAN 208-246: Pracownie (Physical Rooms)
```
VLAN = Numer SALI FIZYCZNEJ (nie klasy uczniowskiej!)

Parter:     VLAN 208, 209 = Sale 8, 9
Piętro I:   VLAN 223-225 = Sale 23-25
Piętro II:  VLAN 226-228, 230-231 = Sale 26-28, 30-31
Piętro III: VLAN 241-244, 246 = Sale 41-44, 46
```

### QoS Policies (PFU 2.7)
```yaml
Pracownie (VLAN 208-246):  60M/60M (burst 80M, 30s)
Sale dydaktyczne (101-104): 1000M/1000M per piętro
WiFi uczniowska (300-303):  200M/200M per piętro
Administracja (500):        unlimited
CCTV (501):                 100M/100M
Management (600):           unlimited (priority 7)
```

---

## 🔧 Maintenance Workflow

### Adding New VLAN
```bash
# 1. Edit YAML (single source of truth)
code common/vlans-master.yaml

# 2. Add VLAN definition (example):
vlans:
  labs:
    - sala: 47
      vlan_id: 247
      subnet: "10.47.0.0/16"
      gateway: "10.47.0.1"
      floor: "P3"
      type: "mobile"
      ports: 18

# 3. Regenerate Terraform
python scripts/generate-terraform.py

# 4. Review & deploy
cd zsel-eip-tf-infra/environments/networking-prod
terraform validate
terraform plan
terraform apply
```

### Modifying QoS
```bash
# 1. Edit qos_policies section in vlans-master.yaml
qos_policies:
  labs:
    max_limit: "100M/100M"  # Changed from 60M
    burst_limit: "120M/120M"

# 2. Regenerate & redeploy
python scripts/generate-terraform.py
terraform apply
```

---

## 📚 Documentation

### Key Files
- **`common/vlans-master.yaml`** - Single source of truth (324 lines)
  - VLANs definition (29 VLANs)
  - QoS policies (PFU 2.7 compliant)
  - BGP configuration (MetalLB peering)
  - Firewall rules matrix
  - Device inventory (57 MikroTik devices)

- **`scripts/generate-terraform.py`** - Python generator (280 lines)
  - Reads YAML → generates Terraform HCL
  - Functions: `generate_vlans()`, `generate_qos()`, `generate_bgp()`
  - Output: `prod-values-generated.auto.tfvars`

### Related Repositories
- **zsel-eip-network** - Network documentation (VLAN-ROUTING-FIREWALL.md, PFU compliance)
- **zsel-eip-ansible** - Ansible playbooks (for 56 MikroTik devices)
- **zsel-eip-dokumentacja** - Full PFU documentation (architektura/pfu.md)
- **zsel-eip-gitops** - K3s GitOps configuration (ArgoCD, MetalLB, BGP)

---

## 🏗️ Architecture

### Deployment Strategy
```
Terraform (1 device):    CCR2216-BCU-01 (core router)
                         ↓ manages configuration
                         
Ansible (56 devices):    Remaining MikroTik switches
                         ↓ propagates config from core
```

### Single Source of Truth Flow
```
Edit vlans-master.yaml
    ↓
python generate-terraform.py
    ↓
prod-values.auto.tfvars (Terraform)
    ↓
terraform apply → CCR2216-BCU-01
    ↓
ansible-playbook → 56 devices
```

---

## ⚠️ Important Notes

1. **DO NOT edit `prod-values.auto.tfvars` manually!**
   - Always edit `common/vlans-master.yaml`
   - Run `generate-terraform.py` to regenerate

2. **VLAN 208-246 = Physical room numbers** (not class names!)
   - Example: VLAN 208 = Sala 8 (not "klasa 1AT")
   - See PFU 2.7 documentation for room mapping

3. **Backup before changes:**
   ```bash
   mv prod-values.auto.tfvars prod-values-$(date +%Y%m%d).backup
   ```

4. **Always validate:**
   ```bash
   terraform validate
   terraform plan  # Review before apply!
   ```

---

## 👥 Team

- **Network Team:** network@zsel.opole.pl
- **DevOps Team:** devops@zsel.opole.pl
- **IT Admin:** it@zsel.opole.pl

---

## 📄 Compliance

- **PFU 2.7** - Program Funkcjonalno-Użytkowy (Branżowe Centrum Umiejętności)
- **Naming Convention:** `<MODEL>-<RODZAJ>-<LOKALIZACJA>-<NR>`
- **QoS Requirements:** 60M (pracownie), 200M (WiFi), 1000M (dydaktyczne)
- **Security:** SSH only (port 2222), Telnet/HTTP disabled

---

---

## 🚀 Organization-Wide Security Rollout

**Status:** 1/25 repositories secured (4% complete)

### 📊 Current State
```
█░░░░░░░░░░░░░░░░░░░░ 4% (1/25 repos)
```

**Completed:** zsel-eip-infra ✅  
**Pending:** 24 repositories (see [STATUS.md](STATUS.md))

### 📚 Rollout Documentation

| Document | Purpose | Lines |
|----------|---------|-------|
| **[STATUS.md](STATUS.md)** | Current deployment status & metrics | 240+ |
| **[QUICK-START.md](QUICK-START.md)** | 3-command deployment guide | 320+ |
| **[ROLLOUT-PLAN.md](ROLLOUT-PLAN.md)** | Complete 4-phase rollout strategy | 350+ |
| **[DEPLOYMENT-STATUS.md](DEPLOYMENT-STATUS.md)** | Initial deployment report | 280+ |

### 🎯 Quick Deploy (All Remaining 24 Repos)

```powershell
# Navigate to scripts
cd c:\Users\kolod\Desktop\LKP\05_BCU\INFRA\zsel-eip-infra\scripts

# Phase 1: Deploy to 6 core repos (Week 1)
.\Deploy-Batch.ps1 -Phase 1

# Phase 2: Deploy to 17 Terraform modules (Week 2)
.\Deploy-Batch.ps1 -Phase 2

# Phase 3: Configure .github org repo (Week 2)
# Manual configuration needed

# Phase 4: Deploy self-hosted K8s runners (Week 3)
# See ROLLOUT-PLAN.md Phase 4
```

### 📋 3-Week Timeline

**Week 1** (Phase 1): Core repos (gitops, network, ansible, dokumentacja, opole, opole-ad)  
**Week 2** (Phase 2-3): Terraform modules (17) + org config  
**Week 3** (Phase 4): Self-hosted runners on Kubernetes cluster  

**Total time:** ~40 hours (can parallelize to ~10 hours)

### 🔒 No Exceptions Policy

After Phase 1 testing, **ALL users** (including admins) must:
- ✅ Create PRs (NO direct push to main)
- ✅ Get 1 code owner approval
- ✅ Pass all CI/CD checks (18 jobs)
- ✅ Resolve all conversations

**Setting:** `enforce_admins: true` (will be enabled after Week 1)

### 🎯 Project Tracking

All rollout progress tracked in:  
**[GitHub Project #2 - Security Framework Rollout](https://github.com/orgs/ZSEL-OPOLE/projects/2)**

---

**Last updated:** 2025-01-19  
**Security framework:** ✅ Production-ready  
**Rollout status:** 1/25 repos (4%)  
**PFU Compliance:** ✅ 2.7  
**VLANs:** 29 (15 pracownie + 4 dydaktyczne + 10 infrastruktury)
