# 演示导入样例（合成数据）

**声明**：本目录文件由 `pnpm samples:demo` 生成，SKU / 销量 / 库存均为虚构，**不含**真实业务数据。

## 文件

| 文件 | 用途 |
|------|------|
| `01-skus.csv` | 商品主数据（5 个 DEMO-SKU） |
| `02-sales-daily-wide.csv` | xiaoshou 日销量宽表（约 90 天） |
| `03-inventory-simple.csv` | 简易库存盘点（非飞书周转宽表） |

## 导入顺序（数据中心 / 对应页面）

1. `pnpm db:migrate && pnpm db:seed`（超管与菜单）
2. 上传 `01-skus.csv`（商品 / SKU 导入）
3. 上传 `02-sales-daily-wide.csv`（销量历史 · 日宽表）
4. 上传 `03-inventory-simple.csv`（库存盘点 · 简易列式）

FOB 分账联调请用 [`../fob/`](../fob/README.md) 合成 xlsx。

## 重新生成

```bash
pnpm samples:demo
```
