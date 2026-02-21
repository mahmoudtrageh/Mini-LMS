# Mini LMS

A Laravel 12 Learning Management System with Livewire v3, Filament v3, Alpine.js, and Plyr.js — fully containerised with Docker.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or Docker Engine + Compose v2)

No local PHP, Composer, or Node.js required.

## Quick Start

```bash
docker compose up --build
```

The first boot installs Laravel, all packages, and builds frontend assets (~3–5 min). Subsequent starts take a few seconds.

Once running, visit:

| URL | Description |
|-----|-------------|
| http://localhost:8000 | Laravel application |
| http://localhost:8000/admin | Filament admin panel |

## Available Commands

| Command | Description |
|---------|-------------|
| `make install` | Build images and start all services |
| `make up` | Start services (no rebuild) |
| `make down` | Stop and remove containers |
| `make restart` | Restart all services |
| `make logs` | Tail logs from all services |
| `make shell` | Open a bash shell in the app container |
| `make test` | Run Pest test suite |
| `make fresh` | Wipe DB and re-run migrations + seeds |
| `make artisan CMD="..."` | Run any artisan command |
| `make tinker` | Open Laravel Tinker REPL |

## Services & Ports

| Service | Image | Port | Role |
|---------|-------|------|------|
| `app` | Custom PHP 8.3-FPM | 9000 (internal) | Laravel PHP-FPM |
| `web` | nginx:1.25-alpine | **8000** → 80 | Reverse proxy |
| `db` | mysql:8.0 | 3306 | MySQL database |
| `queue` | Custom PHP 8.3-FPM | — | Queue worker (Redis) |
| `redis` | redis:7-alpine | 6379 | Cache / sessions / queues |

## Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | Laravel 12 |
| UI Components | Livewire v3 |
| JS interactivity | Alpine.js |
| Admin panel | Filament v3 |
| CSS | Tailwind CSS v3 |
| Video player | Plyr.js |
| Testing | Pest v2 |
| Database | MySQL 8.0 |
| Cache / Queue | Redis 7 |
| PHP | 8.3-FPM |

## Running Tests

```bash
# Via Make
make test

# Directly
docker compose exec app php artisan test

# With coverage
docker compose exec app php artisan test --coverage
```

## Queue Worker

The `queue` container runs automatically and processes jobs from the Redis queue. View its logs:

```bash
docker compose logs -f queue
```

## Environment

Copy `.env.docker` to `.env` to customise environment variables (the entrypoint does this automatically on first boot). Key variables:

```env
DB_HOST=db
REDIS_HOST=redis
QUEUE_CONNECTION=redis
CACHE_DRIVER=redis
SESSION_DRIVER=redis
```
