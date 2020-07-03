FROM alpine:edge
FROM composer:1.6.5 as composer
LABEL Maintainer="Jarak Kritkiattisak <jarak.krit@gmail.com>" \
      Description="Lightweight container with Nginx 1.18 & PHP-FPM 7.2 based on Alpine Linux."

ADD https://dl.bintray.com/php-alpine/key/php-alpine.rsa.pub /etc/apk/keys/php-alpine.rsa.pub

RUN apk --update add ca-certificates && \
    apk upgrade 
    # echo "https://dl.bintray.com/php-alpine/v3.11/php-7.4" >> /etc/apk/repositories

# Install packages and remove default server definition
RUN apk --no-cache add php7 php7-cli php7-fpm php7-opcache php7-mysqli php7-json php7-openssl php7-curl \
    php7-zlib php7-xml php7-phar php7-intl php7-dom php7-xmlreader php7-ctype php7-session \
    php7-mbstring php7-gd nginx supervisor curl && \
    rm /etc/nginx/conf.d/default.conf
RUN apk add --no-cache php7-pear php7-dev autoconf gcc musl-dev make zlib zlib-dev
# RUN pecl install redis \
#     && pecl install memcache \
#     && docker-php-ext-enable redis

COPY --from=composer /usr/bin/composer /usr/bin/composer

# Run composer install to install the dependencies
# RUN composer install --optimize-autoloader --no-interaction --no-progress

# Configure nginx
COPY config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php7/php-fpm.d/www.conf
COPY config/php.ini /etc/php7/conf.d/custom.ini

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Setup document root
RUN mkdir -p /var/www/html

# Make sure files/folders needed by the processes are accessable when they run under the nobody user
RUN chown -R nobody.nobody /var/www/html && \
  chown -R nobody.nobody /run && \
  chown -R nobody.nobody /var/lib/nginx && \
  chown -R nobody.nobody /var/log/nginx
RUN apk --no-cache  add libpng-dev \
    imagemagick \
    libc-dev \
    libpng-dev \
    libzip-dev  \
    mariadb-client \
    php7-pdo \
    php7-pdo_mysql \
    php7-tokenizer
RUN docker-php-ext-configure gd
RUN docker-php-ext-install \
    bcmath \
    calendar \
    exif \
    gd \
    pdo_mysql \
    zip
RUN docker-php-ext-install mysqli

RUN apk --no-cache add php7-dev php7-xml php7-fileinfo autoconf automake libtool m4
RUN docker-php-ext-configure fileinfo
RUN docker-php-ext-install fileinfo
# Switch to use a non-root user from here on
USER nobody

# Add application
WORKDIR /var/www/html
COPY --chown=nobody src/ /var/www/html/

# Expose the port nginx is reachable on
EXPOSE 3000

# Let supervisord start nginx & php-fpm
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:9000/fpm-ping
