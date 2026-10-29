# 对外共享门禁：扫描敏感关键字与样例目录
# Usage: .\scripts\audit-external-share.ps1
# Exit 0 = 通过；非 0 = 勿打包交付

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

$failures = @()
$warnings = @()

Write-Host "=== scm-agent 对外共享审计 ===" -ForegroundColor Cyan

# --- 禁止存在的真实样例目录 ---
$forbiddenDirs = @(
  "docs/samples/xiaoshou",
  "docs/samples/cs",
  "docs/samples/caigou",
  "docs/samples/kucun",
  "docs/samples/采购"
)
foreach ($d in $forbiddenDirs) {
  if (Test-Path (Join-Path $Root $d)) {
    $failures += "禁止目录仍存在: $d"
  }
}

# --- 演示样例应存在 ---
$required = @(
  "docs/samples/demo/README.md",
  "docs/samples/demo/01-skus.csv",
  "docs/samples/demo/02-sales-daily-wide.csv",
  "docs/samples/demo/03-inventory-simple.csv",
  "docs/external-share/README.md",
  "docs/external-share/deployment-guide.md",
  "docs/external-share/business-overview.md"
)
foreach ($r in $required) {
  if (-not (Test-Path (Join-Path $Root $r))) {
    $failures += "缺少: $r （可先 pnpm samples:demo）"
  }
}

# --- .env 仅警告（本地开发常见）---
if (Test-Path (Join-Path $Root ".env")) {
  $warnings += "根目录存在 .env：打包 ZIP 时务必排除"
}
if (Test-Path (Join-Path $Root "docker-compose.public.yml")) {
  $warnings += "存在 docker-compose.public.yml（gitignore）：打包时务必排除"
}
foreach ($heavy in @('.worktrees', '.tmp-workbuddy-practice', 'node_modules', 'apps/web/node_modules', 'sites/blueprint-report/node_modules', 'docs/samples/forecast-backtest')) {
  if (Test-Path (Join-Path $Root $heavy)) {
    $warnings += "体积大户仍在: $heavy（打包前请删除；依赖可 pnpm install 重建）"
  }
}

# --- ripgrep / Select-String 扫描 ---
$pattern = 'chinabestwo|HPJzbHdPea7elSs92T8c31BTnxe|QWc8bLj05annNashYaYccebYnjg|UvD5b2txjau5WksACknccdQknHh|scm\.al6s\.cn|\bal6s\.cn\b|10\.100\.1\.154|boway15/scmgent|5N7D2B3'
$excludeDirs = @('node_modules', '.git', '.worktrees', 'pgdata', 'dist', '.turbo', 'AgentStores')

$rg = Get-Command rg -ErrorAction SilentlyContinue
$hits = @()
if ($rg) {
  $args = @(
    '-n', '-i',
    '--glob', '!node_modules/**',
    '--glob', '!.git/**',
    '--glob', '!.worktrees/**',
    '--glob', '!**/audit-external-share.ps1',
    '--glob', '!**/prepare-external-share.ps1',
    '--glob', '!docs/external-share/**',
    $pattern
  )
  $out = & rg @args 2>$null
  if ($out) { $hits = @($out) }
} else {
  Write-Host "未找到 rg，改用 Select-String（较慢）…" -ForegroundColor Yellow
  $files = Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
      $p = $_.FullName
      foreach ($ex in $excludeDirs) {
        if ($p -match [regex]::Escape($ex)) { return $false }
      }
      if ($_.Name -match 'audit-external-share|prepare-external-share') { return $false }
      if ($p -match 'docs[\\/]external-share') { return $false }
      $_.Extension -match '\.(md|ts|tsx|js|mjs|yml|yaml|html|json|env|txt|ps1|mdc)$'
    }
  foreach ($f in $files) {
    $m = Select-String -Path $f.FullName -Pattern $pattern -AllMatches -ErrorAction SilentlyContinue
    foreach ($hit in $m) {
      $rel = $hit.Path.Substring($Root.Length + 1)
      $hits += "${rel}:$($hit.LineNumber):$($hit.Line.Trim())"
    }
  }
}

# 允许名单：审计说明里的关键字枚举、测试用私网、占位示例
$allowRegex = '(172\.16\.0\.1/x|example\.feishu\.cn|scm\.example\.com|docs/external-share|审计|搜索 `|rg -i)'

$badHits = @()
foreach ($h in $hits) {
  if ($h -match $allowRegex) { continue }
  $badHits += $h
}

if ($badHits.Count -gt 0) {
  $failures += "敏感关键字命中 $($badHits.Count) 处（节选最多 40 行）："
  $badHits | Select-Object -First 40 | ForEach-Object { $failures += "  $_" }
}

Write-Host ""
if ($warnings.Count -gt 0) {
  Write-Host "警告:" -ForegroundColor Yellow
  $warnings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}

if ($failures.Count -gt 0) {
  Write-Host "失败:" -ForegroundColor Red
  $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
  Write-Host ""
  Write-Host "审计未通过。修复后重跑本脚本。" -ForegroundColor Red
  exit 1
}

Write-Host "审计通过。" -ForegroundColor Green
exit 0
