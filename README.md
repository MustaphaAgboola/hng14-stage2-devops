# HNG14 Stage 2 — Containerized Job Processing System

A production-ready, containerized microservices application consisting of a job queue system with a Node.js frontend, Python/FastAPI backend, Python worker, and Redis message broker.

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Internal Docker Network            │
│                                                     │
│  ┌──────────┐     ┌──────────┐     ┌────────────┐  │
│  │ Frontend │────▶│   API    │────▶│   Redis    │  │
│  │ :3000    │     │  :8000   │     │   :6379    │  │
│  └──────────┘     └──────────┘     └────────────┘  │
│                                          ▲          │
│                                    ┌─────┴──────┐   │
│                                    │   Worker   │   │
│                                    └────────────┘   │
└─────────────────────────────────────────────────────┘
```

**Job flow:** User submits via frontend → API creates job in Redis queue → Worker picks up job, processes it, marks as completed → Frontend polls and displays final status.

---

## Prerequisites

Make sure the following are installed on your machine:

| Tool | Version | Install |
|---|---|---|
| Docker | 24+ | https://docs.docker.com/get-docker/ |
| Docker Compose | v2+ | Included with Docker Desktop |
| Git | any | https://git-scm.com/ |

Verify your setup:
```bash
docker --version
docker compose version
git --version
```

---

## Quickstart (clean machine)

### 1. Clone the repository

```bash
git clone https://github.com/<your-username>/hng14-stage2-devops.git
cd hng14-stage2-devops
```

### 2. Create your environment file

Copy the example and set your own Redis password:

```bash
cp .env.example .env
```

Open `.env` and set a strong password:

```env
REDIS_PASSWORD=your_strong_password_here
APP_ENV=production
```

> **Never commit `.env` to git.** It is already blocked by `.gitignore`.

### 3. Build and start the full stack

```bash
docker compose up --build
```

This will:
- Build all three service images from source
- Start Redis, API, Worker, and Frontend in dependency order
- Each service waits for its dependency to be confirmed **healthy** before starting

---

## What a successful startup looks like

You will see output similar to this (services may interleave):

```
redis-1     | Ready to accept connections tcp
api-1       | INFO:     Application startup complete.
api-1       | INFO:     Uvicorn running on http://0.0.0.0:8000
worker-1    | (waiting silently for jobs)
frontend-1  | Frontend running on port 3000
```

Check that all four services are healthy:

```bash
docker compose ps
```

Expected output:

```
NAME          IMAGE        STATUS                   PORTS
redis-1       redis:7-...  Up (healthy)
api-1         api          Up (healthy)   0.0.0.0:8000->8000/tcp
worker-1      worker       Up (healthy)
frontend-1    frontend     Up (healthy)   0.0.0.0:3000->3000/tcp
```

All four services must show `(healthy)` — not just `Up`.

---

## Test the application

Open your browser and go to:

```
http://localhost:3000
```

1. Click **"Submit New Job"**
2. A job ID appears on screen with status `queued`
3. Within ~2 seconds the status updates to `completed`

You can also test via the API directly:

```bash
# Submit a job
curl -X POST http://localhost:8000/jobs

# Check job status (replace JOB_ID)
curl http://localhost:8000/jobs/JOB_ID

# API health check
curl http://localhost:8000/health
```

---

## Stop the stack

```bash
docker compose down
```

To also remove volumes (clears Redis data):

```bash
docker compose down -v
```

---

## CI/CD Pipeline

The pipeline runs automatically on every push and pull request via GitHub Actions.

### Stages (run in strict order)

| Stage | What it does |
|---|---|
| **lint** | flake8 (Python), eslint (JavaScript), hadolint (Dockerfiles) |
| **test** | 6 pytest unit tests with Redis mocked; coverage report uploaded as artifact |
| **build** | Builds all 3 images, tags with git SHA + `latest`, pushes to local registry |
| **security-scan** | Trivy scans all images; fails pipeline on any CRITICAL finding; uploads SARIF |
| **integration-test** | Full stack starts inside runner, job submitted, completion asserted, stack torn down |
| **deploy** | Rolling update (main branch only) — 60s health check timeout before swapping containers |

A failure in any stage stops all subsequent stages.

### Required GitHub Secret

For the deploy stage to work, add this secret to your repository:

| Secret | Value |
|---|---|
| `REDIS_PASSWORD` | A strong password for Redis |

Go to: **Repository → Settings → Secrets and variables → Actions → New repository secret**

---

## Project Structure

```
.
├── api/                    # FastAPI backend
│   ├── main.py             # Job creation and status endpoints
│   ├── requirements.txt    # Production dependencies (pinned)
│   ├── requirements-dev.txt# Test dependencies
│   ├── Dockerfile          # Multi-stage, non-root, health-checked
│   └── tests/
│       └── test_main.py    # 6 unit tests (Redis mocked)
├── worker/                 # Background job processor
│   ├── worker.py           # Polls Redis queue, processes jobs
│   ├── healthcheck.py      # Pings Redis (used by HEALTHCHECK)
│   ├── requirements.txt    # Pinned dependencies
│   └── Dockerfile          # Multi-stage, non-root, health-checked
├── frontend/               # Express.js web dashboard
│   ├── app.js              # Proxies requests to API
│   ├── views/index.html    # Job submission UI
│   ├── package.json        # Dependencies + eslint dev dep
│   └── Dockerfile          # Multi-stage, non-root, health-checked
├── scripts/
│   └── deploy.sh           # Rolling update script
├── .github/workflows/
│   └── ci.yml              # Full CI/CD pipeline
├── docker-compose.yml      # Full stack orchestration
├── .env.example            # Template for required env vars
├── FIXES.md                # All bugs found and fixed
└── README.md               # This file
```

---

## Environment Variables

All configuration is injected at runtime via environment variables. See `.env.example` for the full list.

| Variable | Used by | Description |
|---|---|---|
| `REDIS_PASSWORD` | api, worker, redis | Redis authentication password |
| `REDIS_HOST` | api, worker | Redis hostname (default: `redis`) |
| `REDIS_PORT` | api, worker | Redis port (default: `6379`) |
| `APP_ENV` | api | Environment name (`production`/`test`) |
| `API_URL` | frontend | API base URL (default: `http://api:8000`) |
