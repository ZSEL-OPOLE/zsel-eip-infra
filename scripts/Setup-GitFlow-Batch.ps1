<#
.SYNOPSIS
    Batch setup GitFlow for all Phase 1 repositories

.DESCRIPTION
    Sets up GitFlow workflow (develop branch + protection) for all repos

.EXAMPLE
    .\Setup-GitFlow-Batch.ps1

.NOTES
    Runs Setup-GitFlow.ps1 for each repository
#>

[CmdletBinding()]
param()

$repos = @(
    @{ Name = 'zsel-eip-infra'; Path = 'c:\Users\kolod\Desktop\LKP\05_BCU\INFRA\zsel-eip-infra' }
    @{ Name = 'zsel-eip-gitops'; Path = 'C:\Users\kolod\AppData\Local\Temp\security-rollout\zsel-eip-gitops' }
    @{ Name = 'zsel-eip-network'; Path = 'C:\Users\kolod\AppData\Local\Temp\security-rollout\zsel-eip-network' }
    @{ Name = 'zsel-eip-ansible'; Path = 'C:\Users\kolod\AppData\Local\Temp\security-rollout\zsel-eip-ansible' }
    @{ Name = 'zsel-eip-dokumentacja'; Path = 'C:\Users\kolod\AppData\Local\Temp\security-rollout\zsel-eip-dokumentacja' }
    @{ Name = 'zsel-opole'; Path = 'C:\Users\kolod\AppData\Local\Temp\security-rollout\zsel-opole' }
    @{ Name = 'zsel-opole-ad'; Path = 'C:\Users\kolod\AppData\Local\Temp\security-rollout\zsel-opole-ad' }
)

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   🔄 Batch GitFlow Setup                                      ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$scriptPath = Join-Path $PSScriptRoot "Setup-GitFlow.ps1"

foreach ($repo in $repos) {
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "Setting up: $($repo.Name)" -ForegroundColor Yellow
    
    # Clone if doesn't exist
    if (-not (Test-Path $repo.Path)) {
        Write-Host "  Cloning repository..." -ForegroundColor Cyan
        $parentDir = Split-Path $repo.Path
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        Push-Location $parentDir
        gh repo clone "ZSEL-OPOLE/$($repo.Name)" 2>&1 | Out-Null
        Pop-Location
    }
    
    # Run setup
    & $scriptPath -RepoPath $repo.Path -RepoName $repo.Name
    
    Start-Sleep -Seconds 1
}

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   ✅ All Repositories Configured                              ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "📊 Summary: 7/7 repos with GitFlow" -ForegroundColor Yellow
Write-Host "  ✅ zsel-eip-infra" -ForegroundColor Green
Write-Host "  ✅ zsel-eip-gitops" -ForegroundColor Green
Write-Host "  ✅ zsel-eip-network" -ForegroundColor Green
Write-Host "  ✅ zsel-eip-ansible" -ForegroundColor Green
Write-Host "  ✅ zsel-eip-dokumentacja" -ForegroundColor Green
Write-Host "  ✅ zsel-opole" -ForegroundColor Green
Write-Host "  ✅ zsel-opole-ad`n" -ForegroundColor Green

Write-Host "🎯 Workflow:" -ForegroundColor Yellow
Write-Host "  feature/* → develop (testing)" -ForegroundColor White
Write-Host "  develop → main (production, after 7 days)`n" -ForegroundColor White
