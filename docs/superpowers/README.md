# Superpowers 设计与实施记录（内部）

本目录存放功能迭代的 **design / plan** 文档，供内部研发追溯决策。

## 对外共享说明

- **接收方主阅读路径**：[`../external-share/`](../external-share/)（部署与业务总览）与 [`../business/`](../business/)（算法与 S&OP）。
- 本目录可能仍出现历史飞书 `tbl*` / Base 占位符；**配置生产飞书时请只使用贵司自己的 `app_token` 与 `table_id`**，见 [`../feishu-bitable-sync.md`](../feishu-bitable-sync.md)。
- 文档中的业务规模数字、内网域名若仍有残留，以 `external-share` 与 `.env.example` 为准，勿照抄进对方环境。

## 目录约定

| 子目录 | 内容 |
|--------|------|
| `specs/` | 设计规格（为什么、边界、数据模型） |
| `plans/` | 实施计划（任务拆解、验收） |

Agent 在本仓开发时可 `@` 引用相关 spec；对外交付时无需单独打包本目录以外的路径。
