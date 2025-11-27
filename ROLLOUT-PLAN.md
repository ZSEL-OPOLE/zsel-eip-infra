# 🚀 Security Framework Rollout Plan

**Organization:** ZSEL-OPOLE  
**Total Repositories:** 25  
**Project Tracking:** https://github.com/orgs/ZSEL-OPOLE/projects/2  
**Start Date:** 2025-11-27  
**Target Completion:** 2025-12-15

---

## 📊 Current Status

**Completed (1/25):**
- ✅ `zsel-eip-infra` - Full security framework deployed

**Pending (24/25):**
- ⏳ 6 main repositories
- ⏳ 17 Terraform modules
- ⏳ 1 organization config (.github)

---

## 🎯 Rollout Strategy

### Phase 1: Core Infrastructure Repos (Priority: HIGH)
**Timeline:** Week 1 (2025-11-27 to 2025-12-03)  
**Scope:** Main repositories with active development

| # | Repository | Type | Priority | Estimated Time | Status |
|---|------------|------|----------|----------------|--------|
| 1 | ✅ zsel-eip-infra | Infrastructure | P0 | - | DONE |
| 2 | ⏳ zsel-eip-gitops | GitOps/K8s | P0 | 2h | TODO |
| 3 | ⏳ zsel-eip-network | Network Config | P0 | 2h | TODO |
| 4 | ⏳ zsel-eip-ansible | Automation | P1 | 2h | TODO |
| 5 | ⏳ zsel-eip-dokumentacja | Documentation | P1 | 1.5h | TODO |
| 6 | ⏳ zsel-opole | Main Project | P1 | 2h | TODO |
| 7 | ⏳ zsel-opole-ad | Active Directory | P1 | 1.5h | TODO |

**Total Phase 1:** 11 hours

### Phase 2: Terraform Modules (Priority: MEDIUM)
**Timeline:** Week 2 (2025-12-04 to 2025-12-10)  
**Scope:** All Terraform modules (batch deployment)

**MikroTik Modules (11):**
- ⏳ zsel-eip-tf-module-mikrotik-system
- ⏳ zsel-eip-tf-module-mikrotik-interfaces
- ⏳ zsel-eip-tf-module-mikrotik-firewall
- ⏳ zsel-eip-tf-module-mikrotik-dhcp-server
- ⏳ zsel-eip-tf-module-mikrotik-bridge-vlan-filtering
- ⏳ zsel-eip-tf-module-mikrotik-users
- ⏳ zsel-eip-tf-module-mikrotik-ip-addressing
- ⏳ zsel-eip-tf-module-mikrotik-routing
- ⏳ zsel-eip-tf-module-mikrotik-vpn
- ⏳ zsel-eip-tf-module-mikrotik-vlans
- ⏳ zsel-eip-tf-module-storage-longhorn

**Kubernetes Modules (4):**
- ⏳ zsel-eip-tf-module-k8s-rbac
- ⏳ zsel-eip-tf-module-k8s-network-policies
- ⏳ zsel-eip-tf-module-k8s-namespaces
- ⏳ zsel-eip-tf-module-k8s-argocd

**Active Directory Modules (2):**
- ⏳ zsel-eip-tf-module-ad-user-ad
- ⏳ zsel-eip-tf-module-ad-network-ad

**Estimated Time:** 1h per module × 17 = 17 hours (can be parallelized)

### Phase 3: Organization Config (Priority: HIGH)
**Timeline:** Week 2 (2025-12-04 to 2025-12-10)  
**Scope:** Organization-level configurations

| # | Repository | Type | Priority | Estimated Time | Status |
|---|------------|------|----------|----------------|--------|
| 1 | ⏳ .github | Org Config | P0 | 3h | TODO |

**Contents:**
- Default community health files
- Organization-wide workflow templates
- Issue/PR templates for all repos
- Dependabot config
- Security policies

### Phase 4: Self-Hosted Runners (Priority: HIGH)
**Timeline:** Week 3 (2025-12-11 to 2025-12-15)  
**Scope:** Kubernetes-based GitHub Actions runners

**Tasks:**
1. ⏳ Deploy Actions Runner Controller (ARC) on K8s
2. ⏳ Configure runner scale sets
3. ⏳ Update workflows to use self-hosted runners
4. ⏳ Test runner performance and scaling
5. ⏳ Document runner maintenance procedures

**Estimated Time:** 8 hours

---

## 🔧 Deployment Checklist (Per Repository)

### Automated Deployment Script:
```powershell
# deploy-security-framework.ps1
param(
    [string]$TargetRepo,
    [string]$SourceRepo = "zsel-eip-infra"
)

# 1. Copy security files
# 2. Adjust for repo-specific needs
# 3. Create PR (not direct push - enforce policy!)
# 4. Wait for approval
# 5. Merge and verify
```

### Manual Steps (Per Repo):
- [ ] Copy security framework files from zsel-eip-infra
- [ ] Adjust `.pre-commit-config.yaml` for repo type (Terraform/Python/Mixed)
- [ ] Update `CODEOWNERS` with relevant teams
- [ ] Adjust `README.md` with security section
- [ ] **Create Pull Request** (NO direct push to main!)
- [ ] Wait for 1 approval from code owner
- [ ] Verify all checks pass
- [ ] Merge PR
- [ ] Configure branch protection rules
- [ ] Add repository to relevant teams
- [ ] Test workflow on real PR

**Time per repo:** ~1-2 hours

---

## 👥 No Exceptions Policy

### Rules Apply to EVERYONE (Including Admins):

✅ **Enforced Rules:**
1. All changes via Pull Requests (NO direct push to main)
2. Minimum 1 code owner review required
3. All CI/CD checks must pass
4. Linear history only (rebase, no merge commits)
5. Pre-commit hooks must pass locally
6. GPG signed commits (recommended)

✅ **Admin Override:**
- Available but LOGGED in audit trail
- Only for emergencies (production down, security hotfix)
- Must be documented in PR description
- Requires post-incident review

✅ **Bypass Prevention:**
```json
{
  "enforce_admins": true,  // ← Enable this in Phase 2
  "required_pull_request_reviews": {
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1
  }
}
```

**Current Status:**
- ❌ `enforce_admins`: false (allows admin bypass)
- **TODO:** Enable after testing PR workflow

---

## 🏗️ Self-Hosted Runners Architecture

### Why Self-Hosted Runners?

**Current (GitHub-hosted):**
- ✅ Free tier: 2,000 minutes/month
- ❌ Limited to public repos (free tier)
- ❌ No access to internal resources
- ❌ Cannot scale beyond GitHub limits
- ❌ No control over runner environment

**Future (Self-hosted on K8s):**
- ✅ Unlimited minutes
- ✅ Access to internal network (databases, services)
- ✅ Custom tools pre-installed
- ✅ Auto-scaling based on workload
- ✅ Cost-effective for heavy CI/CD
- ✅ Dedicated resources for critical jobs

### Implementation Plan:

**1. Actions Runner Controller (ARC) Setup:**
```bash
# Install ARC on K8s cluster
helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
helm upgrade --install arc \
  --namespace actions-runner-system \
  --create-namespace \
  actions-runner-controller/actions-runner-controller \
  --set authSecret.github_token=$GITHUB_PAT
```

**2. Runner Scale Set Configuration:**
```yaml
# runner-scale-set.yaml
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: zsel-opole-runners
  namespace: actions-runner-system
spec:
  replicas: 3  # Minimum runners
  template:
    spec:
      repository: ZSEL-OPOLE/*  # All repos
      labels:
        - self-hosted
        - kubernetes
        - zsel-runner
      resources:
        limits:
          cpu: "2"
          memory: 4Gi
        requests:
          cpu: "1"
          memory: 2Gi
      # Auto-scaling
      workVolumeClaimTemplate:
        storageClassName: longhorn
        resources:
          requests:
            storage: 50Gi
```

**3. Workflow Migration:**
```yaml
# Before (GitHub-hosted)
runs-on: ubuntu-latest

# After (Self-hosted)
runs-on: [self-hosted, kubernetes, zsel-runner]
```

**4. Runner Images:**
- Base: Ubuntu 22.04
- Pre-installed:
  - Docker
  - Terraform (latest)
  - Python 3.12
  - PowerShell 7
  - kubectl, helm, argocd CLI
  - Pre-commit framework
  - All security tools (TruffleHog, Checkov, etc.)

**5. Security:**
- Runners in isolated namespace
- Network policies restrict egress
- Secrets via Kubernetes secrets (sealed-secrets)
- Auto-rotation of runner tokens
- Audit logging enabled

**6. Monitoring:**
```yaml
# Prometheus metrics
actions_runner_queue_depth
actions_runner_job_duration_seconds
actions_runner_success_rate
actions_runner_pod_restarts
```

**7. Maintenance:**
- Weekly runner image updates
- Auto-cleanup of completed jobs
- Log rotation (7 days retention)
- Health checks every 5 minutes

**Estimated Cost Savings:**
- GitHub Actions minutes (2,000 → unlimited): $0
- Runner compute (K8s existing): $0
- Reduced workflow time (10-20% faster): Priceless

---

## 📋 Tracking & Accountability

### GitHub Project Board:
**URL:** https://github.com/orgs/ZSEL-OPOLE/projects/2

**Columns:**
1. 📋 Backlog
2. 🏗️ In Progress
3. 👀 Review
4. ✅ Done

### Issue Templates:

**For Each Repository:**
```markdown
Title: [SECURITY] Deploy security framework to {repo-name}

Labels: security, infrastructure, rollout

Assignee: @infrastructure-team

Tasks:
- [ ] Copy framework files
- [ ] Adjust for repo type
- [ ] Create PR (no direct push!)
- [ ] Get code owner approval
- [ ] Merge PR
- [ ] Configure branch protection
- [ ] Add to teams
- [ ] Verify workflow

Estimated: 2 hours
```

### Progress Tracking:

**Daily Standup Questions:**
1. Which repos were completed yesterday?
2. Which repos are blocked?
3. What's the plan for today?

**Weekly Review:**
- % completion
- Blockers identified
- Adjust timeline if needed

---

## 🎯 Success Metrics

### Phase 1 (Core Repos):
- [ ] 7/7 repos with security framework
- [ ] 100% PR workflow adoption
- [ ] 0 direct pushes to main
- [ ] All teams trained

### Phase 2 (Terraform Modules):
- [ ] 17/17 modules protected
- [ ] Consistent security across modules
- [ ] Module testing automated

### Phase 3 (Org Config):
- [ ] .github repo configured
- [ ] Default templates active
- [ ] Dependabot enabled org-wide

### Phase 4 (Self-Hosted Runners):
- [ ] ARC deployed on K8s
- [ ] 3+ runners always available
- [ ] <30s job queue time
- [ ] All workflows migrated
- [ ] 95%+ runner uptime

### Overall:
- [ ] 25/25 repos secured
- [ ] 100% enforcement of branch policy
- [ ] Zero security incidents
- [ ] <2 minutes average PR review time
- [ ] Self-hosted runners operational

---

## 📞 Support & Questions

**Primary Contact:** @ZSEL-OPOLE/infrastructure-team  
**Security Lead:** @ZSEL-OPOLE/security-team  
**DevOps Support:** @ZSEL-OPOLE/devops-team

**Documentation:**
- [SECURITY-SETUP.md](SECURITY-SETUP.md) - Setup guide
- [CONTRIBUTING.md](CONTRIBUTING.md) - Development workflow
- [DEPLOYMENT-STATUS.md](DEPLOYMENT-STATUS.md) - Current status

**Slack Channels (if available):**
- #infrastructure
- #security
- #devops

---

## 🚨 Rollback Plan

**If Issues Arise:**

1. **Minor Issues** (linting warnings):
   - Fix in follow-up PR
   - Document in known issues

2. **Blocking Issues** (workflow broken):
   - Revert PR
   - Fix in zsel-eip-infra
   - Test thoroughly
   - Re-deploy

3. **Critical Issues** (repo unusable):
   - Admin override to disable protection
   - Emergency hotfix
   - Post-incident review
   - Update rollout plan

**Rollback Checklist:**
- [ ] Identify affected repos
- [ ] Document issue
- [ ] Revert changes
- [ ] Test fix
- [ ] Re-deploy with fix
- [ ] Update documentation

---

**Last Updated:** 2025-11-27  
**Next Review:** 2025-12-01  
**Maintained by:** @ZSEL-OPOLE/infrastructure-team
