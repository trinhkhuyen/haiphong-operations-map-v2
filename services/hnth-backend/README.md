# HNTH Backend

Backend production-oriented for the HNTH map. It is intentionally separated from the existing relay so migration can be tested locally without losing the current workflow.

## Local

```powershell
docker compose -f docker-compose.local.yml up -d postgres
pnpm install
pnpm --filter @haiphong-ops/hnth-backend start
```

Default API port: `8788`.

## Environment

```text
PORT=8788
DATABASE_URL=postgres://hnth:hnth_local_password@127.0.0.1:5432/hnth
JWT_SECRET=replace-this-local-secret
ADMIN_USERNAME=admin
ADMIN_PASSWORD=change-this-local-password
```
