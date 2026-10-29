# 部署相关文件

与根目录 `Dockerfile`、`docker-compose.yml` 配合使用。Compose **示例**放在本目录，复制到仓库根后再 `-f` 叠加（生成文件已在 `.gitignore`）。

| 文件 | 用途 |
|------|------|
| [docker-compose.linux.example.yml](./docker-compose.linux.example.yml) | Linux：Postgres 仅本机、时区等 |
| [docker-compose.public.example.yml](./docker-compose.public.example.yml) | 公网域名 / Tunnel / Cookie |
| [centos/](./centos/) | CentOS/Rocky/Alma 速查 |
| [dedicated-host/](./dedicated-host/) | Win11 专用机模板 |
| [cron/](./cron/) | 定时任务 sidecar |

```bash
# Linux
cp deploy/docker-compose.linux.example.yml docker-compose.linux.yml
docker compose -f docker-compose.yml -f docker-compose.linux.yml up -d --build

# 公网
cp deploy/docker-compose.public.example.yml docker-compose.public.yml
# 编辑后：
docker compose -f docker-compose.yml -f docker-compose.public.yml up -d --build
```

对外说明见 [docs/external-share/](../docs/external-share/)。
