# 数据导入说明（对外版）

**数据中心 → 数据导入**（`/data/import`）请使用贵司 ERP / 飞书导出的**脱敏**文件，或仓库内合成演示样例。

## 推荐：合成演示包

| 导入类型 | 样例文件 | 说明 |
|----------|----------|------|
| SKU 主数据 | [`../demo/01-skus.csv`](../demo/01-skus.csv) | 5 个 `DEMO-SKU-*` |
| 销量历史（日） | [`../demo/02-sales-daily-wide.csv`](../demo/02-sales-daily-wide.csv) | xiaoshou 日销量宽表 |
| 库存盘点（简易） | [`../demo/03-inventory-simple.csv`](../demo/03-inventory-simple.csv) | 列式库存，非飞书周转宽表 |
| FOB 分账 | [`../fob/`](../fob/README.md) | 合成柜号 xlsx，可联调分摊 |

重新生成：`pnpm samples:demo` / `pnpm samples:fob`。详见 [`../demo/README.md`](../demo/README.md)。

## 导入类型

| 类型 | 格式 | 备注 |
|------|------|------|
| SKU 主数据 | CSV 列式 | 支持标准 9 位 / legacy 编码 |
| 库存盘点 | CSV 或 xlsx | 简易列式或库存周转宽表；大表可走后台批次 |
| 销量历史 | xiaoshou **宽表** CSV/xlsx | 不支持 `sku_code,sale_date,qty_sold` 窄表 |
| 销量预测 | 月度日均宽表 | 与飞书表结构一致时可互导 |
| 库存策略 | CSV | 需 SKU 已存在 |
| 供应商/工厂 | CSV | `merchant_code` 等 |
| 航线周期 | CSV | 更新已有 `warehouse_code` 交期 |
| 下单计划 | CSV + 页面填商家 | PMC 计划行 |

## 建议顺序

1. SKU 主数据（或库存周转宽表自动补全部分字段）
2. 销量日宽表
3. 库存盘点 / 库存策略 / 销量预测 / PMC 计划等按需导入

## FOB 头程分摊联调

不含真实截单数据。可使用 **合成样例**：

- 见 [../fob/README.md](../fob/README.md)
- 模板 xlsx：`docs/samples/import-fob/*模板.xlsx`

## 飞书一键拉取

配置 `FEISHU_BITABLE_*` 后，导入中心可改为从多维表格拉取，字段映射见 [feishu-bitable-sync.md](../../feishu-bitable-sync.md)。

## 已移除能力

- **合规属性导入**（`compliance`）：模块已下线
- **窄表销量 CSV**：后端已拒绝，请改用宽表
- **仓库内真实业务 CSV/xlsx**：已删除；请勿再提交 `docs/samples/xiaoshou/` 等目录
