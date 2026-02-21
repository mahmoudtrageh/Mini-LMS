#!/bin/bash
set -e

WORKDIR=/var/www/html
READY_FLAG="$WORKDIR/.docker-ready"

echo "==> Container role: ${CONTAINER_ROLE:-app}"

# ── Queue role: wait for app to finish bootstrapping first ────────────────────
if [ "${CONTAINER_ROLE}" = "queue" ]; then
    echo "==> Waiting for app container to finish bootstrapping..."
    until [ -f "$READY_FLAG" ]; do
        sleep 3
    done
    echo "==> App is ready. Starting queue worker..."
    cd "$WORKDIR"
    exec php artisan queue:work redis \
        --sleep=3 \
        --tries=3 \
        --max-time=3600 \
        --verbose
fi

# ── First-run: create Laravel project ────────────────────────────────────────
if [ ! -f "$WORKDIR/artisan" ]; then
    echo "==> First run detected — creating Laravel project..."
    # composer create-project requires an empty target dir, so use a temp location
    # then move files into the (possibly non-empty) workdir, skipping existing files.
    TMPDIR=$(mktemp -d)
    composer create-project laravel/laravel "$TMPDIR" --prefer-dist --no-interaction
    # Move everything from temp into workdir; don't overwrite files that already exist
    # (e.g. Dockerfile, README.md, docker/ that were mounted via volume)
    cp -rn "$TMPDIR"/. "$WORKDIR"/
    rm -rf "$TMPDIR"
fi

cd "$WORKDIR"

# ── Patch Vite config for Tailwind v3 (Filament v3 incompatible with v4) ─────
# Laravel 12 ships @tailwindcss/vite (v4 plugin); we need the PostCSS approach.
if grep -q "@tailwindcss/vite" vite.config.js 2>/dev/null; then
    echo "==> Patching vite.config.js for Tailwind v3..."
    cat > vite.config.js << 'VITEEOF'
import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';

export default defineConfig({
    plugins: [
        laravel({
            input: ['resources/css/app.css', 'resources/js/app.js'],
            refresh: true,
        }),
    ],
    server: {
        watch: {
            ignored: ['**/storage/framework/views/**'],
        },
    },
});
VITEEOF
fi

# Patch app.css from Tailwind v4 @import syntax to v3 directives
# Use grep -F for fixed-string matching to avoid regex issues
if grep -qF "@import" resources/css/app.css 2>/dev/null && grep -qF "tailwindcss" resources/css/app.css 2>/dev/null && ! grep -q "@tailwind base" resources/css/app.css 2>/dev/null; then
    echo "==> Patching resources/css/app.css for Tailwind v3..."
    printf '@tailwind base;\n@tailwind components;\n@tailwind utilities;\n' > resources/css/app.css
fi

# Patch package.json: remove @tailwindcss/vite (v4 plugin), ensure tailwindcss v3
if grep -qF "@tailwindcss/vite" package.json 2>/dev/null; then
    echo "==> Patching package.json to remove @tailwindcss/vite and pin Tailwind v3..."
    node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
delete pkg.devDependencies['@tailwindcss/vite'];
pkg.devDependencies['tailwindcss'] = '^3.4.0';
pkg.devDependencies['autoprefixer'] = '^10.4.0';
pkg.devDependencies['postcss'] = '^8.4.0';
if (!pkg.dependencies) pkg.dependencies = {};
pkg.dependencies['alpinejs'] = '^3.0.0';
pkg.dependencies['plyr'] = '^3.0.0';
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 4));
console.log('package.json patched');
"
    # Wipe node_modules and lock file so npm reinstalls with updated deps
    rm -rf node_modules package-lock.json
fi

# Ensure postcss.config.js exists for Tailwind v3
if [ ! -f "postcss.config.js" ]; then
    echo "==> Creating postcss.config.js..."
    cat > postcss.config.js << 'POSTCSSEOF'
export default {
    plugins: {
        tailwindcss: {},
        autoprefixer: {},
    },
};
POSTCSSEOF
fi

# Ensure tailwind.config.js exists for Tailwind v3
if [ ! -f "tailwind.config.js" ]; then
    echo "==> Creating tailwind.config.js..."
    cat > tailwind.config.js << 'TWEOF'
/** @type {import('tailwindcss').Config} */
export default {
    content: [
        './vendor/laravel/framework/src/Illuminate/Pagination/resources/views/*.blade.php',
        './storage/framework/views/*.php',
        './resources/**/*.blade.php',
        './resources/**/*.js',
        './resources/**/*.vue',
    ],
    theme: {
        extend: {},
    },
    plugins: [],
};
TWEOF
fi

# ── Composer dependencies ─────────────────────────────────────────────────────
if [ ! -d "$WORKDIR/vendor" ]; then
    echo "==> Installing Composer dependencies..."
    composer install --no-interaction --prefer-dist --optimize-autoloader
fi

# ── Environment file ──────────────────────────────────────────────────────────
# Always use our Docker .env unless one has already been customised
# (detect the default sqlite .env that Laravel's post-install script creates)
if [ ! -f "$WORKDIR/.env" ] || grep -q "DB_CONNECTION=sqlite" "$WORKDIR/.env" 2>/dev/null; then
    echo "==> Copying .env.docker → .env..."
    cp /var/www/.env.docker "$WORKDIR/.env"
fi
if ! grep -q "^APP_KEY=base64:" "$WORKDIR/.env" 2>/dev/null; then
    echo "==> Generating app key..."
    php artisan key:generate --force
fi

# ── Install Laravel packages (idempotent via composer.json check) ─────────────
if ! grep -q "livewire/livewire" composer.json; then
    echo "==> Installing Livewire v3..."
    composer require livewire/livewire:"^3.0" --no-interaction
fi

if ! grep -q "filament/filament" composer.json; then
    echo "==> Installing Filament v3..."
    composer require filament/filament:"^3.0" --no-interaction
    php artisan filament:install --panels --no-interaction || true
fi

if ! grep -q "pestphp/pest" composer.json; then
    echo "==> Installing Pest..."
    composer require pestphp/pest:"^2.0" pestphp/pest-plugin-laravel:"^2.0" --dev --no-interaction
    php artisan pest:install --no-interaction || true
fi

# ── Node / frontend assets ────────────────────────────────────────────────────
if [ ! -d "$WORKDIR/node_modules" ]; then
    echo "==> Installing npm dependencies..."
    npm install
fi

# Build assets if no manifest exists
if [ ! -f "$WORKDIR/public/build/manifest.json" ]; then
    echo "==> Building frontend assets..."
    npm run build
fi

# ── Wait for database ─────────────────────────────────────────────────────────
echo "==> Waiting for database..."
until mysqladmin ping -h"${DB_HOST:-db}" -u"${DB_USERNAME:-lms_user}" -p"${DB_PASSWORD:-lms_secret}" --skip-ssl --silent 2>/dev/null; do
    echo "    Database not ready — retrying in 3s..."
    sleep 3
done
echo "==> Database is ready."

# ── Fix storage & cache permissions (files may be created as root via volume) ─
chown -R www-data:www-data \
    "$WORKDIR/storage" \
    "$WORKDIR/bootstrap/cache"
chmod -R 775 \
    "$WORKDIR/storage" \
    "$WORKDIR/bootstrap/cache"

# ── Migrations ────────────────────────────────────────────────────────────────
echo "==> Running migrations..."
php artisan migrate --force

# ── Seeds (only if the users table is empty — avoids duplicate seed data) ─────
USERS=$(php artisan tinker --execute="echo \App\Models\User::count();" 2>/dev/null | tr -d '[:space:]' || echo "0")
if [ "$USERS" = "0" ]; then
    echo "==> Seeding database..."
    php artisan db:seed --force 2>/dev/null || true
fi

# ── Storage link ──────────────────────────────────────────────────────────────
php artisan storage:link --force 2>/dev/null || true

# ── Cache warm-up (clear first to ensure fresh values) ───────────────────────
php artisan config:clear
php artisan config:cache
php artisan route:cache
php artisan view:cache

# ── Start PHP-FPM ─────────────────────────────────────────────────────────────
echo "==> Starting PHP-FPM..."
touch "$READY_FLAG"
exec php-fpm
