# GitHub Copilot Auto-Review & Approve

## 🤖 Automated Code Review with GitHub Copilot

GitHub Copilot automatycznie review'uje i approve'uje PRs spełniające kryteria bezpieczeństwa.

---

## 📋 Jak to działa

### 1. **Copilot Review (każdy PR)**

Dla każdego PR do `develop` lub `main`:

```yaml
✅ Automatyczna analiza:
  - Security vulnerabilities
  - Code quality & best practices
  - Performance issues
  - Documentation completeness
  - Test coverage
```

**Output:**
- Komentarz z podsumowaniem
- Security score
- Quality score (0-100)
- Complexity level
- Sugestie poprawek

---

### 2. **Auto-Approve dla develop (bezpieczne zmiany)**

Copilot automatycznie **approve'uje** PR do `develop` jeśli:

#### ✅ Kryteria Auto-Approve:

| Kategoria | Warunek |
|-----------|---------|
| **Dokumentacja** | Tylko pliki `.md`, `.txt` |
| **Małe zmiany** | <500 linii + brak security files |
| **Konfiguracja** | Tylko `.json`, `.yml`, `.yaml` (bez workflows) |

#### ❌ Wymaga Human Review:

- Zmiany >500 linii
- Pliki security/auth
- Pliki `.env`, secrets
- Workflows (`.github/workflows/`)
- Kod aplikacji
- Infrastruktura

---

### 3. **Production PRs (develop → main)**

**ZAWSZE wymaga 2 human approvals** ⛔

Copilot:
- ❌ NIE approve'uje automatycznie
- ✅ Dodaje label `needs-human-review`
- ✅ Dodaje label `production-release`
- ✅ Przypomina o wymaganiach:
  - 2 senior developer approvals
  - 7-day stabilization
  - Release notes
  - Rollback plan

---

## 🚀 Setup

### Krok 1: Utwórz GitHub App Token

Potrzebujesz osobnego tokena dla Copilot (GitHub Actions nie może approve'ować własnych workflow):

```bash
# 1. Utwórz GitHub App:
https://github.com/organizations/ZSEL-OPOLE/settings/apps/new

# 2. Permissions:
- Pull Requests: Read & Write
- Contents: Read
- Issues: Read & Write

# 3. Install app w organizacji

# 4. Wygeneruj Private Key

# 5. Dodaj do Secrets:
COPILOT_APPROVE_TOKEN=<your_token>
```

### Krok 2: Włącz Workflow

```bash
# Workflow już utworzony w:
.github/workflows/copilot-review.yml

# Commit i push:
git add .github/workflows/copilot-review.yml
git commit -m "feat(ci): add Copilot auto-review & approve"
git push origin develop
```

### Krok 3: Test

```bash
# Utwórz testowy PR (dokumentacja):
git checkout -b test/copilot-approve develop
echo "# Test" > TEST.md
git add TEST.md
git commit -m "docs: test copilot approve"
git push origin test/copilot-approve
gh pr create --base develop --title "Test: Copilot Auto-Approve"

# Sprawdź:
# 1. Copilot dodaje review comment ✅
# 2. Copilot approve'uje PR ✅
# 3. Label 'copilot-approved' dodany ✅
```

---

## 🎯 Przykładowe Scenariusze

### Scenariusz 1: Dokumentacja (AUTO-APPROVE ✅)

```bash
# PR zmienia tylko README.md
files: ['README.md']
lines: +50, -20

Copilot:
✅ Review: "Documentation update, no code changes"
✅ Auto-approve: "Safe changes detected"
✅ Label: 'copilot-approved'
```

### Scenariusz 2: Mały bugfix (AUTO-APPROVE ✅)

```bash
# PR naprawia typo w config
files: ['config.json']
lines: +5, -5

Copilot:
✅ Review: "Configuration fix, no security impact"
✅ Auto-approve: "Small change, no sensitive files"
✅ Label: 'copilot-approved'
```

### Scenariusz 3: Kod aplikacji (HUMAN REVIEW ❌)

```bash
# PR dodaje nową funkcję
files: ['src/app.py', 'tests/test_app.py']
lines: +200, -50

Copilot:
✅ Review: "New feature added, requires human review"
❌ No auto-approve
✅ Label: 'needs-human-review'
📝 Comment: "Human review required: code changes detected"
```

### Scenariusz 4: Security (HUMAN REVIEW ❌)

```bash
# PR zmienia auth
files: ['src/auth.py', '.env.example']
lines: +30, -10

Copilot:
✅ Review: "Security-sensitive changes detected"
❌ No auto-approve
✅ Label: 'needs-human-review'
⚠️ Alert: "Security review required"
```

### Scenariusz 5: Production Release (HUMAN REVIEW ❌)

```bash
# PR: develop → main
base: main
files: ['any']

Copilot:
✅ Review: "Production deployment"
❌ No auto-approve
✅ Label: 'needs-human-review', 'production-release'
🔒 Block: "Requires 2 senior approvals"
```

---

## 🔧 Konfiguracja

### Dostosuj Kryteria Auto-Approve

Edytuj `.github/workflows/copilot-review.yml`:

```yaml
# Zwiększ limit linii (domyślnie 500):
const criteria = {
  smallPR: pr.additions + pr.deletions < 1000,  # Zmień na 1000
  # ...
};

# Dodaj więcej bezpiecznych rozszerzeń:
documentationOnly: pr.files.every(f => 
  f.filename.endsWith('.md') || 
  f.filename.endsWith('.txt') ||
  f.filename.endsWith('.pdf')  # Dodaj PDF
),
```

### Wyłącz Auto-Approve dla Repo

Dodaj label do PR:

```bash
gh pr edit <number> --add-label "skip-copilot-review"
```

Lub dodaj do `.github/copilot-config.yml`:

```yaml
auto-approve:
  enabled: false  # Wyłącz całkowicie
```

---

## 📊 Monitoring

### Sprawdź Statystyki Copilot

```bash
# PRs auto-approved:
gh pr list --label "copilot-approved" --state merged

# PRs wymagające human review:
gh pr list --label "needs-human-review" --state open

# Copilot review accuracy:
gh api /repos/ZSEL-OPOLE/zsel-eip-infra/actions/workflows/copilot-review.yml/runs \
  --jq '.workflow_runs[] | {date: .created_at, conclusion: .conclusion}'
```

### Dashboard Metrics

Dodaj do GitHub Projects:

```yaml
Metryki Copilot:
- PRs reviewed: 50
- Auto-approved: 30 (60%)
- Human review: 20 (40%)
- False positives: 2 (4%)
- Avg review time: 2 min
```

---

## 🛡️ Security

### Bezpieczeństwo Auto-Approve

**Zabezpieczenia:**

1. ✅ **Nigdy** nie approve'uje PRs do `main`
2. ✅ **Nigdy** nie approve'uje security changes
3. ✅ **Zawsze** sprawdza file types
4. ✅ **Zawsze** weryfikuje size (<500 lines)
5. ✅ **Zawsze** wymaga passing CI/CD

**Token Permissions:**

```yaml
COPILOT_APPROVE_TOKEN:
  - pull_requests: write  # Tylko approve
  - contents: read        # Tylko read
  - issues: write         # Tylko labels
  
  # NIE MA:
  - admin: false          # Nie może bypass'ować protection
  - push: false           # Nie może push'ować
```

### Audit Log

```bash
# Zobacz wszystkie Copilot approvals:
gh api /repos/ZSEL-OPOLE/zsel-eip-infra/pulls/reviews \
  --jq '.[] | select(.user.login == "github-actions[bot]")'

# Export do CSV:
gh pr list --label "copilot-approved" --json number,title,createdAt,mergedAt \
  --jq 'map([.number, .title, .createdAt, .mergedAt]) | @csv' > copilot-approvals.csv
```

---

## ❓ FAQ

### Czy Copilot może ominąć branch protection?

**NIE.** Branch protection wymaga:
- 1 approval (develop) lub 2 approvals (main)
- 18 passing CI/CD checks

Copilot approval liczy się jako 1 approval, ale:
- Nadal potrzeba passing checks
- Main nadal wymaga 2 approvals (human + Copilot)
- enforce_admins=true nadal aktywne

### Co jeśli Copilot się pomyli?

Human code owner może:
1. Request changes (override Copilot)
2. Close PR
3. Dodać label `needs-human-review`

### Czy Copilot sprawdza security?

**TAK**, ale:
- ✅ Static analysis (dependencies, secrets)
- ✅ Code patterns (SQL injection, XSS)
- ❌ Runtime vulnerabilities
- ❌ Business logic

**Zawsze** wymaga human review dla security changes.

---

## 🎓 Best Practices

### DO ✅

- ✅ Używaj auto-approve dla dokumentacji
- ✅ Używaj auto-approve dla małych config changes
- ✅ Monitoruj false positives
- ✅ Audytuj Copilot decisions co tydzień
- ✅ Update criteria na podstawie doświadczenia

### DON'T ❌

- ❌ Nie polegaj TYLKO na Copilot (human review nadal ważny)
- ❌ Nie zwiększaj limitu >500 lines bez przemyślenia
- ❌ Nie approve'uj security changes automatycznie
- ❌ Nie pomijaj CI/CD checks
- ❌ Nie używaj auto-approve dla production PRs

---

## 📈 Workflow Timeline z Copilot

### Feature → Develop (z Copilot)

```
Developer creates PR:
  ↓ 2 min
Copilot review + approve (if eligible):
  ↓ 5 min
CI/CD runs (18 jobs):
  ↓ 25 min
✅ MERGE TO DEVELOP (total: ~30 min)
```

**Oszczędność czasu:** ~2-4 godziny na human review

### Develop → Main (bez Copilot)

```
Create PR after 7 days:
  ↓ 1 hour
Human review #1 (senior dev):
  ↓ 2 hours
Human review #2 (infra team):
  ↓ 2 hours
CI/CD runs (18 jobs):
  ↓ 25 min
✅ MERGE TO MAIN (total: ~5.5 hours + 7 days)
```

**Copilot NIE przyspiesza** (2 human approvals wymagane)

---

## 🚀 Next Steps

1. **Setup token** (`COPILOT_APPROVE_TOKEN`)
2. **Commit workflow** (`.github/workflows/copilot-review.yml`)
3. **Test** (create doc-only PR)
4. **Monitor** (check false positives)
5. **Optimize** (adjust criteria after 1 week)
6. **Scale** (deploy to all 25 repos)

---

## 📚 Resources

- [GitHub Copilot PR Review Docs](https://docs.github.com/en/copilot/using-github-copilot/code-review)
- [GitHub Actions Permissions](https://docs.github.com/en/actions/security-guides/automatic-token-authentication)
- [Branch Protection API](https://docs.github.com/en/rest/branches/branch-protection)

---

**Status:** ✅ Ready to use  
**Updated:** 2025-11-27  
**Version:** 1.0.0
