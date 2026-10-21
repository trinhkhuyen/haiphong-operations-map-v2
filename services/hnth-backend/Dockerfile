FROM node:22-alpine

WORKDIR /app
RUN corepack enable

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY packages ./packages
COPY services/hnth-backend/package.json ./services/hnth-backend/package.json
RUN pnpm install --frozen-lockfile --filter @haiphong-ops/hnth-backend...

COPY services/hnth-backend/src ./services/hnth-backend/src
WORKDIR /app/services/hnth-backend
ENV NODE_ENV=production
EXPOSE 8788
CMD ["pnpm", "start"]

