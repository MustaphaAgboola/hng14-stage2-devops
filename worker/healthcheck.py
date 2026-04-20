import redis
import os
import sys

try:
    r = redis.Redis(
        host=os.getenv("REDIS_HOST", "redis"),
        port=int(os.getenv("REDIS_PORT", 6379)),
        password=os.getenv("REDIS_PASSWORD"),
    )
    r.ping()
    sys.exit(0)
except Exception:
    sys.exit(1)
