# CentOS / Rocky / AlmaLinux 部署

完整步骤见 **[docs/external-share/centos-docker-deploy.md](../../docs/external-share/centos-docker-deploy.md)**。

快速命令：

```bash
cp .env.example .env
# 编辑 JWT_SECRET、CRON_SECRET、BOOTSTRAP_ADMIN_PASSWORD、APP_BASE_URL
docker compose up -d --build
curl -s http://127.0.0.1:8081/api/health
```

生产建议：

```bash
cp docker-compose.linux.example.yml docker-compose.linux.yml
docker compose -f docker-compose.yml -f docker-compose.linux.yml up -d --build
```
