import { readFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  parseDailySalesRows,
  wideCsvBufferToRowObjects,
} from './sales-report-parser.js';
import { computeForecastDailyAvgForMonth, resolveLastYearSameMonthDailyAvg } from './forecast-baseline.js';

const samplesDir = join(dirname(fileURLToPath(import.meta.url)), '../../../docs/samples/demo');
const DAILY_FILE = '02-sales-daily-wide.csv';

describe('xiaoshou sample smoke', () => {
  it('parses demo daily wide CSV and produces non-zero forecast inputs', () => {
    const dailyPath = join(samplesDir, DAILY_FILE);
    if (!existsSync(dailyPath)) {
      console.warn(`skip: missing ${dailyPath}; run pnpm samples:demo`);
      return;
    }

    const dailyObjects = wideCsvBufferToRowObjects(readFileSync(dailyPath));
    const daily = parseDailySalesRows(dailyObjects);
    assert.ok(daily.diagnostics.expandedRowCount > 0, 'daily should expand rows');

    const targetSku = 'DEMO-SKU-001';
    const skuDailyRows = daily.rows.filter((row) => row.skuCode === targetSku);
    assert.ok(skuDailyRows.length > 0, 'demo SKU should appear in daily rows');

    const recent30 =
      skuDailyRows
        .filter((row) => row.saleDate >= '2026-06-01')
        .reduce((sum, row) => sum + row.qtySold, 0) / 30;
    const recent90 =
      skuDailyRows.reduce((sum, row) => sum + row.qtySold, 0) / 90;

    const lastYearSameMonthDailyAvg = resolveLastYearSameMonthDailyAvg({
      dailyRows: skuDailyRows,
      monthlyRows: [],
      forecastYear: 2026,
      month: 7,
    });

    const { forecastDailyAvg } = computeForecastDailyAvgForMonth({
      recent30DailyAvg: recent30,
      recent90DailyAvg: recent90,
      lastYearSameMonthDailyAvg,
      seasonalityFactor: 1,
      trendFactor: 1,
    });

    assert.ok(
      forecastDailyAvg > 0 || recent30 > 0 || recent90 > 0,
      `demo SKU should yield positive sales or forecast: forecast=${forecastDailyAvg}`,
    );
  });
});
