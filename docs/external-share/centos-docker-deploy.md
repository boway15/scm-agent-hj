# CentOS / Rocky / AlmaLinux Docker 部署指南

> 适用：**CentOS Stream 8/9**、**Rocky Linux 8/9**、**AlmaLinux 8/9** 等 RHEL 系服务器。  
> 通用 Compose 说明见 [deployment-guide.md](./deployment-guide.md)。  
> 镜像为 **linux/amd64**（`node:20-alpine` / `postgres:16-alpine`）；ARM 服务器需自行验证构建。

---

## 1. 与 Windows 专用机的差异

| 项 | CentOS Linux | Win11 + Docker Desktop |
|----|----------------|-------------------------|
| 安装 | Docker Engine + Compose **插件** | Docker Desktop |
| 访问宿主机 Dify | 需 `host.docker.internal`（根目录 `docker-compose.yml` 已配 `host-gateway`） | Desktop 自带 |
| 防火墙 | **firewalld** 放行 8081 | Windows 防火墙 |
| SELinux | 默认 Enforcing；**命名卷**一般无问题 | 无 |
| 宿主机 Node/pnpm | **不需要**（全在容器内 build/run） | 可选（本地 dev） |

---

## 2. 服务器要求

| 项 | 建议 |
|----|------|
| CPU | 2 核+ |
| 内存 | **≥ 8GB**（web 容器 `NODE_OPTIONS=4096MB` + Postgres + 构建缓存） |
| 磁盘 | ≥ 30GB 可用（镜像 + `pgdata` / `costingdata` 卷） |
| 端口 | **8081**（业务）；5432 建议仅本机（见 [docker-compose.linux.example.yml](../../deploy/docker-compose.linux.example.yml)） |

---

## 3. 安装 Docker（Rocky / Alma / CentOS Stream 9 示例）

```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
# 重新登录 SSH 后生效
docker --version
docker compose version
```

**CentOS 7（已 EOL）**：仅建议迁移到 Rocky 8+；若必须沿用，请安装 [Docker CE 官方文档](https://docs.docker.com/engine/install/centos/) 对应 7 的 repo，且内核需 ≥ 3.10。

---

## 4. 获取代码并配置

```bash
sudo mkdir -p /opt/scm-agent
sudo chown "$USER:$USER" /opt/scm-agent
cd /opt/scm-agent
git clone <你的仓库 URL> .
cp .env.example .env
```

编辑 `.env`（生产至少修改）：

```env
JWT_SECRET=<随机长串>
CRON_SECRET=<随机长串>
BOOTSTRAP_ADMIN_PASSWORD=<强密码>
# 浏览器访问地址（IP 或域名，无尾斜杠）
APP_BASE_URL=http://<服务器IP>:8081
```

可选：Dify 跑在**同一台宿主机** 8080 端口时：

```env
DIFY_BASE_URL=http://127.0.0.1:8080/v1
# 容器内会自动改写为 host.docker.internal（见 apps/web/server/integrations/dify.ts）
# 若 Dify 在其它机器，直接写内网 URL，例如：
# DIFY_BASE_URL=http://10.0.0.5/v1
```

---

## 5. 首次启动

```bash
cd /opt/scm-agent
docker compose up -d --build
```

生产建议叠加 Linux override（收紧 Postgres 端口、时区）：

```bash
cp deploy/docker-compose.linux.example.yml docker-compose.linux.yml
docker compose -f docker-compose.yml -f docker-compose.linux.yml up -d --build
```

公网 + HTTPS + 飞书登录时，再叠加（见 [deployment-guide.md](./deployment-guide.md) 第 5 节）：

```bash
cp deploy/docker-compose.public.example.yml docker-compose.public.yml
# 编辑域名与 FEISHU_OAUTH_REDIRECT_URI
docker compose -f docker-compose.yml -f docker-compose.linux.yml -f docker-compose.public.yml up -d --build
```

---

## 6. 防火墙与 SELinux

### firewalld（对外提供 8081）

```bash
sudo firewall-cmd --permanent --add-port=8081/tcp
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports
```

若前面有 **Nginx/Caddy** 只暴露 443，则仅放行 443，8081 绑定 `127.0.0.1`。

### SELinux

- 默认使用 Compose **命名卷** `pgdata`、`costingdata`，通常无需 `:Z` 标签。
- 若将 Postgres 数据 **bind mount** 到 `/opt/...`，需：

```bash
sudo chcon -Rt svirt_sandbox_file_t /opt/scm-agent/pgdata
# 或 compose volumes 加 :Z（仅该目录独占时）
```

---

## 7. 验收

```bash
docker compose ps
curl -s http://127.0.0.1:8081/api/health | head -c 500
echo
docker compose logs --tail=30 web
docker compose logs --tail=20 cron
```

浏览器：`http://<服务器IP>:8081`，登录 `admin@scm.local` / `BOOTSTRAP_ADMIN_PASSWORD`。

演示数据（可选，在**开发机**生成后上传 CSV，或在服务器装 Node 后 `pnpm samples:demo`）见 [../samples/demo/README.md](../samples/demo/README.md)。

---

## 8. 日常运维

| 操作 | 命令 |
|------|------|
| 拉代码并重建 | `git pull && docker compose up -d --build --remove-orphans` |
| 仅重启 web | `docker compose restart web` |
| 查看定时任务 | `docker compose logs -f cron` |
| 停调度 | `docker compose stop cron` |
| 备份数据库 | `docker compose exec -T postgres pg_dump -U scm scm_dev > scm_dev_$(date +%F).sql` |
| 恢复（慎用） | `cat backup.sql \| docker compose exec -T postgres psql -U scm scm_dev` |

升级后迁移（若 entrypoint 未自动跑完）：

```bash
docker compose exec web sh -c "cd /app/packages/db && pnpm exec drizzle-kit migrate"
```

---

## 9. Nginx 反向代理（HTTPS 示例）

业务容器仍监听 `127.0.0.1:8081`，Nginx 终止 TLS：

```nginx
server {
    listen 443 ssl http2;
    server_name scm.example.com;

    ssl_certificate     /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8081;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        client_max_body_size 100m;
    }
}
```

同时在 `docker-compose.public.yml` 或 `.env` 中设置：

- `APP_BASE_URL=https://scm.example.com`
- `COOKIE_SECURE=true`（HTTPS 必须）

---

## 10. 常见问题（CentOS）

| 现象 | 处理 |
|------|------|
| `docker compose` 不存在 | 安装 `docker-compose-plugin`，勿只用旧版 `docker-compose` v1 |
| 构建 OOM / 卡住 | 增加 swap 或升内存；`docker compose build web` 单独重试 |
| 外网无法访问 8081 | `firewall-cmd` 放行；云厂商安全组放行 |
| Dify 连不上 | 确认 `DIFY_BASE_URL`；同机 Dify 用 `127.0.0.1` + 已配 `extra_hosts` |
| 飞书 OAuth 失败 | `APP_BASE_URL` / 回调 URL 与飞书控制台完全一致 |
| 5432 被扫描 | 使用 `docker-compose.linux.yml` 绑定 `127.0.0.1:5432` |
| 时区不对 | cron/web 设 `TZ=Asia/Shanghai`（linux override 已含） |

---

## 11. 开机自启

Docker 服务已 `enable` 时，容器 `restart: unless-stopped` 会在重启后自动拉起。验证：

```bash
sudo systemctl is-enabled docker
docker compose ps
```
