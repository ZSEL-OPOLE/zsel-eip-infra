<#
.SYNOPSIS
    Batch deploy security framework to multiple repositories

.DESCRIPTION
    Deploys security framework to all 24 pending repositories using Deploy-SecurityFramework.ps1.
    Creates GitHub Project issues for tracking. Respects priority and phases.

.PARAMETER Phase
    Deployment phase: 1 (Core repos), 2 (Terraform modules), 3 (Org config)

.PARAMETER DryRun
    Show what would be deployed without actually deploying

.EXAMPLE
    .\Deploy-Batch.ps1 -Phase 1
    .\Deploy-Batch.ps1 -Phase 2 -DryRun

.NOTES
    Author: ZSEL-OPOLE Infrastructure Team
    Version: 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet(1, 2, 3, 'All')]
    [string]$Phase = '1',

    [Parameter(Mandatory=$false)]
    [switch]$DryRun,

    [Parameter(Mandatory=$false)]
    [switch]$CreateIssues = $true
)

# Repository definitions from ROLLOUT-PLAN.md
$repositories = @{
    'Phase1' = @(
        @{ Name = 'zsel-eip-infra'; Type = 'Main'; Priority = 'P0'; Status = 'DONE' }
        @{ Name = 'zsel-eip-gitops'; Type = 'Main'; Priority = 'P0'; Status = 'PENDING' }
        @{ Name = 'zsel-eip-network'; Type = 'Main'; Priority = 'P0'; Status = 'PENDING' }
        @{ Name = 'zsel-eip-ansible'; Type = 'Ansible'; Priority = 'P1'; Status = 'PENDING' }
        @{ Name = 'zsel-eip-dokumentacja'; Type = 'Documentation'; Priority = 'P1'; Status = 'PENDING' }
        @{ Name = 'zsel-opole'; Type = 'Main'; Priority = 'P1'; Status = 'PENDING' }
        @{ Name = 'zsel-opole-ad'; Type = 'Main'; Priority = 'P1'; Status = 'PENDING' }
    )
    'Phase2' = @(
        # MikroTik Modules
        @{ Name = 'zsel-eip-tf-module-mikrotik-bridge-vlan-filtering'; Type = 'Terraform'; Priority = 'P2'; Status = 'PENDING' }
        @{ Name = 'zsel-eip-tf-module-mikrotik-dhcp-server'; Type = 'Terraform'; Priority = 'P2'; Status = 'PENDING' }
        @{ Name = 'zsel-eip-tf-module-mikrotik-firewall'; Type = 'Terraform'; Priority = 'P2'; Status = 'PENDING' }
        @{ Name = 'zsel-eip-tf-module-mikrotik-interfaces'; Type = 'Terraform'; Priority = 'P2'; Status = 'PENDING' }
        @{ Name = 'zsel-eip-tf-module-mikrotik-ip-addressing'; Type = 'Terraform'; Priority = 'P2'; Status = 'PENDING' }
        @{ Name = 'zsel-eip-tf-module-mikrotik-routing'; Type = 'Terraform'; Priority = 'P2'; Status = 'PENDING' }
        @{ Name = 'zsel-eip-tf-module-mikrotik-system'; Type = 'Terraform'; Priority = 'P2'; Status = 'PENDING' }
        @{ Name = 'zsel-eip-tf-module-mikrotik-users'; Type = 'Terraform'; Priority = 'P2'; Status = 'PENDING' }
        @{ Name = 'zsel-eip-tf-module-mikrotik-vlans'; Type = 'Terraform'; Priority = 'P2'; Status = 'PENDING' }
        @{ Name = 'zsel-eip-tf-module-mikrotik-vpn'; Type = 'Terraform'; Priority = 'P2'; Status = 'PENDING' }
        @{ Name = 'zsel-eip-tf-module-mikrotik-wifi'; Type = 'Terraform'; Priority = 'P2'; Status = 'PENDING' }
        # Kubernetes Modules
        @{ Name = 'zsel-eip-tf-module-k8s-argocd'; Type = 'Terraform'; Priority = 'P1'; Status = 'PENDING' }
        @{ Name = 'zsel-eip-tf-module-k8s-namespaces'; Type = 'Terraform'; Priority = 'P2'; Status = 'PENDING' }
        @{ Name = 'zsel-eip-tf-module-k8s-network-policies'; Type = 'Terraform'; Priority = 'P2'; Status = 'PENDING' }
        @{ Name = 'zsel-eip-tf-module-k8s-rbac'; Type = 'Terraform'; Priority = 'P2'; Status = 'PENDING' }
        # Storage & AD Modules
        @{ Name = 'zsel-eip-tf-module-storage-longhorn'; Type = 'Terraform'; Priority = 'P2'; Status = 'PENDING' }
        @{ Name = 'zsel-eip-tf-module-ad-network-ad'; Type = 'Terraform'; Priority = 'P2'; Status = 'PENDING' }
        @{ Name = 'zsel-eip-tf-module-ad-user-ad'; Type = 'Terraform'; Priority = 'P2'; Status = 'PENDING' }
    )
    'Phase3' = @(
        @{ Name = '.github'; Type = 'Main'; Priority = 'P0'; Status = 'PENDING' }
    )
}

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function New-GitHubIssue {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$RepoName,
        [string]$RepoType,
        [string]$Priority,
        [int]$PhaseNumber
    )

    $title = "[SECURITY] Deploy framework to $RepoName"
    
    $body = @"
## 🔒 Security Framework Deployment

**Repository:** $RepoName  
**Type:** $RepoType  
**Priority:** $Priority  
**Phase:** $PhaseNumber  
**Estimated Time:** 2 hours

---

### 📋 Deployment Tasks:

- [ ] Run deployment script: ``Deploy-SecurityFramework.ps1 -TargetRepo "$RepoName" -RepoType "$RepoType"``
- [ ] Review generated Pull Request
- [ ] Verify CI/CD workflows pass (18 jobs)
- [ ] Adjust .pre-commit-config.yaml for repo specifics (if needed)
- [ ] Update CODEOWNERS with correct teams
- [ ] Get 1 code owner approval
- [ ] Merge PR (NO direct push!)
- [ ] Configure branch protection rules
- [ ] Add repository to GitHub teams:
  $(switch ($RepoType) {
    'Main' { '- @ZSEL-OPOLE/infrastructure-team' }
    'Terraform' { '- @ZSEL-OPOLE/terraform-team' }
    'Ansible' { '- @ZSEL-OPOLE/infrastructure-team' }
    'Documentation' { '- @ZSEL-OPOLE/documentation-team' }
  })
- [ ] Test PR workflow with dummy PR
- [ ] Move to "Done" in Project Board

---

### 🧪 Verification Steps:

1. **Pre-commit hooks:**
   ``````powershell
   cd $RepoName
   pip install pre-commit
   pre-commit install
   pre-commit run --all-files
   ``````

2. **GitHub Actions:**
   - Check: https://github.com/ZSEL-OPOLE/$RepoName/actions
   - All jobs should be ✅ green

3. **Branch Protection:**
   - Settings → Branches → main
   - Verify rules are active

---

### 📚 Documentation:

- [Rollout Plan](https://github.com/ZSEL-OPOLE/zsel-eip-infra/blob/main/ROLLOUT-PLAN.md)
- [Security Setup](https://github.com/ZSEL-OPOLE/$RepoName/blob/main/SECURITY-SETUP.md)
- [Contributing Guide](https://github.com/ZSEL-OPOLE/$RepoName/blob/main/CONTRIBUTING.md)

---

### 🎯 Success Criteria:

- ✅ All security framework files present
- ✅ GitHub Actions workflows passing
- ✅ Branch protection active
- ✅ Team access configured
- ✅ Documentation updated
- ✅ PR workflow tested

---

**Script:** ``scripts/Deploy-SecurityFramework.ps1``  
**Project:** https://github.com/orgs/ZSEL-OPOLE/projects/2
"@

    if ($DryRun) {
        Write-ColorOutput "  [DRY RUN] Would create issue: $title" -Color Yellow
        return $null
    }

    try {
        $issue = gh issue create `
            --repo "ZSEL-OPOLE/zsel-eip-infra" `
            --title $title `
            --body $body `
            --label "security,infrastructure,rollout,phase-$PhaseNumber,$Priority" `
            --assignee "@me" | ConvertFrom-Json

        Write-ColorOutput "  ✅ Issue #$($issue.number): $RepoName" -Color Green
        
        # Add to project (requires project ID from earlier)
        gh project item-add 2 --owner ZSEL-OPOLE --url $issue.url 2>&1 | Out-Null

        return $issue
    }
    catch {
        Write-ColorOutput "  ❌ Failed to create issue for $RepoName`: $_" -Color Red
        return $null
    }
}

function Invoke-Deployment {
    param(
        [string]$RepoName,
        [string]$RepoType
    )

    if ($DryRun) {
        Write-ColorOutput "  [DRY RUN] Would deploy to: $RepoName ($RepoType)" -Color Yellow
        return $true
    }

    $scriptPath = Join-Path $PSScriptRoot "Deploy-SecurityFramework.ps1"
    
    Write-ColorOutput "`n🚀 Deploying to $RepoName..." -Color Cyan
    
    try {
        & $scriptPath -TargetRepo $RepoName -RepoType $RepoType -CreatePR $true
        return $?
    }
    catch {
        Write-ColorOutput "  ❌ Deployment failed: $_" -Color Red
        return $false
    }
}

# ═══════════════════════════════════════════════════════════════
# MAIN SCRIPT
# ═══════════════════════════════════════════════════════════════

Write-ColorOutput "`n╔════════════════════════════════════════════════════════════════╗" -Color Cyan
Write-ColorOutput "║   📦 Batch Security Framework Deployment                      ║" -Color Cyan
Write-ColorOutput "╚════════════════════════════════════════════════════════════════╝`n" -Color Cyan

# Determine which repos to deploy
$targetRepos = @()
switch ($Phase) {
    '1' { $targetRepos = $repositories['Phase1'] }
    '2' { $targetRepos = $repositories['Phase2'] }
    '3' { $targetRepos = $repositories['Phase3'] }
    'All' { 
        $targetRepos = $repositories['Phase1'] + $repositories['Phase2'] + $repositories['Phase3']
    }
}

# Filter out already done repos
$pendingRepos = $targetRepos | Where-Object { $_.Status -eq 'PENDING' }

Write-ColorOutput "📊 Deployment Summary:" -Color Yellow
Write-ColorOutput "  Phase: $Phase" -Color White
Write-ColorOutput "  Total Repos: $($targetRepos.Count)" -Color White
Write-ColorOutput "  Pending: $($pendingRepos.Count)" -Color White
Write-ColorOutput "  Already Done: $($targetRepos.Count - $pendingRepos.Count)" -Color White
Write-ColorOutput "  Dry Run: $(if ($DryRun) { 'YES' } else { 'NO' })`n" -Color White

if ($pendingRepos.Count -eq 0) {
    Write-ColorOutput "✅ All repositories in Phase $Phase are already deployed!" -Color Green
    exit 0
}

# Create GitHub Issues first
if ($CreateIssues) {
    Write-ColorOutput "`n📝 Creating GitHub Issues for tracking...`n" -Color Cyan
    
    $phaseNumber = switch ($Phase) {
        '1' { 1 }
        '2' { 2 }
        '3' { 3 }
        'All' { 0 }
    }

    $issueCount = 0
    foreach ($repo in $pendingRepos) {
        $issue = New-GitHubIssue `
            -RepoName $repo.Name `
            -RepoType $repo.Type `
            -Priority $repo.Priority `
            -PhaseNumber $phaseNumber

        if ($issue) { $issueCount++ }
        Start-Sleep -Milliseconds 500  # Rate limiting
    }

    Write-ColorOutput "`n✅ Created $issueCount issues" -Color Green
}

# Ask for confirmation before deploying
if (-not $DryRun) {
    Write-ColorOutput "`n⚠️  About to deploy to $($pendingRepos.Count) repositories!" -Color Yellow
    $confirmation = Read-Host "Continue? (yes/no)"
    
    if ($confirmation -ne 'yes') {
        Write-ColorOutput "❌ Deployment cancelled by user" -Color Red
        exit 1
    }
}

# Deploy to each repository
Write-ColorOutput "`n🚀 Starting deployments...`n" -Color Cyan

$results = @{
    Success = @()
    Failed = @()
}

foreach ($repo in $pendingRepos) {
    Write-ColorOutput "═══════════════════════════════════════════════════════════════" -Color DarkGray
    Write-ColorOutput "  Repository: $($repo.Name)" -Color Cyan
    Write-ColorOutput "  Type: $($repo.Type) | Priority: $($repo.Priority)" -Color White
    Write-ColorOutput "═══════════════════════════════════════════════════════════════" -Color DarkGray

    $success = Invoke-Deployment -RepoName $repo.Name -RepoType $repo.Type

    if ($success) {
        $results.Success += $repo.Name
        Write-ColorOutput "✅ $($repo.Name) - COMPLETED`n" -Color Green
    }
    else {
        $results.Failed += $repo.Name
        Write-ColorOutput "❌ $($repo.Name) - FAILED`n" -Color Red
    }

    # Brief pause between deployments
    Start-Sleep -Seconds 2
}

# Final summary
Write-ColorOutput "`n╔════════════════════════════════════════════════════════════════╗" -Color Cyan
Write-ColorOutput "║   📊 Deployment Summary                                        ║" -Color Cyan
Write-ColorOutput "╚════════════════════════════════════════════════════════════════╝`n" -Color Cyan

Write-ColorOutput "✅ Successful: $($results.Success.Count)" -Color Green
foreach ($repo in $results.Success) {
    Write-ColorOutput "   - $repo" -Color Green
}

if ($results.Failed.Count -gt 0) {
    Write-ColorOutput "`n❌ Failed: $($results.Failed.Count)" -Color Red
    foreach ($repo in $results.Failed) {
        Write-ColorOutput "   - $repo" -Color Red
    }
}

Write-ColorOutput "`n🎯 Next Steps:" -Color Yellow
Write-ColorOutput "  1. Review all Pull Requests" -Color White
Write-ColorOutput "  2. Wait for CI/CD checks to pass" -Color White
Write-ColorOutput "  3. Get code owner approvals" -Color White
Write-ColorOutput "  4. Merge PRs (NO direct push!)" -Color White
Write-ColorOutput "  5. Configure branch protection" -Color White
Write-ColorOutput "  6. Update project board: https://github.com/orgs/ZSEL-OPOLE/projects/2" -Color White
Write-ColorOutput "  7. Test PR workflow on each repo`n" -Color White

if ($DryRun) {
    Write-ColorOutput "ℹ️  This was a DRY RUN - no actual changes made" -Color Yellow
}
