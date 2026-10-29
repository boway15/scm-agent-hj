# 双推：GitHub (origin) + GitLab (gitlab)
# Usage: .\scripts\git-push-dual.ps1 [branch]
#        .\scripts\git-push-dual.ps1 main --tags

param(
  [string]$Branch = "main",
  [switch]$Tags
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))

Write-Host "Push origin (GitHub): $Branch" -ForegroundColor Cyan
git push -u origin $Branch
if ($Tags) { git push origin --tags }

Write-Host "Push gitlab: $Branch" -ForegroundColor Cyan
git push -u gitlab $Branch
if ($Tags) { git push gitlab --tags }

Write-Host "Done." -ForegroundColor Green
