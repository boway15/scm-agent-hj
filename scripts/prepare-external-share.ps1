# 对外共享前脱敏：删除真实业务样例、内部报告，并提示本地私密文件
# Usage:
#   .\scripts\prepare-external-share.ps1 -WhatIf
#   .\scripts\prepare-external-share.ps1

param(
  [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

function Remove-Paths {
  param([string[]]$Paths, [string]$Label)
  foreach ($rel in $Paths) {
    $full = Join-Path $Root $rel
    if (-not (Test-Path $full)) { continue }
    if ($WhatIf) {
      Write-Host "[WhatIf] 删除 $Label : $rel"
    } else {
      if (Test-Path $full -PathType Container) {
        Remove-Item -Recurse -Force $full
      } else {
        Remove-Item -Force $full
      }
      Write-Host "已删除: $rel"
    }
  }
}

function Git-Rm-IfTracked {
  param([string[]]$Paths)
  foreach ($rel in $Paths) {
    $tracked = git ls-files -- $rel 2>$null
    if (-not $tracked) { continue }
    if ($WhatIf) {
      Write-Host "[WhatIf] git rm -- $rel"
    } else {
      git rm -f -- $rel 2>$null
      if ($LASTEXITCODE -eq 0) { Write-Host "git rm: $rel" }
    }
  }
}

Write-Host "=== scm-agent 对外共享脱敏 ===" -ForegroundColor Cyan
Write-Host "仓库根: $Root"

# --- Git 已跟踪：真实/敏感样例（保留 fob 合成样例与 import README）---
$gitRm = @(
  "docs/samples/caigou",
  "docs/samples/cs",
  "docs/samples/kucun",
  "docs/samples/xiaoshou",
  "docs/samples/采购",
  "docs/samples/import/tengfei近3个月买家消息.xlsx",
  "docs/samples/forecast-july-2026-accuracy-compare.csv",
  "docs/samples/forecast-july-2026-blend-system-actual.csv",
  "docs/samples/七月预测实际偏差对比.csv",
  "docs/samples/import-fob/1.体积导入-导出截单清单数据导出_202607011522.xlsx",
  "docs/samples/import-fob/体积信息_202606181444.xlsx",
  "docs/samples/import-fob/导出-按工厂主体导出FOB工厂测试--小A2026-06.xlsx",
  "docs/samples/import-fob/导出截单清单数据导出_202607150908.xlsx",
  "docs/samples/import-fob/库存表-SKU库存周转情况查询-明细6a4227ef43084ca969e19dfe.xlsx",
  "docs/reports/2026-feishu-plus-contest-entry.md",
  "docs/reports/2026-feishu-plus-project-description.md",
  "docs/reports/scm-blueprint.html",
  "docs/reports/scm-feishu-ai-blueprint-report.md",
  "sites/blueprint-report",
  "apps/web/scripts/.hono-test",
  "apps/web/tmp-hono-test"
)

foreach ($item in $gitRm) {
  $full = Join-Path $Root $item
  if (Test-Path $full -PathType Container) {
    Get-ChildItem -Path $full -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
      $rel = $_.FullName.Substring($Root.Length + 1) -replace '\\', '/'
      Git-Rm-IfTracked @($rel)
    }
    if (-not $WhatIf -and (Test-Path $full)) {
      Remove-Item -Recurse -Force $full -ErrorAction SilentlyContinue
    } elseif ($WhatIf -and (Test-Path $full)) {
      Write-Host "[WhatIf] 删除目录: $item"
    }
  } else {
    Git-Rm-IfTracked @($item)
    if (-not $WhatIf -and (Test-Path $full)) { Remove-Item -Force $full }
  }
}

# --- 未跟踪本地产物 / 体积大户（可重建）---
$localOnly = @(
  ".tmp-rules-baseline-full.json",
  ".tmp-rules-baseline.json",
  ".tmp-ai-miss-analysis.sql",
  ".tmp-workbuddy-practice",
  ".worktrees",
  ".superpowers",
  "node_modules",
  "apps/web/node_modules",
  "apps/web/dist",
  "apps/web/docs",
  "apps/web/apps",
  "apps/web/tmp-hono-test",
  "apps/web/scripts/.hono-test",
  "apps/web/scm-agent-miaoda.zip",
  "sites/blueprint-report",
  "sites/blueprint-report/node_modules",
  "sites/blueprint-report/dist",
  "docs/reports/scm-blueprint.html",
  "docs/reports/scm-feishu-ai-blueprint-report.md",
  "docs/samples/forecast-backtest",
  "cookies.txt",
  "-w",
  "docs/samples/_count-sku-csv.mjs",
  "docs/samples/_export-batch2-en.sql",
  "docs/samples/_export-missing-only.mjs",
  "docs/samples/_gen-zh-table.mjs",
  "docs/samples/_no-forecast-md.txt",
  "docs/samples/_print-no-md.mjs",
  "docs/samples/sku-forecast-check-DRAFT-1792044685998-en.csv",
  "docs/samples/sku-forecast-check-DRAFT-1792044685998.csv",
  "docs/samples/sku-forecast-missing-DRAFT-1792044685998.csv"
)
Remove-Paths -Paths $localOnly -Label "本地临时/缓存"

Write-Host ""
Write-Host "请手动确认未打包进 ZIP / 未 push 的文件：" -ForegroundColor Yellow
Write-Host "  .env, docker-compose.public.yml, pgdata/, cookies.txt, login.json"
Write-Host ""
Write-Host "下一步：pnpm samples:demo ；然后运行审计门禁：" -ForegroundColor Yellow
Write-Host "  .\scripts\audit-external-share.ps1"
Write-Host ""
Write-Host "对外文档入口: docs/external-share/README.md" -ForegroundColor Green
