## Tech Stack

Laravel 11/12

Livewire v3

Alpine.js

Filament v3

Pest

MySQL

Plyr.js

Docker + Docker Compose (Required)

## docker

Required services

app (PHP-FPM or Laravel container)

web (Nginx or Apache)

db (MySQL)

queue worker (separate container OR same image different command)

(Optional bonus) redis for queue/cache

## Must-have DX
docker-compose.yml at repo root

One-command start:

docker compose up --build

Documented bootstrap script/commands in README:

install deps

migrations + seeds

queue worker

run tests

✅ The reviewer should be able to run the full project on a clean machine using Docker only.