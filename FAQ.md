# ❓ FAQ - Organization Security Framework Rollout

## 🎯 Ogólne pytania

### Dlaczego tylko 1/25 repos jest secured?
Security framework był początkowo testowany na `zsel-eip-infra`. Po potwierdzeniu że działa, teraz rollout na pozostałe 24 repos.

### Czy muszę wdrażać wszystkie fazy od razu?
Nie! Plan zakłada 3 tygodnie:
- **Tydzień 1**: Faza 1 (6 głównych repos)
- **Tydzień 2**: Faza 2-3 (17 modułów + org config)
- **Tydzień 3**: Faza 4 (self-hosted runners)

### Czy mogę wdrożyć tylko wybrane repos?
Tak, użyj:
```powershell
.\Deploy-SecurityFramework.ps1 -TargetRepo "nazwa-repo" -RepoType "Main"
```

---

## 🔒 Pytania o enforcement

### Czy jako admin mogę omijać branch protection?
**Obecnie**: TAK (enforce_admins: false)  
**Docelowo**: NIE (enforce_admins: true) - po testach w Tygodniu 1

### Co jeśli potrzebuję hotfix w weekend?
1. **Najpierw** rozważ czy to faktycznie emergency
2. Jeśli TAK: utwórz PR jak zawsze
3. Self-approve jeśli jesteś code owner
4. Poczekaj na CI/CD (5-10 minut)
5. Merge

**UWAGA**: Po włączeniu `enforce_admins: true`, MUSISZ poczekać na approval od innego code ownera (nawet jako admin)!

### Co jeśli CI/CD się wywali?
1. Sprawdź logi: `gh pr checks`
2. Napraw błąd
3. Push kolejny commit
4. CI/CD uruchomi się ponownie

### Czy mogę tymczasowo wyłączyć branch protection?
**NIE ZALECANE!** Ale jeśli musisz (np. migration):
```powershell
# Wyłącz (TYLKO dla emergency!)
gh api repos/ZSEL-OPOLE/{repo}/branches/main/protection -X DELETE

# Pamiętaj WŁĄCZYĆ Z POWROTEM!
gh api repos/ZSEL-OPOLE/{repo}/branches/main/protection -X PUT --input .github/branch-protection.json
```

---

## 📦 Pytania o deployment

### Czy Deploy-Batch.ps1 może zniszczyć dane?
**NIE!** Skrypt:
- Tworzy nowy branch (nie modyfikuje main bezpośrednio)
- Tworzy Pull Request (wymaga review)
- **Nie merguje** automatycznie (musisz zatwierdzić)
- Działa na kopii w `$env:TEMP` (nie modyfikuje lokalnych repos)

### Co jeśli deployment się nie powiedzie?
1. PR nie zostanie utworzony - nic się nie stanie
2. Lub PR zostanie utworzony ale z błędami w CI/CD
3. Po prostu zamknij PR i spróbuj ponownie
4. Wszystkie zmiany są w feature branch - main pozostaje nietknięty

### Czy mogę testować zmiany lokalnie przed push?
TAK! Zainstaluj pre-commit:
```powershell
pip install pre-commit
pre-commit install
pre-commit run --all-files
```

### Jak długo trwa deployment 1 repo?
- **Automated**: 5-10 minut (PR creation)
- **Manual review**: 10-20 minut (read PR, test locally)
- **CI/CD**: 5-10 minut (18 jobs)
- **Merge**: 1 minuta

**Total**: ~30 minut per repo

### Czy mogę równolegle deployować do wielu repos?
**TAK!** Szczególnie Faza 2 (17 modułów Terraform):
```powershell
# Uruchom wszystkie równolegle
.\Deploy-Batch.ps1 -Phase 2
```

---

## 🛠️ Pytania techniczne

### Jakie narzędzia muszą być zainstalowane?
```powershell
# Sprawdź co masz
gh --version          # GitHub CLI
git --version         # Git
python --version      # Python 3.9+
pwsh --version        # PowerShell 7+

# Opcjonalne (dla developerów)
pre-commit --version  # Pre-commit framework
terraform --version   # Terraform (dla modułów)
```

### Czy muszę instalować wszystkie pre-commit hooks lokalnie?
Zależy od typu pracy:
- **Tylko czytanie/review**: NIE
- **Drobne edycje (README, docs)**: Opcjonalnie
- **Development (kod, Terraform, skrypty)**: TAK, zdecydowanie!

### Co jeśli nie mam Python?
```powershell
# Windows (winget)
winget install Python.Python.3.12

# Lub Chocolatey
choco install python

# Verify
python --version
```

### Co jeśli pre-commit hook blokuje commit?
1. **Przeczytaj błąd** - hook mówi co jest nie tak
2. **Napraw problem** - np. usuń trailing whitespace
3. **Spróbuj ponownie**: `git commit`
4. Lub **skip hook** (NIE ZALECANE): `git commit --no-verify`

### Jak zaktualizować hooks?
```powershell
pre-commit autoupdate      # Update all hooks
pre-commit run --all-files # Test after update
```

---

## 🔍 Pytania o GitHub Actions

### Dlaczego CI/CD trwa 10 minut?
18 jobs uruchamia się równolegle:
- Secret detection (3 tools): ~2 min
- Code security (PowerShell, Python, Terraform): ~3 min
- Validation (YAML, JSON, Markdown): ~2 min
- Quality checks (linting, formatting): ~3 min

**Total**: ~10 min (nie 18×time, bo równoległe)

### Czy GitHub Actions są darmowe?
Dla public repos: **TAK, unlimited!**
Dla private repos: 2,000 minut/miesiąc free (currently nie używamy)

### Co jeśli przekroczymy limit?
W przyszłości (Faza 4): **self-hosted runners na K8s**
- Unlimited minutes
- Szybsze buildy (lokalna sieć)
- Pełna kontrola

### Jak sprawdzić użycie minutes?
```powershell
# Organization-wide
gh api orgs/ZSEL-OPOLE/settings/billing/actions

# Per repo
gh api repos/ZSEL-OPOLE/{repo}/actions/runs --jq '.workflow_runs[].run_duration_ms | @json' | Measure-Object
```

### Czy mogę wyłączyć niektóre jobs?
**NIE ZALECANE!** Każdy job ma cel:
- Secret detection → zapobiega wyciekowi credentials
- Security scans → wykrywa vulnerabilities
- Validation → zapewnia jakość kodu

Jeśli MUSISZ (np. testing): edytuj `.github/workflows/security-checks.yml`

---

## 📊 Pytania o self-hosted runners

### Kiedy wdrożymy self-hosted runners?
**Tydzień 3** (Faza 4) - 3-9 lutego

### Na czym będą działać?
**K8s cluster**: 9× Mac Pro M2 Ultra
- 216 CPU cores total
- 1,728 GB RAM total
- 72 TB storage (Longhorn)

### Czy self-hosted runners są bezpieczne?
TAK, jeśli dobrze skonfigurowane:
- ✅ Isolated namespace
- ✅ Network policies (ingress/egress rules)
- ✅ RBAC (minimal permissions)
- ✅ Sealed secrets (encrypted)
- ✅ Pod security standards (restricted)
- ✅ Auto-scaling (min 3, max 10)

### Czy mogę testować workflows lokalnie?
TAK! Użyj `act`:
```powershell
# Install act
choco install act-cli

# Run workflow locally
act -W .github/workflows/security-checks.yml
```

---

## 🚨 Troubleshooting

### Problem: "gh: command not found"
```powershell
winget install GitHub.cli
gh auth login
```

### Problem: "Permission denied (publickey)"
```powershell
# Generate SSH key
ssh-keygen -t ed25519 -C "your.email@zsel.opole.pl"

# Add to GitHub
cat ~/.ssh/id_ed25519.pub
# Paste to: https://github.com/settings/keys
```

### Problem: "pre-commit: command not found"
```powershell
pip install pre-commit
pre-commit --version
```

### Problem: "fatal: refusing to merge unrelated histories"
```powershell
# Force merge (ONLY if you're sure!)
git pull origin main --allow-unrelated-histories
```

### Problem: GitHub Actions nie uruchamiają się
Sprawdź:
1. Settings → Actions → General → **Allow all actions** ✅
2. Branch protection: **Require status checks** ✅
3. Workflow syntax: Use YAML validator

### Problem: Branch protection nie działa
```powershell
# Verify settings
gh api repos/ZSEL-OPOLE/{repo}/branches/main/protection | jq

# Re-apply
gh api repos/ZSEL-OPOLE/{repo}/branches/main/protection -X PUT --input .github/branch-protection.json
```

### Problem: PR nie może być zmergowany mimo passing checks
**Możliwe przyczyny:**
1. ❌ Brak approval od code owner → Poproś o review
2. ❌ Conversations not resolved → Resolve all comments
3. ❌ Branch out of date → `git pull origin main; git push`
4. ❌ enforce_admins=true → Nawet admin musi dostać approval!

---

## 📚 Dodatkowe pytania

### Gdzie mogę znaleźć pełną dokumentację?
- **QUICK-START.md** - Szybki start (3 polecenia)
- **ROLLOUT-PLAN.md** - Kompletna strategia
- **SECURITY-SETUP.md** - Konfiguracja security
- **STATUS.md** - Obecny status

### Kto może odpowiedzieć na pytania?
- **GitHub Discussions**: https://github.com/ZSEL-OPOLE/zsel-eip-infra/discussions
- **Issues**: https://github.com/ZSEL-OPOLE/zsel-eip-infra/issues
- **Email**: it@zsel.opole.pl

### Czy mogę przyczynić się do poprawy dokumentacji?
**TAK!** Utwórz PR:
```powershell
git checkout -b docs/improve-faq
# Edit FAQ.md
git commit -m "docs: improve FAQ section"
gh pr create --title "docs: improve FAQ"
```

### Co jeśli znajdę bug w skryptach?
1. Sprawdź GitHub Issues: czy już zgłoszony?
2. Jeśli nie: `gh issue create --title "bug: description"`
3. Lub napraw i wyślij PR: `gh pr create`

### Jak mogę pomóc w rollout?
1. **Review PRs** - przejrzyj Pull Requesty
2. **Test workflows** - testuj na swoich repos
3. **Improve docs** - popraw dokumentację
4. **Report issues** - zgłaszaj problemy

---

## 🎯 Kluczowe zasady

### ✅ DO:
- Zawsze twórz PR (nawet dla drobnych zmian)
- Czekaj na CI/CD passing
- Proś o review od code ownerów
- Testuj zmiany lokalnie (pre-commit)
- Czytaj dokumentację przed zmianami

### ❌ DON'T:
- NIE push directly do main (po włączeniu enforce_admins)
- NIE skip pre-commit hooks bez powodu
- NIE merguj bez approval
- NIE wyłączaj branch protection
- NIE commituj secretów/credentials

---

## 🔗 Użyteczne linki

**Dokumentacja:**
- [QUICK-START.md](QUICK-START.md) - Przewodnik szybkiego startu
- [ROLLOUT-PLAN.md](ROLLOUT-PLAN.md) - Kompletny plan
- [STATUS.md](STATUS.md) - Obecny status
- [SECURITY-SETUP.md](SECURITY-SETUP.md) - Konfiguracja

**GitHub:**
- [Organization](https://github.com/ZSEL-OPOLE)
- [Project #2](https://github.com/orgs/ZSEL-OPOLE/projects/2)
- [Actions Status](https://github.com/ZSEL-OPOLE/zsel-eip-infra/actions)

**Narzędzia:**
- [GitHub CLI](https://cli.github.com/)
- [Pre-commit](https://pre-commit.com/)
- [Act (local testing)](https://github.com/nektos/act)

---

**Pytanie nie ma na liście?**  
→ Utwórz issue: `gh issue create --title "question: ..."`

**Znalazłeś błąd w FAQ?**  
→ Wyślij PR: `gh pr create --title "docs: fix FAQ"`
