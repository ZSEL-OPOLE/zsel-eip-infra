# 🚀 Quick Start Guide - Security Framework Rollout

## ✅ Co już jest zrobione (zsel-eip-infra)

1. **Security Framework wdrożony** (17 plików, 2,823 linii kodu)
2. **GitHub Actions**: 2 workflows, 18 jobs - wszystkie ✅ PASS
3. **Branch Protection**: Aktywna (ale enforce_admins=false)
4. **Teams**: 8 zespołów utworzonych
5. **GitHub Project #2**: [Security Framework Rollout](https://github.com/orgs/ZSEL-OPOLE/projects/2)
6. **Dokumentacja**: SECURITY.md, CONTRIBUTING.md, SECURITY-SETUP.md, ROLLOUT-PLAN.md

---

## 📊 Status: 1/25 repos wdrożonych

```
✅ DONE (1):     zsel-eip-infra

⏳ PENDING (24): 
   📌 Phase 1 (6): gitops, network, ansible, dokumentacja, opole, opole-ad
   📌 Phase 2 (17): wszystkie moduły Terraform
   📌 Phase 3 (1): .github (org config)
```

---

## 🎯 Rozpoczęcie wdrożenia - 3 polecenia

### **KROK 1: Dry-run (sprawdź co się stanie)**

```powershell
cd c:\Users\kolod\Desktop\LKP\05_BCU\INFRA\zsel-eip-infra\scripts
.\Deploy-Batch.ps1 -Phase 1 -DryRun
```

✅ **Efekt**: Zobaczyysz co zostanie wdrożone, **BEZ faktycznych zmian**

---

### **KROK 2: Utwórz tracking issues w GitHub Project**

```powershell
.\Deploy-Batch.ps1 -Phase 1 -CreateIssues -DryRun
# Usuń -DryRun jak będziesz gotowy
```

✅ **Efekt**: Utworzy 6 issues w GitHub Project #2 (jeden per repo)

---

### **KROK 3: Wdróż Fazę 1 (6 głównych repos)**

```powershell
.\Deploy-Batch.ps1 -Phase 1
# Potwierdź: yes
```

✅ **Efekt**: 
- Utworzy 6 Pull Requestów (NIE bezpośredni push!)
- Skopiuje wszystkie pliki security framework
- Zaktualizuje README.md
- Utworzy feature branch per repo
- Uruchomi CI/CD checks

**⏱️ Czas:** ~11 godzin (może być równolegle: ~2 godziny)

---

## 🔒 Polityka: ZERO wyjątków

### ⚠️ **Nawet admin (Ty) MUSI robić przez PR!**

**Obecnie:**
```yaml
enforce_admins: false  # ❌ Admin może omijać
```

**Docelowo (po testach Fazy 1):**
```yaml
enforce_admins: true   # ✅ WSZYSCY przez PR!
```

### Jak to włączyć po testach:

```powershell
# Edytuj .github/branch-protection.json
$config = Get-Content .github/branch-protection.json | ConvertFrom-Json
$config.enforce_admins = $true
$config | ConvertTo-Json -Depth 10 | Set-Content .github/branch-protection.json

# Zastosuj na WSZYSTKICH repos
gh repo list ZSEL-OPOLE --json name --jq '.[].name' | ForEach-Object {
    gh api "repos/ZSEL-OPOLE/$_/branches/main/protection" -X PUT --input .github/branch-protection.json
}
```

---

## 📦 Szczegółowe wdrożenie pojedynczego repo

Jeśli chcesz ręcznie wdrożyć na 1 repo (np. testowo):

```powershell
cd c:\Users\kolod\Desktop\LKP\05_BCU\INFRA\zsel-eip-infra\scripts

# Przykład: zsel-eip-gitops
.\Deploy-SecurityFramework.ps1 `
    -TargetRepo "zsel-eip-gitops" `
    -RepoType "Main" `
    -CreatePR $true  # ZAWSZE true! Wymuszamy PR workflow
```

**Efekt:**
1. Klonuje repo do `$env:TEMP\security-rollout`
2. Tworzy branch: `security/deploy-framework-20250119`
3. Kopiuje 17 plików framework
4. Dostosowuje .pre-commit-config.yaml
5. Aktualizuje README.md
6. Commituje: `feat(security): deploy security framework`
7. Pushuje branch
8. **Tworzy Pull Request** z pełnym opisem
9. **Zwraca URL PR** do review

---

## 🧪 Workflow testowy (zaraz po merge PR)

Po wdrożeniu na 1 repo, **przetestuj cały workflow**:

```powershell
# 1. Klonuj repo
cd $env:TEMP
gh repo clone ZSEL-OPOLE/zsel-eip-gitops
cd zsel-eip-gitops

# 2. Zainstaluj pre-commit
pip install pre-commit
pre-commit install

# 3. Utwórz test branch
git checkout -b test/security-workflow

# 4. Zrób zmianę
echo "# Test" >> README.md
git add README.md
git commit -m "test: verify security workflow"

# 5. Wypchnij i utwórz PR
git push origin test/security-workflow
gh pr create --title "Test Security Workflow" --body "Testing PR enforcement"

# 6. Sprawdź GitHub Actions
gh pr checks

# 7. Zobacz że NIE możesz zmergować bez approval!
gh pr merge --auto  # Powinno pokazać błąd jeśli enforce_admins: true
```

---

## 🗓️ Harmonogram wdrożenia

### **Tydzień 1: Faza 1 - Core Repos**
```powershell
# Poniedziałek - Przygotowanie
.\Deploy-Batch.ps1 -Phase 1 -CreateIssues  # Utwórz issues

# Wtorek - Wdrożenie
.\Deploy-Batch.ps1 -Phase 1               # Deploy (6 PRs)

# Środa-Czwartek - Review & Merge
# Przejrzyj wszystkie PRs, merguj po approve

# Piątek - Testy & Enforcement
# Test workflow, włącz enforce_admins: true
```

**Rezultat:** 7/25 repos (28%) secured ✅

---

### **Tydzień 2: Faza 2 + 3 - Moduły & Org Config**
```powershell
# Poniedziałek - Terraform Modules
.\Deploy-Batch.ps1 -Phase 2               # Deploy 17 modules (równolegle!)

# Wtorek-Środa - Review & Merge
# Przejrzyj PRs, merguj

# Czwartek - Organization Config
# Ręcznie skonfiguruj .github repo

# Piątek - Weryfikacja
# Test wszystkich 25 repos
```

**Rezultat:** 25/25 repos (100%) secured ✅

---

### **Tydzień 3: Faza 4 - Self-Hosted Runners na K8s**
```powershell
# Poniedziałek-Wtorek - ARC Installation
helm install arc \
    --namespace actions-runner-system \
    --create-namespace \
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller

# Środa - Runner Scale Sets
kubectl apply -f arc-runner-set.yaml

# Czwartek - Migracja Workflows
# Zmień ubuntu-latest → [self-hosted, kubernetes]

# Piątek - Monitoring
# Sprawdź metryki, uptime, koszty
```

**Rezultat:** Unlimited GitHub Actions minutes 🎉

---

## 📋 Checklist przed rozpoczęciem

- [ ] GitHub CLI zainstalowane: `gh --version`
- [ ] Git skonfigurowany: `git config --global user.name`
- [ ] Python 3.9+ zainstalowany: `python --version`
- [ ] PowerShell 7+ aktywny: `$PSVersionTable.PSVersion`
- [ ] GitHub PAT z uprawnieniami: repo, admin:org, project
- [ ] Dostęp do K8s cluster: `kubectl cluster-info`
- [ ] Przeczytane: ROLLOUT-PLAN.md
- [ ] Backup kluczowych repos (opcjonalne)

---

## 🆘 Troubleshooting

### **Problem: "gh: command not found"**
```powershell
winget install GitHub.cli
```

### **Problem: "Permission denied" podczas push**
```powershell
gh auth login
gh auth status
```

### **Problem: Pre-commit hooks nie działają**
```powershell
pip install --upgrade pre-commit
pre-commit clean
pre-commit install --install-hooks
```

### **Problem: GitHub Actions nie uruchamiają się**
- Sprawdź: Settings → Actions → General → Allow all actions ✅
- Sprawdź: `.github/workflows/*.yml` syntax (YAML validator)

### **Problem: Branch protection nie działa**
```powershell
gh api repos/ZSEL-OPOLE/{repo}/branches/main/protection | jq
```

### **Problem: Pull Request nie może być zmergowany**
- ✅ Dobry znak! To znaczy że **branch protection działa**!
- Poproś o approval od code ownera
- Sprawdź czy wszystkie checks są green

---

## 🎯 Metryki sukcesu

Po pełnym wdrożeniu (3 tygodnie):

| Metryka | Target | Jak sprawdzić |
|---------|--------|---------------|
| Repos secured | 25/25 (100%) | `gh repo list ZSEL-OPOLE \| wc -l` |
| PRs via workflow | 100% | GitHub Insights → Pull Requests |
| Direct pushes | 0 | GitHub Insights → Commits |
| CI/CD passing | >95% | GitHub Actions dashboard |
| Pre-commit adoption | 100% | `.pre-commit-config.yaml` w każdym repo |
| Runner uptime | >95% | `kubectl get pods -n actions-runner-system` |
| Code owner reviews | 100% | GitHub Insights → Reviews |

---

## 📚 Dodatkowa dokumentacja

- **[ROLLOUT-PLAN.md](ROLLOUT-PLAN.md)** - Kompletny plan wdrożenia (350+ linii)
- **[SECURITY-SETUP.md](SECURITY-SETUP.md)** - Przewodnik konfiguracji
- **[SECURITY.md](SECURITY.md)** - Polityka bezpieczeństwa
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Workflow developmentu
- **[DEPLOYMENT-STATUS.md](DEPLOYMENT-STATUS.md)** - Status obecny

---

## 🚦 Następny krok: DRY RUN

```powershell
cd c:\Users\kolod\Desktop\LKP\05_BCU\INFRA\zsel-eip-infra\scripts
.\Deploy-Batch.ps1 -Phase 1 -DryRun
```

**Gotowy? Usuń `-DryRun` i wdróż!** 🚀

---

## 💡 Wskazówki

1. **Równoległe wdrożenia**: Faza 2 (17 modułów) można robić równolegle
2. **Test małym krokiem**: Zacznij od 1 repo (`Deploy-SecurityFramework.ps1`)
3. **GitHub Project**: Śledź postęp w [Project #2](https://github.com/orgs/ZSEL-OPOLE/projects/2)
4. **Rollback**: Jeśli coś pójdzie źle, po prostu zamknij PR i usuń branch
5. **No exceptions**: enforce_admins=true włącz PO testach, nie przed!

---

**Status:** Framework gotowy ✅ | Skrypty gotowe ✅ | Project utworzony ✅  
**Czas do pełnego wdrożenia:** ~3 tygodnie (~40 godzin)  
**Następny krok:** Dry-run Fazy 1 → Wdrożenie → Testy → Enforcement
