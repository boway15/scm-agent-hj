-- 分仓库存影子长表 + 数据问题类型扩展
-- 0095 应先建类型；此处兜底，避免 journal 漏登记时出现 42704（类型不存在）
DO $$ BEGIN
  CREATE TYPE "inventory_data_issue_type" AS ENUM (
    'missing_available_at',
    'unallocated_warehouse',
    'share_sum_mismatch',
    'unmapped_warehouse',
    'position_source_mismatch',
    'position_share_gap'
  );
EXCEPTION WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
ALTER TYPE "inventory_data_issue_type" ADD VALUE IF NOT EXISTS 'unmapped_warehouse';
--> statement-breakpoint
ALTER TYPE "inventory_data_issue_type" ADD VALUE IF NOT EXISTS 'position_source_mismatch';
--> statement-breakpoint
ALTER TYPE "inventory_data_issue_type" ADD VALUE IF NOT EXISTS 'position_share_gap';
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "warehouse_stock_facts" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
  "snapshot_date" date NOT NULL,
  "sku_id" uuid,
  "sku_code" varchar(100) NOT NULL,
  "warehouse_raw" varchar(100) NOT NULL,
  "warehouse_code" varchar(100) NOT NULL,
  "mapped" boolean DEFAULT true NOT NULL,
  "bucket" varchar(40) NOT NULL,
  "bucket_name" varchar(80) NOT NULL,
  "qty" integer DEFAULT 0 NOT NULL,
  "source" varchar(40) NOT NULL,
  "selected" boolean DEFAULT false NOT NULL,
  "column_name" varchar(200) NOT NULL,
  "created_at" timestamptz DEFAULT now() NOT NULL
);
--> statement-breakpoint
DO $$ BEGIN
  ALTER TABLE "warehouse_stock_facts"
    ADD CONSTRAINT "warehouse_stock_facts_sku_id_skus_id_fk"
    FOREIGN KEY ("sku_id") REFERENCES "public"."skus"("id")
    ON DELETE set null ON UPDATE no action;
EXCEPTION WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "warehouse_stock_facts_date_sku_idx"
  ON "warehouse_stock_facts" ("snapshot_date", "sku_code");
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "warehouse_stock_facts_date_wh_bucket_idx"
  ON "warehouse_stock_facts" ("snapshot_date", "warehouse_code", "bucket");
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS "warehouse_stock_facts_date_selected_idx"
  ON "warehouse_stock_facts" ("snapshot_date", "selected", "sku_id");
