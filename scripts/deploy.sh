#!/bin/bash
# Rolling update script — updates each service one at a time.
# New container must pass its health check within TIMEOUT seconds
# before the old one is stopped. On failure, old container is left running.

set -euo pipefail

TIMEOUT=60
SERVICES=("api" "frontend" "worker")

rolling_update() {
  local service=$1
  echo ""
  echo "=== Rolling update: $service ==="

  # Record the current (old) container ID
  OLD_ID=$(docker compose ps -q "$service" 2>/dev/null | head -1 || echo "")
  echo "  Old container: ${OLD_ID:-none}"

  # Get the image, network, and env from the running container
  if [ -n "$OLD_ID" ]; then
    NETWORK=$(docker inspect "$OLD_ID" \
      --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' \
      2>/dev/null | head -1)
    IMAGE=$(docker inspect "$OLD_ID" --format '{{.Config.Image}}' 2>/dev/null)
  else
    echo "  No old container found — starting fresh."
    docker compose up -d --no-deps "$service"
    return 0
  fi

  # Re-build the new image
  docker compose build --quiet "$service"
  NEW_IMAGE=$(docker compose config --format json 2>/dev/null | \
    python3 -c "import sys,json; d=json.load(sys.stdin); \
      img=d['services'].get('${service}',{}).get('image',''); print(img)" || echo "")

  [ -z "$NEW_IMAGE" ] && NEW_IMAGE="$IMAGE"

  # Start a temporary new container on the same network
  TEMP_NAME="deploy_${service}_$(date +%s)"
  ENV_ARGS=$(docker inspect "$OLD_ID" \
    --format '{{range .Config.Env}}-e "{{.}}" {{end}}' 2>/dev/null)

  echo "  Starting new container: $TEMP_NAME"
  eval docker run -d \
    --name "$TEMP_NAME" \
    --network "$NETWORK" \
    $ENV_ARGS \
    "$NEW_IMAGE" || {
    echo "  ERROR: Failed to start new container for $service"
    return 1
  }

  # Poll health check for up to TIMEOUT seconds
  local elapsed=0
  while [ $elapsed -lt $TIMEOUT ]; do
    HEALTH=$(docker inspect \
      --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
      "$TEMP_NAME" 2>/dev/null || echo "unknown")
    echo "  [$elapsed/${TIMEOUT}s] Health: $HEALTH"

    if [ "$HEALTH" = "healthy" ]; then
      echo "  New container is healthy! Swapping..."

      # Stop old, remove temp, restart service cleanly via compose
      docker stop "$OLD_ID" 2>/dev/null && docker rm "$OLD_ID" 2>/dev/null || true
      docker stop "$TEMP_NAME" 2>/dev/null && docker rm "$TEMP_NAME" 2>/dev/null || true
      docker compose up -d --no-deps "$service"

      echo "  Rolling update complete for $service!"
      return 0
    fi

    sleep 5
    elapsed=$((elapsed + 5))
  done

  # Health check timed out — abort, leave old container running
  echo "  ERROR: $service did not become healthy within ${TIMEOUT}s. Aborting."
  echo "  Old container ($OLD_ID) remains running."
  docker stop "$TEMP_NAME" 2>/dev/null && docker rm "$TEMP_NAME" 2>/dev/null || true
  return 1
}

for svc in "${SERVICES[@]}"; do
  rolling_update "$svc"
done

echo ""
echo "=== All services updated successfully ==="
