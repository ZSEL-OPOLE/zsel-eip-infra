# 🔄 GitFlow Workflow - Quality Gating Strategy

## 📋 Przegląd

Wdrożono **GitFlow** z 3-poziomowym quality gating:

```
feature/xyz → develop (testing) → main (production)
    ↓            ↓ 1 week           ↓
  PR review   Stabilność      Auto-deploy PROD
```

---

## 🌳 Branch Strategy

### **main** (Production)
- **Chroniony**: enforce_admins=true
- **Tylko z develop**: Po 1 tygodniu stabilności
- **Auto-deploy**: Wszystkie środowiska PROD
- **Rollback**: Możliwy w trybie emergency

### **develop** (Testing/Staging)
- **Chroniony**: enforce_admins=true
- **Merge z**: feature/*, bugfix/*, hotfix/*
- **Testing**: Automatyczne testy + manualne QA
- **Stabilność**: Minimum 1 tydzień przed main
- **CI/CD**: Deploy do środowisk DEV/TEST

### **feature/*** (Development)
- **Tworzone od**: develop
- **Merge do**: develop (via PR)
- **Naming**: feature/ISSUE-123-short-description
- **Lifetime**: Do merge (potem delete)

---

## 🚦 Quality Gates

### **Gate 1: Feature → Develop**

**Automatyczne checks (18 jobs):**
- ✅ Secret detection (3 tools)
- ✅ Code security (PSScriptAnalyzer, Bandit, TFSec)
- ✅ Validation (YAML, JSON, Markdown)
- ✅ Code quality (linting, formatting)
- ✅ Pre-commit hooks (30+ checks)

**Manualne requirements:**
- ✅ 1 code owner approval
- ✅ All conversations resolved
- ✅ PR description complete
- ✅ Tests passing

**Czas**: ~30 minut (automated) + review time

---

### **Gate 2: Develop → Main (1 Week Stability)**

**Kryteria stabilności:**
- ✅ No critical bugs w develop przez 7 dni
- ✅ All tests passing przez 7 dni
- ✅ No hotfixes needed
- ✅ QA sign-off
- ✅ Stakeholder approval

**Automatyczne checks:**
- ✅ Same as Gate 1 (18 jobs)
- ✅ Integration tests
- ✅ Performance tests (optional)
- ✅ Security scan (daily)

**Manualne requirements:**
- ✅ 2 code owner approvals (senior devs)
- ✅ Release notes prepared
- ✅ Rollback plan documented
- ✅ Production deploy scheduled

**Czas**: 7 dni minimum

---

## 📝 Workflow Examples

### **Nowa funkcja (Normal Flow)**

```bash
# 1. Utwórz feature branch od develop
git checkout develop
git pull origin develop
git checkout -b feature/SEC-123-add-security-framework

# 2. Pracuj, commituj
git add .
git commit -m "feat(security): add framework files"
git push origin feature/SEC-123-add-security-framework

# 3. Utwórz PR: feature/* → develop
gh pr create --base develop --title "feat: Add security framework"

# 4. Review + CI/CD → Merge do develop
# Auto-deploy to DEV/TEST environments

# 5. Czekaj 1 tydzień (stabilność w develop)

# 6. Utwórz PR: develop → main
gh pr create --base main --head develop --title "release: Security framework v1.0"

# 7. Review + approval → Merge do main
# Auto-deploy to PROD environments
```

---

### **Hotfix (Emergency)**

```bash
# 1. Utwórz hotfix branch od main
git checkout main
git pull origin main
git checkout -b hotfix/CRIT-456-fix-security-vuln

# 2. Napraw bug
git add .
git commit -m "fix(security)!: patch critical vulnerability"
git push origin hotfix/CRIT-456-fix-security-vuln

# 3. PR do main (emergency)
gh pr create --base main --title "hotfix: Critical security patch"

# 4. Fast-track approval (2 senior devs)
# Skip 1-week wait (emergency only!)

# 5. Merge → Auto-deploy PROD

# 6. Backport do develop
git checkout develop
git merge main
git push origin develop
```

---

### **Release (Planned)**

```bash
# 1. Przygotuj release branch od develop
git checkout develop
git pull origin develop
git checkout -b release/v1.2.0

# 2. Bump versions, update changelog
# No new features! Only fixes/polish

# 3. PR do main
gh pr create --base main --head release/v1.2.0 --title "release: v1.2.0"

# 4. Approval + merge → Deploy PROD

# 5. Tag release
git checkout main
git pull origin main
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin v1.2.0

# 6. Merge back to develop
git checkout develop
git merge main
git push origin develop

# 7. Delete release branch
git branch -d release/v1.2.0
git push origin --delete release/v1.2.0
```

---

## ⏱️ Timelines

| Action | Gate | Time | Auto/Manual |
|--------|------|------|-------------|
| PR Creation | - | 5 min | Auto |
| CI/CD Checks | Gate 1 | 10 min | Auto |
| Code Review | Gate 1 | 1-24h | Manual |
| Merge to develop | Gate 1 | 1 min | Auto |
| Deploy to DEV/TEST | - | 5-10 min | Auto |
| Stabilization | Gate 2 | 7 days | Monitor |
| Release PR | Gate 2 | 5 min | Manual |
| Senior approvals | Gate 2 | 1-48h | Manual |
| Merge to main | Gate 2 | 1 min | Auto |
| Deploy to PROD | - | 10-30 min | Auto |

**Total (feature → PROD)**: ~8-10 dni

---

## 🔒 Branch Protection Rules

### **main** (Production)

```json
{
  "required_status_checks": ["18 CI/CD jobs"],
  "enforce_admins": true,
  "required_approving_review_count": 2,
  "require_code_owner_reviews": true,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
```

**Konfiguracja:**
```bash
gh api repos/ZSEL-OPOLE/{repo}/branches/main/protection \
  -X PUT --input .github/branch-protection-main.json
```

---

### **develop** (Testing)

```json
{
  "required_status_checks": ["18 CI/CD jobs"],
  "enforce_admins": true,
  "required_approving_review_count": 1,
  "require_code_owner_reviews": true,
  "required_linear_history": true
}
```

**Konfiguracja:**
```bash
gh api repos/ZSEL-OPOLE/{repo}/branches/develop/protection \
  -X PUT --input .github/branch-protection-develop.json
```

---

## 🚀 Deployment Strategy

### **Environments**

| Environment | Branch | Purpose | Auto-deploy | Access |
|-------------|--------|---------|-------------|--------|
| **LOCAL** | feature/* | Development | No | Developers |
| **DEV** | develop | Integration testing | Yes | Developers + QA |
| **TEST** | develop | QA testing | Yes | QA Team |
| **STAGING** | develop | Pre-prod validation | Yes (manual trigger) | QA + Stakeholders |
| **PROD** | main | Production | Yes (after approval) | End users |

---

### **Auto-deploy Rules**

```yaml
# .github/workflows/deploy.yml
on:
  push:
    branches:
      - develop  # → Deploy to DEV/TEST
      - main     # → Deploy to PROD
  pull_request:
    branches:
      - develop  # → Deploy to PR preview
      - main     # → No preview (security)
```

**Develop pushes:**
- ✅ Auto-deploy to DEV
- ✅ Auto-deploy to TEST
- ✅ Notify QA team
- ✅ Run integration tests

**Main pushes:**
- ✅ Create GitHub Release
- ✅ Tag version
- ✅ Deploy to PROD (all services)
- ✅ Notify stakeholders
- ✅ Update documentation

---

## 📊 Metrics & Monitoring

### **Develop Branch (7-Day Window)**

**Daily checks:**
- ✅ CI/CD success rate (must be 100%)
- ✅ Test coverage (target >80%)
- ✅ No critical/high security vulnerabilities
- ✅ No performance regressions
- ✅ Error rate in DEV/TEST (target <1%)

**Weekly review:**
- ✅ All tests passing
- ✅ No open critical bugs
- ✅ QA sign-off received
- ✅ Documentation updated

**Dashboard:**
```bash
# Check develop stability
gh api repos/ZSEL-OPOLE/{repo}/commits/develop/status

# Check test results
gh run list --branch develop --limit 50

# Check issues
gh issue list --label "critical,bug" --json number,title
```

---

## ⚠️ Emergency Procedures

### **Hotfix (Skip 7-Day Wait)**

**Allowed when:**
- 🔴 Critical security vulnerability
- 🔴 Production down
- 🔴 Data loss risk
- 🔴 Legal/compliance issue

**Process:**
1. Create `hotfix/*` from main
2. Fix ONLY the critical issue
3. PR to main with label `emergency`
4. Require 2 senior approvals
5. Fast-track CI/CD (all must pass)
6. Deploy to PROD
7. Backport to develop immediately

**Example:**
```bash
git checkout -b hotfix/CVE-2024-12345-critical-patch main
# Fix vulnerability
gh pr create --base main --label emergency --title "HOTFIX: CVE-2024-12345"
# After merge:
git checkout develop && git merge main && git push
```

---

### **Rollback**

**If PROD deployment fails:**

```bash
# 1. Identify last good commit
git log main --oneline -10

# 2. Create rollback branch
git checkout -b rollback/revert-bad-deploy main

# 3. Revert bad commits
git revert <bad-commit-sha>

# 4. Emergency PR
gh pr create --base main --label emergency --title "ROLLBACK: Revert failed deployment"

# 5. Fast-track → Deploy
```

---

## 📚 Documentation Requirements

### **Feature PR (feature → develop)**

Required in PR description:
- ✅ What changed (features, files)
- ✅ Why changed (issue, requirement)
- ✅ How to test
- ✅ Screenshots (if UI)
- ✅ Breaking changes (if any)

---

### **Release PR (develop → main)**

Required:
- ✅ **CHANGELOG.md** updated
- ✅ Version bumped (semver)
- ✅ Release notes prepared
- ✅ Migration guide (if breaking)
- ✅ Rollback plan documented
- ✅ Stakeholder approval email

**Template:**
```markdown
## Release v1.2.0

### 📦 Changes (since v1.1.0)
- feat: Added security framework (#123)
- fix: Fixed authentication bug (#124)
- docs: Updated README (#125)

### ✅ Stability Metrics (7 days)
- CI/CD success: 100% (70/70 builds)
- Test coverage: 85%
- Critical bugs: 0
- QA sign-off: ✅ 2024-11-20

### 🚀 Deployment Plan
- Date: 2024-11-27 14:00 CET
- Downtime: None (rolling deploy)
- Rollback: Available (v1.1.0)

### 👥 Approvals
- QA: @qa-lead ✅
- DevOps: @devops-lead ✅
- Product: @product-owner ✅
```

---

## 🎯 Best Practices

### **DO:**
- ✅ Always create feature branches from develop
- ✅ Keep feature branches small (<500 lines)
- ✅ Rebase feature branches regularly
- ✅ Delete merged feature branches
- ✅ Wait full 7 days for develop → main
- ✅ Document all changes
- ✅ Test locally before PR
- ✅ Review others' PRs

### **DON'T:**
- ❌ Never push directly to main or develop
- ❌ Never force-push to protected branches
- ❌ Never skip CI/CD checks
- ❌ Never merge without approval
- ❌ Never deploy PROD on Friday 🙂
- ❌ Never skip the 7-day stabilization (except emergency)
- ❌ Never merge develop → main with failing tests

---

## 🔧 Setup Commands

### **1. Create develop branch**

```bash
# For each repo
cd /path/to/repo
git checkout main
git pull origin main
git checkout -b develop
git push origin develop

# Set as default branch for new clones (optional)
gh repo edit --default-branch develop
```

---

### **2. Configure branch protection**

```bash
# Protect main
gh api repos/ZSEL-OPOLE/{repo}/branches/main/protection \
  -X PUT --input .github/branch-protection-main.json

# Protect develop
gh api repos/ZSEL-OPOLE/{repo}/branches/develop/protection \
  -X PUT --input .github/branch-protection-develop.json
```

---

### **3. Update workflows**

Edit `.github/workflows/security-checks.yml`:
```yaml
on:
  push:
    branches: [main, develop]  # Add develop!
  pull_request:
    branches: [main, develop]  # Add develop!
```

---

### **4. Setup auto-deploy**

Create `.github/workflows/deploy.yml`:
```yaml
name: Deploy

on:
  push:
    branches:
      - develop  # Deploy to DEV/TEST
      - main     # Deploy to PROD

jobs:
  deploy-dev:
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to DEV
        run: |
          echo "Deploying to DEV environment..."
          # Your deploy commands here

  deploy-prod:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production  # Requires manual approval
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to PROD
        run: |
          echo "Deploying to PROD environment..."
          # Your deploy commands here
```

---

## 📊 Success Metrics

| Metric | Target | Measure |
|--------|--------|---------|
| CI/CD success rate | >95% | GitHub Actions |
| PR review time | <24h | GitHub Insights |
| Deploy frequency | 1-2×/week | GitHub Releases |
| Lead time (dev→prod) | 8-10 days | Manual tracking |
| Failed deployments | <5% | Monitoring |
| Rollbacks | <2% | Git history |
| Hotfixes | <1/month | Git branches |

---

## 🔗 Resources

- **GitHub Flow**: https://docs.github.com/en/get-started/quickstart/github-flow
- **GitFlow**: https://nvie.com/posts/a-successful-git-branching-model/
- **Semantic Versioning**: https://semver.org/
- **Conventional Commits**: https://www.conventionalcommits.org/

---

**Wdrożono:** 2024-11-27  
**Następna aktualizacja:** Po 1 miesiącu (2024-12-27)  
**Odpowiedzialny:** Infrastructure Team
