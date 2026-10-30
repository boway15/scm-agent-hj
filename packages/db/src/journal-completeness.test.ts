import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const drizzleDir = join(root, 'drizzle');
const journalPath = join(drizzleDir, 'meta', '_journal.json');

type Journal = {
  entries: Array<{ idx: number; tag: string }>;
};

function loadJournal(): Journal {
  return JSON.parse(readFileSync(journalPath, 'utf8')) as Journal;
}

function sqlPath(tag: string): string {
  return join(drizzleDir, `${tag}.sql`);
}

describe('drizzle journal completeness', () => {
  it('registers 0095_inventory_data_issues before 0111_warehouse_stock_facts', () => {
    const tags = loadJournal().entries.map((e) => e.tag);
    const createIdx = tags.indexOf('0095_inventory_data_issues');
    const alterIdx = tags.indexOf('0111_warehouse_stock_facts');
    assert.notEqual(createIdx, -1, '0095_inventory_data_issues must be in _journal.json');
    assert.notEqual(alterIdx, -1, '0111_warehouse_stock_facts must be in _journal.json');
    assert.ok(
      createIdx < alterIdx,
      'CREATE TYPE inventory_data_issue_type (0095) must run before ALTER TYPE (0111)',
    );
  });

  it('creates each ALTER TYPE target in an earlier journaled migration', () => {
    const tags = loadJournal().entries.map((e) => e.tag);
    const createdAt = new Map<string, number>();
    const missing: string[] = [];

    tags.forEach((tag, index) => {
      const sql = readFileSync(sqlPath(tag), 'utf8');
      for (const match of sql.matchAll(
        /CREATE\s+TYPE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:"[^"]+"\.)?"?(\w+)"?/gi,
      )) {
        const name = match[1]!.toLowerCase();
        if (!createdAt.has(name)) createdAt.set(name, index);
      }
      for (const match of sql.matchAll(/ALTER\s+TYPE\s+(?:"[^"]+"\.)?"?([A-Za-z_]\w*)"?/gi)) {
        const name = match[1]!.toLowerCase();
        if (!createdAt.has(name)) {
          missing.push(`${tag} ALTER TYPE ${name} (no earlier CREATE TYPE in journal)`);
        }
      }
    });

    assert.deepEqual(missing, []);
  });

  it('registers SQL files required by current inventory schema', () => {
    const tags = new Set(loadJournal().entries.map((e) => e.tag));
    for (const tag of [
      '0095_inventory_data_issues',
      '0097_inventory_dest_allocations',
      '0104_demand_plan_weekly_menu_rename',
      '0105_sku_commercial_status',
    ]) {
      assert.ok(tags.has(tag), `${tag} must be in _journal.json so migrate will apply it`);
    }
  });

  it('has a SQL file for every journal tag', () => {
    const sqlFiles = new Set(
      readdirSync(drizzleDir).filter((name) => name.endsWith('.sql')),
    );
    const missingFiles = loadJournal()
      .entries.map((e) => `${e.tag}.sql`)
      .filter((name) => !sqlFiles.has(name));
    assert.deepEqual(missingFiles, []);
  });
});
