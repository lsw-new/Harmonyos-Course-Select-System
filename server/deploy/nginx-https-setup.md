# HTTPS 反向代理部署说明（lsw666.duckdns.org）

App 后端从「裸 IP + HTTP」改为「域名 + HTTPS」，收尾审计 P2-01「生产包不要写死公网 HTTP IP / 使用 HTTPS」。

## 架构

```
HarmonyOS App
  └─ https://lsw666.duckdns.org/api/...        (AppConfig.baseUrl)
       └─ nginx :443  (Let's Encrypt 证书, TLSv1.2/1.3)
            └─ location /api/ → http://127.0.0.1:8090   (pm2: dtest2-api / Node+Express)
```

- 域名 `lsw666.duckdns.org` → `138.2.47.185`（DuckDNS）。
- 证书：Let's Encrypt（certbot 自动续期），与同机既有 `library`(:5000) 站点共用同一证书与 vhost。
- 既有 `library` 站点 `location /` → `:5000` 不受影响；本后端独占 `location /api/`（`:5000` 不使用 `/api`）。
- `:8090` 仍对外开放，旧版 App（http 直连）可继续使用；新版走 HTTPS。

## 服务器端 nginx 配置

在 `/etc/nginx/sites-available/library` 的 `server { listen 443 ssl; server_name lsw666.duckdns.org; ... }` 块内新增：

```nginx
    # dtest2-api 后端（反代到 Node :8090）
    location /api/ {
        proxy_pass http://127.0.0.1:8090;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
```

应用：`sudo nginx -t && sudo systemctl reload nginx`。

## 后端配合

`src/index.js` 设 `app.set('trust proxy', 'loopback')`：仅信任本机 nginx 转发的 `X-Forwarded-For`，使限流 / `req.ip` 取到真实客户端 IP；外部直连 `:8090` 的非回环对端不被信任，无法伪造 IP 绕过限流。

## 验证

```bash
# 经 nginx TLS → :8090（--resolve 避免 hairpin NAT，校验真实证书）
curl --resolve lsw666.duckdns.org:443:127.0.0.1 -X POST \
  https://lsw666.duckdns.org/api/auth/login \
  -H 'content-type: application/json' \
  -d '{"account":"<账号>","password":"<密码>"}'      # 期望 200
curl --resolve lsw666.duckdns.org:443:127.0.0.1 https://lsw666.duckdns.org/   # library 仍 200
```

## 证书续期

certbot 已配置自动续期（systemd timer）。手动续期：`sudo certbot renew --dry-run` 验证、`sudo certbot renew` 实续，续后 `sudo systemctl reload nginx`。
