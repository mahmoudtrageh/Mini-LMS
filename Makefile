.PHONY: install up down restart logs shell test fresh artisan tinker

# Build images and start all services
install:
	docker compose up --build -d

# Start services (no rebuild)
up:
	docker compose up -d

# Stop and remove containers
down:
	docker compose down

# Restart all services
restart:
	docker compose restart

# Tail logs (all services)
logs:
	docker compose logs -f

# Open a shell in the app container
shell:
	docker compose exec app bash

# Run Pest tests
test:
	docker compose exec app php artisan test

# Wipe database and re-run migrations + seeds
fresh:
	docker compose exec app php artisan migrate:fresh --seed

# Run an artisan command — usage: make artisan CMD="route:list"
artisan:
	docker compose exec app php artisan $(CMD)

# Open Tinker REPL
tinker:
	docker compose exec app php artisan tinker
