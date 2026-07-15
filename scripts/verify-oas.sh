#!/usr/bin/env bash
set -euo pipefail

# Boots the MCManager binary, waits for it to come up, fetches /oas.json and
# validates it against the OpenAPI schema. Used by dev:test:oas and
# release:generate:oas in .gitlab-ci.yml - the /oas.json endpoint is only
# registered in DEBUG builds.
BINARY="${1:-.build/debug/MCManager}"
HOST="127.0.0.1"
PORT="8000"

"$BINARY" serve --hostname "$HOST" --port "$PORT" > server.log 2>&1 &
APP_PID=$!

ready=0
for i in $(seq 1 30); do
  if curl -sf "http://${HOST}:${PORT}/version" -o /dev/null; then
    ready=1
    break
  fi
  sleep 1
done

if [ "$ready" -ne 1 ]; then
  echo "Server failed to start"
  cat server.log
  kill "$APP_PID" 2>/dev/null || true
  exit 1
fi

curl -sf "http://${HOST}:${PORT}/oas.json" -o oas.json
openapi-spec-validator oas.json
kill "$APP_PID" 2>/dev/null || true
