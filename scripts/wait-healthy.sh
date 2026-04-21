#!/bin/bash
# Polls docker compose services until all are healthy or timeout is reached.
set -e

TIMEOUT=120
ELAPSED=0
SERVICES=(redis api worker frontend)

check_healthy() {
  for svc in "${SERVICES[@]}"; do
    id=$(docker compose ps -q "$svc" 2>/dev/null | head -1)
    [ -z "$id" ] && echo "$svc: not running" && return 1
    health=$(docker inspect --format='{{.State.Health.Status}}' "$id" 2>/dev/null)
    [ "$health" != "healthy" ] && echo "$svc: $health" && return 1
  done
  return 0
}

echo "Waiting for all services to be healthy (max ${TIMEOUT}s)..."

until check_healthy; do
  ELAPSED=$((ELAPSED + 5))
  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "ERROR: Timed out after ${TIMEOUT}s"
    docker compose ps
    exit 1
  fi
  sleep 5
done

echo "All services healthy!"
