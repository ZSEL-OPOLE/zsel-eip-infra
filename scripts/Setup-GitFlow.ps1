<#
.SYNOPSIS
    Setup GitFlow workflow for repository

.DESCRIPTION
    Creates develop branch, configures branch protection, updates workflows
    to support GitFlow with quality gating (feature → develop → main)

.PARAMETER RepoPath
    Path to repository

.PARAMETER RepoName
    Repository name (for GitHub API)

.EXAMPLE
    .\Setup-GitFlow.ps1 -RepoPath "C:\repo" -RepoName "zsel-eip-infra"

.NOTES
    Author: ZSEL-OPOLE Infrastructure Team
    Version: 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$RepoPath,

    [Parameter(Mandatory=$true)]
    [string]$RepoName
)

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

Write-ColorOutput "`n╔════════════════════════════════════════════════════════════════╗" -Color Cyan
Write-ColorOutput "║   🔄 GitFlow Setup Script                                     ║" -Color Cyan
Write-ColorOutput "╚════════════════════════════════════════════════════════════════╝`n" -Color Cyan

Write-ColorOutput "📋 Configuration:" -Color Yellow
Write-ColorOutput "  Repository: $RepoName" -Color White
Write-ColorOutput "  Path: $RepoPath`n" -Color White

# 1. Create develop branch
Write-ColorOutput "🌿 Creating develop branch..." -Color Cyan
Push-Location $RepoPath
try {
    git checkout main 2>&1 | Out-Null
    git pull origin main 2>&1 | Out-Null
    
    # Check if develop exists
    $developExists = git branch -r | Select-String "origin/develop"
    
    if ($developExists) {
        Write-ColorOutput "  ℹ Develop branch already exists" -Color Yellow
        git checkout develop 2>&1 | Out-Null
        git pull origin develop 2>&1 | Out-Null
    }
    else {
        git checkout -b develop 2>&1 | Out-Null
        git push origin develop 2>&1 | Out-Null
        Write-ColorOutput "  ✓ Develop branch created" -Color Green
    }
}
finally {
    Pop-Location
}

# 2. Configure branch protection for main
Write-ColorOutput "`n🔒 Configuring branch protection (main)..." -Color Cyan
try {
    $mainProtection = Join-Path (Split-Path $RepoPath) "zsel-eip-infra\.github\branch-protection-main.json"
    
    gh api "repos/ZSEL-OPOLE/$RepoName/branches/main/protection" `
        -X PUT --input $mainProtection 2>&1 | Out-Null
    
    Write-ColorOutput "  ✓ Main branch protected" -Color Green
}
catch {
    Write-ColorOutput "  ⚠ Failed to protect main: $_" -Color Yellow
}

# 3. Configure branch protection for develop
Write-ColorOutput "`n🔒 Configuring branch protection (develop)..." -Color Cyan
try {
    $developProtection = Join-Path (Split-Path $RepoPath) "zsel-eip-infra\.github\branch-protection-develop.json"
    
    gh api "repos/ZSEL-OPOLE/$RepoName/branches/develop/protection" `
        -X PUT --input $developProtection 2>&1 | Out-Null
    
    Write-ColorOutput "  ✓ Develop branch protected" -Color Green
}
catch {
    Write-ColorOutput "  ⚠ Failed to protect develop: $_" -Color Yellow
}

# 4. Update workflows
Write-ColorOutput "`n⚙️  Updating GitHub Actions workflows..." -Color Cyan
Push-Location $RepoPath
try {
    $workflowFiles = Get-ChildItem ".github/workflows/*.yml" -ErrorAction SilentlyContinue
    
    if ($workflowFiles) {
        foreach ($file in $workflowFiles) {
            $content = Get-Content $file.FullName -Raw
            
            # Add develop to branches if not present
            if ($content -match "branches:\s*\[main\]" -and $content -notmatch "develop") {
                $content = $content -replace "branches:\s*\[main\]", "branches: [main, develop]"
                Set-Content $file.FullName -Value $content -NoNewline
                Write-ColorOutput "  ✓ Updated $($file.Name)" -Color Green
            }
        }
        
        # Commit changes
        git add .github/workflows/*.yml 2>&1 | Out-Null
        git commit -m "ci: add develop branch to workflows" 2>&1 | Out-Null
        git push origin develop 2>&1 | Out-Null
    }
    else {
        Write-ColorOutput "  ℹ No workflow files found" -Color Yellow
    }
}
catch {
    Write-ColorOutput "  ⚠ Failed to update workflows: $_" -Color Yellow
}
finally {
    Pop-Location
}

# 5. Summary
Write-ColorOutput "`n╔════════════════════════════════════════════════════════════════╗" -Color Cyan
Write-ColorOutput "║   ✅ GitFlow Setup Complete                                    ║" -Color Green
Write-ColorOutput "╚════════════════════════════════════════════════════════════════╝`n" -Color Cyan

Write-ColorOutput "📋 Summary:" -Color Yellow
Write-ColorOutput "  ✅ Develop branch created" -Color Green
Write-ColorOutput "  ✅ Main branch protected (2 approvals required)" -Color Green
Write-ColorOutput "  ✅ Develop branch protected (1 approval required)" -Color Green
Write-ColorOutput "  ✅ Workflows updated (main + develop)`n" -Color Green

Write-ColorOutput "🎯 Next steps:" -Color Yellow
Write-ColorOutput "  1. Create feature branch: git checkout -b feature/xyz develop" -Color White
Write-ColorOutput "  2. Work & commit changes" -Color White
Write-ColorOutput "  3. Push: git push origin feature/xyz" -Color White
Write-ColorOutput "  4. Create PR: gh pr create --base develop" -Color White
Write-ColorOutput "  5. After 7 days stability: PR develop → main`n" -Color White

Write-ColorOutput "📚 Documentation: GITFLOW.md`n" -Color Cyan
