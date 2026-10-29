# scm-agent 对外部署指南

> 适用：在自有服务器或云主机上 **Docker Compose** 部署；与内部专用机 SOP（`docs/local-server-release-sop.md`）分离，不含具体域名与内网 IP。

## 1. 架构

```text
浏览器 → (可选) 反向代理 / Cloudflare Tunnel
              ↓
         web 容器 :8081  (React 静态 + Hono API)
              ↓
         postgres:16
              ↓
         cron sidecar → HTTP POST /api/tasks/* + X-Cron-Secret
```

- **生产入口**：`apps/web/server` + 根目录 `Dockerfile`  
- **数据库**：PostgreSQL，Schema 与迁移在 `packages/db`（Drizzle）  
- **可选 AI**：Dify Workflow/RAG；未配置 API Key 时走本地 FAQ 与 TS 补货/预警算法  

## 2. 环境要求

| 项 | 建议 |
|----|------|
| OS | Linux（**CentOS / Rocky / Alma** 见 [centos-docker-deploy.md](./centos-docker-deploy.md)）/ Windows Server / Win11 + WSL2 |
| Docker | Docker Engine 24+ 与 **Compose 插件**（`docker compose`，非旧版 `docker-compose`） |
| 内存 | web 容器建议 ≥ 4GB（`NODE_OPTIONS=--max-old-space-size=4096`） |
| 磁盘 | Postgres 卷 + 可选 `costingdata` 卷（产品核价附件） |
| 端口 | 宿主机 **8081**（默认映射，避免与 Dify 8080 冲突） |

本地开发（非 Docker 全栈）：

```bash
pnpm install
docker compose up -d postgres
cp .env.example .env   # 编辑 DATABASE_URL 等
pnpm db:migrate && pnpm db:seed
pnpm dev               # 前端 + 后端热更新
```

## 3. 首次 Docker 部署

```bash
git clone <接收方私有仓库 URL>
cd scm-agent
cp .env.example .env
# 编辑 .env：至少 JWT_SECRET、CRON_SECRET、BOOTSTRAP_ADMIN_PASSWORD、APP_BASE_URL
docker compose up -d --build
```

**CentOS / Rocky / AlmaLinux**：安装 Docker、firewalld、SELinux 与生产 override 见 **[centos-docker-deploy.md](./centos-docker-deploy.md)**。

Linux 生产可选：

```bash
cp deploy/docker-compose.linux.example.yml docker-compose.linux.yml
docker compose -f docker-compose.yml -f docker-compose.linux.yml up -d --build
```

访问：**http://<主机 IP>:8081**

默认种子用户（`packages/db/src/seed.ts`，可通过环境变量覆盖）：

- 邮箱：`admin@scm.local`  
- 密码：`BOOTSTRAP_ADMIN_PASSWORD`（Compose 默认 `admin123456`，**上线必须修改**）

健康检查：

```bash
curl -s http://127.0.0.1:8081/api/health
```

期望 JSON 中 `db` 正常；`runtime.warnings` 列出未配置项（飞书、Dify 等可后续补）。

## 4. 环境变量要点

完整模板见仓库根目录 **`.env.example`**。分类说明：

### 4.1 必填（生产）

| 变量 | 说明 |
|------|------|
| `DATABASE_URL` | Compose 内由 `docker-compose.yml` 注入；裸机 dev 指向 `127.0.0.1:5432` |
| `JWT_SECRET` | ≥16 位随机串；勿用 `change-me` |
| `CRON_SECRET` | 定时任务 Header `X-Cron-Secret` |
| `APP_BASE_URL` | 浏览器访问根 URL，无尾斜杠；影响 Cookie、飞书 OAuth |
| `BOOTSTRAP_ADMIN_PASSWORD` | 首次 seed 超管密码 |

### 4.2 登录

| 变量 | 典型值 |
|------|--------|
| `AUTH_REQUIRE_LOGIN` | `true` |
| `EMAIL_AUTH_ENABLED` | `true`（邮箱+密码） |
| `FEISHU_AUTH_ENABLED` | 内网试点 `false`；要飞书登录则 `true` + `FEISHU_APP_ID/SECRET` |
| `FEISHU_OAUTH_REDIRECT_URI` | `{APP_BASE_URL}/api/auth/feishu/callback` |

本地 Docker 默认 `COOKIE_SECURE=false` 以便 HTTP 局域网访问；公网 HTTPS 请在 override 中设为 `true`。

### 4.3 飞书多维表格（可选）

未配置时：页面仍可 CSV/XLSX 导入；**从飞书拉取**、部分定时同步、库存总览日快照等不可用。

见 [feishu-bitable-sync.md](../feishu-bitable-sync.md)。需自建飞书应用并填写 `FEISHU_BITABLE_*`（**勿使用文档中的示例 token，须填接收方 Base**）。

QC 复检同步额外需要：

```env
FEISHU_BITABLE_QC_APP_TOKEN=
FEISHU_BITABLE_TABLE_QC_FOLLOW_UP=
FEISHU_BITABLE_VIEW_QC_REINSPECTION=
FEISHU_BITABLE_TABLE_QC_REINSPECTION=
```

未配置四项时，任务 `/api/tasks/qc-reinspection-sync` 会跳过并返回「未配置」。

### 4.4 Dify（可选）

```env
DIFY_BASE_URL=http://<dify-host>/v1
DIFY_API_KEY_KNOWLEDGE=
DIFY_API_KEY_REPLENISHMENT=
DIFY_API_KEY_ALERT=
DIFY_API_KEY_SALES_FORECAST=
DIFY_API_KEY_CS_REPLY_QUALITY=
```

留空则全部降级本地逻辑。Workflow 契约见 [dify-integration-readiness.md](../dify-integration-readiness.md)。

### 4.5 规则与试点

- `ENFORCE_RBAC=true`：菜单级 API 权限  
- `DEMAND_PLAN_PILOT_*`：需求计划试点范围，默认关闭  

## 5. 公网与 HTTPS（示例）

1. 复制 `deploy/docker-compose.public.example.yml` → 根目录 `docker-compose.public.yml`（后者已在 `.gitignore`）  
2. 将 `APP_BASE_URL`、`FEISHU_OAUTH_REDIRECT_URI` 改为接收方域名  
3. 启动：

```bash
docker compose -f docker-compose.yml -f docker-compose.public.yml up -d --build
```

4. 前置 **Cloudflare Tunnel / Nginx / Caddy** 将 443 转到 `127.0.0.1:8081`  
5. 参考模板：`deploy/dedicated-host/cloudflared.config.example.yml`（替换 tunnel 名称与 credentials）

**勿**在 `docker-compose.public.yml` 的 `environment` 里写空字符串覆盖 `.env` 中的飞书变量（Compose 优先级更高）。

## 6. 数据库迁移与种子

发版后若 schema 变更：

```bash
docker compose exec web sh -c "cd /app/packages/db && pnpm exec drizzle-kit migrate"
# 可选：演示数据
docker compose exec web sh -c "cd /app/packages/db && pnpm exec tsx src/seed.ts"
docker compose restart web
```

核对迁移：

```bash
docker compose exec postgres psql -U scm -d scm_dev -c "SELECT id, created_at FROM drizzle.__drizzle_migrations ORDER BY created_at DESC LIMIT 10;"
```

## 7. 定时任务

服务 `cron`（`deploy/cron`）按 `deploy/cron/crontab` 调用内网 `http://web:8081`。

| 操作 | 命令 |
|------|------|
| 查看日志 | `docker compose logs -f cron` |
| 暂停调度 | `docker compose stop cron` 或 `CRON_ENABLED=false` |
| 手动触发 | `docker compose exec cron /usr/local/bin/run-task.sh /api/tasks/stock-alert` |

任务列表见根目录 [README.md](../../README.md#定时任务compose-cron-sidecar)。

## 8. 数据导入建议顺序

合成演示（推荐先跑通）：

```bash
pnpm samples:demo
# 依次导入 docs/samples/demo/01-skus.csv、02-sales-daily-wide.csv、03-inventory-simple.csv
```

生产数据：

1. SKU / 库存周转宽表（自动补全部分主数据）  
2. 销量日/月宽表  
3. 销售预测、库存策略、PMC 计划等  

格式说明：`docs/samples/import/README.md`、`docs/samples/demo/README.md`。

## 9. 常见问题

| 现象 | 处理 |
|------|------|
| 局域网 IP 无法保持登录 | `COOKIE_SECURE=false`（仅 HTTP）；或改用 HTTPS |
| `/api/health` 中飞书同步 false | 检查 `FEISHU_BITABLE_PROCUREMENT_APP_TOKEN` + `FEISHU_BITABLE_TABLE_INVENTORY` |
| Cron 403 | `CRON_SECRET` 与请求 Header 不一致 |
| Windows Docker DB 连接超时 | `DATABASE_URL` 主机用 `127.0.0.1` 而非 `localhost` |
| Linux 容器访问宿主机 Dify 失败 | 确认 `docker-compose.yml` 中 `extra_hosts: host.docker.internal:host-gateway`；或 `.env` 设 `DIFY_DOCKER_HOST` |
| CentOS 外网不通 | firewalld / 云安全组放行 **8081** |
| 内存 OOM | 确认 `shm_size: 256mb`（postgres）与 web `NODE_OPTIONS`；服务器建议 ≥8GB |

## 10. 升级发布

```bash
git pull
docker compose -f docker-compose.yml -f docker-compose.public.yml up -d --build --remove-orphans
curl -s http://127.0.0.1:8081/api/health
```

仅改环境变量、未改镜像时：`--force-recreate web cron` 即可。
