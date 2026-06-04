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
npm run migrate           # 建表迁移：应用 migrations/*.sql（幂等，已应用版本跳过）
npm run seed              # 演示数据：重置测试账号密码 + 演示轮次置 running（幂等）
pm2 start src/index.js --name dtest2-api
pm2 save
```

测试账号（seed 后）：学生 `2023307020941 / Elysia@2024`、管理员 `A20251001 / Admin@2024`。

## 数据库迁移 vs 演示数据（P1-08）

二者职责分离，均幂等可重复执行：

- **建表迁移** `npm run migrate`（`migrate.js`）：按 `migrations/NNN_*.sql` 文件名顺序，
  应用尚未记录于 `dtest2.schema_migrations(version, name, applied_at)` 的迁移，每个迁移在
  独立事务内执行并登记版本号。已应用的版本会跳过——新环境从空库可凭仓库恢复完整 schema。
  - `migrations/001_initial_dtest2_schema.sql`：由线上库 `pg_dump --schema-only -n dtest2`
    导出（已去除 psql 专用的 `\restrict`/`\unrestrict` 元命令，可经 pg 库直接执行），
    末尾附幂等登记 INSERT。涵盖全部 31 张表（accounts/student_profiles/courses/selections/
    grades/notices/leave_requests/feedback_items/evaluation_*/practice_*/approval_*/
    roles/permissions/role_permissions/audit_logs 等）。
- **演示数据** `npm run seed`（`seed.js`）：仅灌入/重置演示用账号、密码、轮次、示例业务数据，
  不负责建表。

后续新增结构变更：在 `migrations/` 下新增 `002_xxx.sql`（版本号递增），`npm run migrate` 即增量应用。

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
