import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { getProcurementOpsBitableConfig } from './procurement-ops-feishu-pull.js';

describe('procurement-ops-feishu-pull config', () => {
  it('requires env table id (no hardcoded production default)', () => {
    const prev = process.env.FEISHU_BITABLE_TABLE_PROCUREMENT_OPS;
    delete process.env.FEISHU_BITABLE_TABLE_PROCUREMENT_OPS;
    try {
      const config = getProcurementOpsBitableConfig();
      assert.equal(config.tableId, undefined);
    } finally {
      if (prev == null) delete process.env.FEISHU_BITABLE_TABLE_PROCUREMENT_OPS;
      else process.env.FEISHU_BITABLE_TABLE_PROCUREMENT_OPS = prev;
    }
  });

  it('uses env table id when set', () => {
    const prev = process.env.FEISHU_BITABLE_TABLE_PROCUREMENT_OPS;
    process.env.FEISHU_BITABLE_TABLE_PROCUREMENT_OPS = 'tblCustom456';
    try {
      assert.equal(getProcurementOpsBitableConfig().tableId, 'tblCustom456');
    } finally {
      if (prev == null) delete process.env.FEISHU_BITABLE_TABLE_PROCUREMENT_OPS;
      else process.env.FEISHU_BITABLE_TABLE_PROCUREMENT_OPS = prev;
    }
  });
});
