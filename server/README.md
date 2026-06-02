# dtest2-harmony-api · Track B 后端（垂直切片）

景德镇艺术职业大学教务 App 的远程后端 API。当前为**垂直切片**：认证 / 课程 / 选课。
Node.js + Express + pg，返回 App 端 `ApiResponse` 信封 `{ success, data, error }`，直连本地 Postgres（`dtest2` schema）。

## 端点

| 方法 | 路径 | 说明 | 鉴权 |
| --- | --- | --- | --- |
| GET | `/health` | 健康检查 + DB 连通 | 否 |
| POST | `/api/auth/login` | `{ account, password }` → `{ token, accountId, role }` | 否 |
| GET | `/api/courses?status=open` | 课程列表（selectedCount 由 selections 派生） | Bearer |
| GET | `/api/selection-rounds/active` | 当前进行中轮次 | Bearer |
| GET | `/api/selections?studentId=` | 我的已选课程 | Bearer |
| POST | `/api/selections` | `{ studentId, courseId }` 选课（轮次/容量/重复校验） | Bearer |
| DELETE | `/api/selections` | `{ studentId, courseId }` 退课（软删除） | Bearer |

## 部署（服务器本机，连 127.0.0.1:15432）

```bash
cd ~/dtest2-api
cp .env.example .env      # 填入 PGPASSWORD 与 JWT_SECRET
npm install --omit=dev
npm run seed              # 重置测试账号密码 + 演示轮次置 running（幂等）
pm2 start src/index.js --name dtest2-api
pm2 save
```

测试账号（seed 后）：学生 `2023307020941 / Elysia@2024`、管理员 `A20251001 / Admin@2024`。

## 冒烟测试

```bash
curl -s localhost:8090/health
TOKEN=$(curl -s localhost:8090/api/auth/login -H 'Content-Type: application/json' \
  -d '{"account":"2023307020941","password":"Elysia@2024"}' | python3 -c 'import sys,json;print(json.load(sys.stdin)["data"]["token"])')
curl -s localhost:8090/api/courses?status=open -H "Authorization: Bearer $TOKEN"
curl -s -X POST localhost:8090/api/selections -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -d '{"studentId":"2023307020941","courseId":"course-cs101"}'
```

## 说明

- Postgres 仅绑 `127.0.0.1`，后端须与库同机部署。
- `.env` 含密钥，不入库（见 `.gitignore`）。
- 密码哈希 SHA-256+盐，演示用途；生产建议 bcrypt/argon2。
- App 端通过 `AppConfig.useRemote` 开关接入（见 App 仓库 `common/remote`）。
