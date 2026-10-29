# 提交给运维（交付清单）

开发侧完成脱敏与审计后，按下列方式把 **代码 + 文档 + 环境说明** 交给运维；**密钥单独通道**，不要打进源码包。

---

## 一、开发侧（交付前）

在仓库根目录执行：

```powershell
git pull
.\scripts\prepare-external-share.ps1
pnpm samples:demo
.\scripts\audit-external-share.ps1
```

审计通过后：

1. **提交并打 tag**（示例 `v1.2.1-ops`），并双推到 GitHub + GitLab（见下文「Git 双远程」）。
2. 确认未提交：`.env`、`docker-compose.public.yml`、`docker-compose.linux.yml`、`pgdata/`、`node_modules/`。

---

## Git 双远程（GitHub + GitLab）

| 远程名 | 地址 | 用途 |
|--------|------|------|
| `origin` | `https://github.com/boway15/scm-agent-hj.git` | 开发主仓 |
| `gitlab` | `https://gitlab.chinabestwo.cn/caobaowei/scm-agent-hj.git` | 运维 / 内网 GitLab |

首次配置（本机执行一次）：

```powershell
git remote set-url origin https://github.com/boway15/scm-agent-hj.git
git remote add gitlab https://gitlab.chinabestwo.cn/caobaowei/scm-agent-hj.git
git remote -v
```

日常双推：

```powershell
git push -u origin main
git push -u gitlab main
git push origin --tags
git push gitlab --tags
```

或：`.\scripts\git-push-dual.ps1 main -Tags`

### 历史瘦身后（force push）

若 GitLab 的 `main` **受保护、禁止 force push**，瘦身后的干净历史可能在分支 `main-rewritten`（与 GitHub `main` 同 commit）。运维可：

1. 在 GitLab 项目设置中临时允许 Maintainer force push `main`，再执行  
   `git push --force-with-lease gitlab main`；或  
2. 将默认分支改为 `main-rewritten` / 删除旧 `main` 后把 `main-rewritten` 重命名为 `main`；或  
3. 直接 `git clone -b main-rewritten <gitlab-url>` 部署。

已 clone 旧 `main` 的同事需 **重新 clone** 或 `git fetch` 后 `reset --hard` 到新 SHA（旧大文件 blob 仅存在于本地未 gc 的备份分支）。

---

## 二、交付物（给运维的三件套）

| # | 内容 | 说明 |
|---|------|------|
| 1 | **源码** | 私有 Git 地址 + tag/commit；或 **ZIP**（见下文打包命令，勿含 `.git` / `node_modules`） |
| 2 | **环境模板** | 仓库内 `.env.example`；运维复制为服务器上的 `.env` 并填生产值 |
| 3 | **部署入口文档** | 发链接或路径：[CentOS Docker 部署](./centos-docker-deploy.md)（Linux）或 [deployment-guide.md](./deployment-guide.md)（通用） |

可选附件：

- [business-overview.md](./business-overview.md) + [scm-sop-operating-standard.md](../business/scm-sop-operating-standard.md)（业务与 S&OP）
- `docs/samples/demo/`（演示 CSV，已在仓库内）

**不要**随源码包提供：真实 `.env`、数据库 dump、内网 `docker-compose.public.yml`。

---

## 三、密钥与集成（单独给运维 / 安全岗）

通过 **密码管理器 / 工单附件 / 当面** 交付，勿进 Git：

| 变量 | 用途 |
|------|------|
| `JWT_SECRET` / `CRON_SECRET` | 登录与定时任务 |
| `BOOTSTRAP_ADMIN_PASSWORD` | 首次超管（上线后改密） |
| `FEISHU_APP_ID` / `FEISHU_APP_SECRET` | 飞书登录与 Bitable（若启用） |
| `FEISHU_BITABLE_*` | 各多维表格 ID（贵司 Base） |
| `DIFY_API_KEY_*` / `DIFY_BASE_URL` | 可选 AI |

运维在服务器：

```bash
cp .env.example .env
chmod 600 .env
vi .env
```

---

## 四、打包 ZIP（无 Git 时）

在**已审计通过**的目录执行（PowerShell 示例）：

```powershell
cd D:\Docker\project\scm-agent-hj
$dest = "scm-agent-ops-$(Get-Date -Format yyyyMMdd).zip"
# 排除体积与敏感（按需调整路径）
$exclude = @('node_modules','.git','pgdata','.env','docker-compose.public.yml','.worktrees','.tmp-*')
# 使用 tar（Win10+）：
tar -a -c -f $dest --exclude=node_modules --exclude=.git --exclude=pgdata --exclude=.env --exclude=docker-compose.public.yml .
```

Linux 打包：

```bash
tar -czvf scm-agent-ops-$(date +%F).tar.gz \
  --exclude=node_modules --exclude=.git --exclude=pgdata --exclude=.env \
  --exclude=docker-compose.public.yml .
```

交付前看体积：通常 **几十 MB**；若 >200MB，检查是否误含 `node_modules` / `.git`。

---

## 五、运维侧（CentOS 最短路径）

```bash
# 1. 解压或 git clone 到 /opt/scm-agent
# 2. 安装 Docker（见 centos-docker-deploy.md 第 3 节）
cd /opt/scm-agent
cp .env.example .env && vi .env

# 3. 启动
docker compose up -d --build
# 生产建议：
# cp docker-compose.linux.example.yml docker-compose.linux.yml
# docker compose -f docker-compose.yml -f docker-compose.linux.yml up -d --build

# 4. 防火墙
sudo firewall-cmd --permanent --add-port=8081/tcp && sudo firewall-cmd --reload

# 5. 验收
curl -s http://127.0.0.1:8081/api/health
```

默认登录：`admin@scm.local` / `.env` 中的 `BOOTSTRAP_ADMIN_PASSWORD`。

HTTPS：Nginx 反代 + `APP_BASE_URL` / `COOKIE_SECURE` 见 [centos-docker-deploy.md](./centos-docker-deploy.md) 第 9 节。

---

## 六、交付邮件 / 工单模板（可复制）

**标题**：scm-agent 生产部署包 vX.X.X  

**正文要点**：

1. 源码：`<Git URL @ tag>` 或附件 ZIP  
2. 部署文档：`docs/external-share/centos-docker-deploy.md`  
3. 环境变量：按 `.env.example` 在服务器建 `.env`（密钥见密管/附件）  
4. 监听端口：**8081**；Postgres 建议仅本机（`docker-compose.linux.yml`）  
5. 验收：`/api/health` 正常 + 浏览器登录 +（可选）导入 `docs/samples/demo`  
6. 联系人：开发 / 产品（飞书表、Dify 由谁申请）

---

## 七、常见问题

| 问题 | 说明 |
|------|------|
| 运维要不要装 Node？ | **不需要**，仅 `docker compose build/up` |
| 数据库要不要单独装？ | **不需要**，Compose 内 `postgres:16-alpine` |
| 和 Win11 专用机文档冲突？ | 内部 Win 文档在 `docs/local-server-release-sop.md`；Linux 以 **centos-docker-deploy** 为准 |
| 升级怎么交？ | 新 tag + `git pull` + `docker compose up -d --build` |
