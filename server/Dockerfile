# 景德镇艺术职业大学教务 App 后端 API —— 生产镜像
# 多阶段构建：deps 阶段只装生产依赖，runner 阶段最小化体积并以非 root 运行。

# ---- 依赖安装阶段 ----
FROM node:20-alpine AS deps
WORKDIR /app
# 仅复制依赖清单，利用 Docker 层缓存：package*.json 不变则跳过重新安装。
COPY package.json package-lock.json ./
# --omit=dev 只装生产依赖；ci 严格按 lock 文件还原，可重复构建。
RUN npm ci --omit=dev

# ---- 运行阶段 ----
FROM node:20-alpine AS runner
# dumb-init 作为 PID 1 正确转发信号（SIGTERM），让 docker stop 能优雅退出。
RUN apk add --no-cache dumb-init
ENV NODE_ENV=production
WORKDIR /app

# 复制已装好的生产依赖与应用源码。
COPY --from=deps /app/node_modules ./node_modules
COPY package.json package-lock.json ./
COPY src ./src
COPY migrations ./migrations
COPY public ./public
COPY assets ./assets
COPY migrate.js seed.js ./

# 上传目录（UPLOAD_DIR 默认指向 ../uploads，这里建在 /app/uploads 并授权）。
RUN mkdir -p /app/uploads && chown -R node:node /app

# 以内置非 root 用户 node 运行，降低容器逃逸风险。
USER node

EXPOSE 8090

# 容器内健康检查：命中裸 /health（本机直连，无需 nginx）。
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:'+(process.env.PORT||8090)+'/health',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "src/index.js"]
