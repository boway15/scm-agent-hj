import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { getInventoryQueryBitableConfig } from './inventory-query-feishu-pull.js';

describe('inventory-query-feishu-pull config', () => {
  it('requires env table id (no hardcoded production default)', () => {
    const prev = process.env.FEISHU_BITABLE_TABLE_INVENTORY_QUERY;
    delete process.env.FEISHU_BITABLE_TABLE_INVENTORY_QUERY;
    try {
      const config = getInventoryQueryBitableConfig();
      assert.equal(config.tableId, undefined);
    } finally {
      if (prev == null) delete process.env.FEISHU_BITABLE_TABLE_INVENTORY_QUERY;
      else process.env.FEISHU_BITABLE_TABLE_INVENTORY_QUERY = prev;
    }
  });

  it('allows env override for table id', () => {
    const prev = process.env.FEISHU_BITABLE_TABLE_INVENTORY_QUERY;
    process.env.FEISHU_BITABLE_TABLE_INVENTORY_QUERY = 'tblCustom123';
    try {
      assert.equal(getInventoryQueryBitableConfig().tableId, 'tblCustom123');
    } finally {
      if (prev == null) delete process.env.FEISHU_BITABLE_TABLE_INVENTORY_QUERY;
      else process.env.FEISHU_BITABLE_TABLE_INVENTORY_QUERY = prev;
    }
  });
});
