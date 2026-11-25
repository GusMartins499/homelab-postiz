#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR/env"
if [[ -e postiz.env || -e postgres.env || -e temporal.env ]]; then
  echo "env/*.env já existe; nada a fazer." >&2
  exit 1
fi
DB_PASS="$(openssl rand -hex 24)"
JWT="$(openssl rand -hex 48)"
umask 077
sed "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$DB_PASS/" postgres.env.example > postgres.env
sed "s/^POSTGRES_PWD=.*/POSTGRES_PWD=$DB_PASS/" temporal.env.example > temporal.env
sed -e "s/^JWT_SECRET=.*/JWT_SECRET=$JWT/" \
    -e "s#postiz:TROCAR@#postiz:$DB_PASS@#" postiz.env.example > postiz.env
echo "env/postgres.env, env/temporal.env e env/postiz.env gerados com segredos novos."
