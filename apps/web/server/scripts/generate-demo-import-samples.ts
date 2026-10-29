/**
 * 生成对外演示用合成导入样例（无真实业务数据）
 * 用法: pnpm samples:demo
 * 或: cd apps/web && pnpm exec tsx server/scripts/generate-demo-import-samples.ts
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = join(__dirname, '../../../../docs/samples/demo');

const SKUS = [
  { code: 'DEMO-SKU-001', name: 'Demo Product Alpha', category: '演示品类/项目组A' },
  { code: 'DEMO-SKU-002', name: 'Demo Product Beta', category: '演示品类/项目组A' },
  { code: 'DEMO-SKU-003', name: 'Demo Product Gamma', category: '演示品类/项目组B' },
  { code: 'DEMO-SKU-004', name: 'Demo Product Delta', category: '演示品类/项目组B' },
  { code: 'DEMO-SKU-005', name: 'Demo Product Epsilon', category: '演示品类/项目组C' },
] as const;

const PLATFORMS = ['亚马逊', '独立站'] as const;
const STATIONS = ['Amazon美国', 'Shopify美国'] as const;

/** 最近 90 天（含今天），固定相对 2026-06-30 便于测试可复现 */
const ANCHOR = new Date('2026-06-30T00:00:00Z');
const DAY_COUNT = 90;

function pad(n: number) {
  return String(n).padStart(2, '0');
}

function ymd(d: Date): string {
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;
}

function dateColumns(): string[] {
  const cols: string[] = [];
  for (let i = DAY_COUNT - 1; i >= 0; i--) {
    const d = new Date(ANCHOR);
    d.setUTCDate(d.getUTCDate() - i);
    cols.push(`(${ymd(d)})`);
  }
  return cols;
}

function demoQty(skuIndex: number, dayIndex: number, channel: number): number {
  const base = 2 + (skuIndex % 3) + (channel === 0 ? 1 : 0);
  const wave = Math.floor(3 * Math.sin((dayIndex + skuIndex * 7) / 9) + 3);
  return Math.max(0, base + wave + ((dayIndex + skuIndex) % 4));
}

function csvEscape(value: string): string {
  if (/[",\n\r]/.test(value)) return `"${value.replace(/"/g, '""')}"`;
  return value;
}

function toCsv(headers: string[], rows: string[][]): string {
  const lines = [headers.map(csvEscape).join(',')];
  for (const row of rows) lines.push(row.map(csvEscape).join(','));
  return `${lines.join('\n')}\n`;
}

function buildSkuCsv(): string {
  const headers = [
    'sku_code',
    'name',
    'unit',
    'category',
    'merchant_code',
    'merchant_name',
    'lead_time_days',
    'moq',
    'unit_cost',
  ];
  const rows = SKUS.map((s, i) => [
    s.code,
    s.name,
    'pcs',
    s.category,
    `DEMO-M${pad(i + 1)}`,
    `Demo Merchant ${i + 1}`,
    String(45 + i * 5),
    String(10 + i * 2),
    String((20 + i * 3).toFixed(2)),
  ]);
  return toCsv(headers, rows);
}

function buildDailySalesCsv(): string {
  const dayCols = dateColumns();
  const headers = ['SKU', '平台', '站点', ...dayCols];
  const rows: string[][] = [];
  SKUS.forEach((s, skuIndex) => {
    PLATFORMS.forEach((platform, ch) => {
      const station = STATIONS[ch] ?? STATIONS[0];
      const qtyCells = dayCols.map((_, dayIndex) => String(demoQty(skuIndex, dayIndex, ch)));
      rows.push([s.code, platform, station, ...qtyCells]);
    });
  });
  return toCsv(headers, rows);
}

function buildInventoryCsv(): string {
  const headers = [
    'sku_code',
    'name',
    'warehouse',
    'qty_available',
    'qty_in_transit',
    'qty_in_production',
    'recorded_date',
  ];
  const recorded = ymd(ANCHOR);
  const rows = SKUS.map((s, i) => [
    s.code,
    s.name,
    i % 2 === 0 ? 'US-WEST' : 'US-EAST',
    String(40 + i * 12),
    String(5 + i * 2),
    String(i * 3),
    recorded,
  ]);
  return toCsv(headers, rows);
}

const README = `# 演示导入样例（合成数据）

**声明**：本目录文件由 \`pnpm samples:demo\` 生成，SKU / 销量 / 库存均为虚构，**不含**真实业务数据。

## 文件

| 文件 | 用途 |
|------|------|
| \`01-skus.csv\` | 商品主数据（5 个 DEMO-SKU） |
| \`02-sales-daily-wide.csv\` | xiaoshou 日销量宽表（约 90 天） |
| \`03-inventory-simple.csv\` | 简易库存盘点（非飞书周转宽表） |

## 导入顺序（数据中心 / 对应页面）

1. \`pnpm db:migrate && pnpm db:seed\`（超管与菜单）
2. 上传 \`01-skus.csv\`（商品 / SKU 导入）
3. 上传 \`02-sales-daily-wide.csv\`（销量历史 · 日宽表）
4. 上传 \`03-inventory-simple.csv\`（库存盘点 · 简易列式）

FOB 分账联调请用 [\`../fob/\`](../fob/README.md) 合成 xlsx。

## 重新生成

\`\`\`bash
pnpm samples:demo
\`\`\`
`;

function main() {
  mkdirSync(OUT_DIR, { recursive: true });

  const files: Array<{ name: string; body: string }> = [
    { name: '01-skus.csv', body: buildSkuCsv() },
    { name: '02-sales-daily-wide.csv', body: buildDailySalesCsv() },
    { name: '03-inventory-simple.csv', body: buildInventoryCsv() },
    { name: 'README.md', body: README },
  ];

  for (const f of files) {
    const path = join(OUT_DIR, f.name);
    writeFileSync(path, f.body, 'utf8');
    console.log(`Wrote ${path}`);
  }

  console.log(`\nDemo SKUs: ${SKUS.map((s) => s.code).join(', ')}`);
  console.log(`Daily columns: ${DAY_COUNT} days ending ${ymd(ANCHOR)}`);
}

main();
