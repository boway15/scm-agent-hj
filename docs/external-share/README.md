# 对外共享包说明

本目录面向**将 scm-agent 交付给其他公司**时的部署与业务阅读路径。共享前请在仓库根目录执行脱敏与审计脚本，并自行核对是否仍有内网地址、飞书 Base、真实 SKU/销量等残留。

## 共享前必做

```powershell
# 仓库根目录
.\scripts\prepare-external-share.ps1 -WhatIf   # 预览将删除/脱敏项
.\scripts\prepare-external-share.ps1           # 执行（含 git rm 已跟踪样例）
pnpm samples:demo                              # 确保合成演示 CSV 存在
.\scripts\audit-external-share.ps1             # 关键字与样例目录门禁（失败则勿打包）
```

流程：**prepare → samples:demo → audit → 打包**。  
**交给运维的步骤与邮件模板**：[handoff-to-ops.md](./handoff-to-ops.md)。

手动确认：

- [ ] 根目录无 `.env`、`docker-compose.public.yml`（已在 `.gitignore`；本地若存在含真实域名，**勿打包进 ZIP**）
- [ ] 无 `.worktrees/`、`.tmp-workbuddy-practice/`、`node_modules/`、`docs/samples/forecast-backtest/`、数据库 dump、`pgdata/`（体积大户，接收方自行 `pnpm install`）
- [ ] 飞书 / Dify / JWT / Cron 等密钥仅存在于接收方自己的 `.env`
- [ ] `audit-external-share.ps1` 退出码为 0
- [ ] 打包体积建议：源码 ZIP（不含 `.git` / `node_modules`）通常远小于 200MB

## 文档阅读顺序

| 顺序 | 文档 | 用途 |
|------|------|------|
| 1 | [部署指南](./deployment-guide.md) | Docker 首次安装、环境变量、可选飞书/Dify/公网 |
| 1b | [CentOS Docker 部署](./centos-docker-deploy.md) | Rocky/Alma/CentOS Stream：安装 Engine、防火墙、HTTPS、运维 |
| 2 | [业务总览](./business-overview.md) | 模块地图、角色、与 ERP/飞书边界 |
| 3 | [scm-demand-supply-inventory-logic.md](../business/scm-demand-supply-inventory-logic.md) | 需求·供应·库存算法与数据流（技术+业务） |
| 4 | [scm-sop-operating-standard.md](../business/scm-sop-operating-standard.md) | S&OP 运作 SOP（谁何时做什么） |
| 5 | [README.md](../../README.md) | 功能路由表、定时任务一览 |

集成类（按需）：

- 飞书多维表格：[feishu-bitable-sync.md](../feishu-bitable-sync.md)
- Dify：[dify/setup-guide.md](../dify/setup-guide.md)、[dify-integration-readiness.md](../dify-integration-readiness.md)
- FOB 分账样例：[samples/fob/README.md](../samples/fob/README.md)（合成数据，可联调）
- 演示导入包：[samples/demo/README.md](../samples/demo/README.md)

## 演示数据

对外包**不包含**真实销量、库存、客服消息、采购跟单导出。接收方应：

1. `pnpm db:migrate && pnpm db:seed` 获得演示账号与最小菜单数据  
2. 使用 `docs/samples/demo/` 合成 CSV（或自家 ERP/飞书脱敏导出）经 **数据中心 → 数据导入** 上传  
3. FOB 模块可用 `docs/samples/fob/` 下合成 xlsx 做分摊联调  

## Cursor / Agent 说明

`.cursor/rules`、`.cursor/skills` **不随仓库交付**（已在 `.gitignore`）。接收方二次开发请自行维护 Cursor 配置；业务与部署以本目录文档及 `README.md` 为准。

## 许可与责任

交付前请由法务确认源码许可、第三方依赖（Dify、飞书 API 等）及数据中是否仍含个人信息/商业机密。本说明不构成法律意见。
