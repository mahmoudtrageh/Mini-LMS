FROM php:8.3-fpm

# ── System dependencies ───────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    zip \
    unzip \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libicu-dev \
    libonig-dev \
    default-mysql-client \
    && rm -rf /var/lib/apt/lists/*

# ── Node.js 20 ────────────────────────────────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# ── PHP extensions ────────────────────────────────────────────────────────────
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        mbstring \
        exif \
        pcntl \
        bcmath \
        gd \
        zip \
        intl \
        opcache

# Redis extension via PECL
RUN pecl install redis && docker-php-ext-enable redis

# ── Composer ──────────────────────────────────────────────────────────────────
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# ── PHP config ────────────────────────────────────────────────────────────────
COPY docker/php/php.ini /usr/local/etc/php/conf.d/custom.ini

# ── Entrypoint ────────────────────────────────────────────────────────────────
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# ── App directory ─────────────────────────────────────────────────────────────
RUN mkdir -p /var/www/html \
    && chown -R www-data:www-data /var/www

# Copy env template (accessible before project is created)
COPY .env.docker /var/www/.env.docker

WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT ["/entrypoint.sh"]
