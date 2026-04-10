FROM php:8.2-fpm-alpine3.23

LABEL org.opencontainers.image.url="https://github.com/misotolar/docker-phppgadmin"
LABEL org.opencontainers.image.description="phpPgAdmin Alpine Linux FPM image"
LABEL org.opencontainers.image.authors="Michal Sotolar <michal@sotolar.com>"

ENV PHPPGADMIN_VERSION=7.14.7-mod
ARG SHA256=7c0e89922abcf88fd81a52590930f3b5121032d1d37234a54a8f6415152dc292
ADD https://github.com/ReimuHakurei/phpPgAdmin/archive/refs/tags/v$PHPPGADMIN_VERSION.tar.gz /usr/src/phpPgAdmin.tar.gz

ENV HEALTHCHECK_VERSION=0.6.0
ARG HEALTHCHECK_SHA256=53bc616c4a30f029b98bff48fdeb0c4da252cb11e4f86656a8222a67dc4e5009
ADD https://raw.githubusercontent.com/renatomefi/php-fpm-healthcheck/refs/tags/v$HEALTHCHECK_VERSION/php-fpm-healthcheck /usr/local/bin/healthcheck

ENV TZ=UTC
ENV PHP_FPM_POOL=www
ENV PHP_FPM_LISTEN=0.0.0.0:9000
ENV PHP_MAX_EXECUTION_TIME=600
ENV PHP_MEMORY_LIMIT=512M
ENV PHP_UPLOAD_LIMIT=2048K

WORKDIR /usr/local/phppgadmin

RUN set -ex; \
    apk add --no-cache \
        fcgi \
        gettext-envsubst \
    ; \
    apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        postgresql-dev \
    ; \
    docker-php-ext-install \
        opcache \
        pgsql \
    ; \
    runDeps="$( \
        scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
            | tr ',' '\n' \
            | sort -u \
            | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )"; \
    apk add --no-cache --virtual .phppgadmin-rundeps $runDeps; \
    apk del --no-network .build-deps; \
    { \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=4000'; \
        echo 'opcache.revalidate_freq=2'; \
        echo 'opcache.fast_shutdown=1'; \
    } > $PHP_INI_DIR/conf.d/opcache-recommended.ini; \
    \
    { \
        echo 'session.cookie_httponly=1'; \
        echo 'session.use_strict_mode=1'; \
    } > $PHP_INI_DIR/conf.d/session-strict.ini; \
    \
    { \
        echo 'expose_php=off'; \
        echo 'allow_url_fopen=off'; \
        echo 'date.timezone=${TZ}'; \
        echo 'max_input_vars=10000'; \
        echo 'memory_limit=${PHP_MEMORY_LIMIT}'; \
        echo 'post_max_size=${PHP_UPLOAD_LIMIT}'; \
        echo 'upload_max_filesize=${PHP_UPLOAD_LIMIT}'; \
        echo 'max_execution_time=${PHP_MAX_EXECUTION_TIME}'; \
    } > $PHP_INI_DIR/conf.d/phppgadmin-misc.ini; \
    echo "$SHA256 */usr/src/phpPgAdmin.tar.gz" | sha256sum -c -; \
    echo "$HEALTHCHECK_SHA256 */usr/local/bin/healthcheck" | sha256sum -c -; \
    chmod 755 /usr/local/bin/healthcheck; \
    rm -rf \
        /usr/src/php.tar.xz \
        /usr/src/php.tar.xz.asc \
        /var/cache/apk/* \
        /var/tmp/* \
        /tmp/*

COPY resources/php-fpm.conf /usr/local/etc/php-fpm.conf.docker
COPY resources/config.inc.php /etc/phppgadmin/config.inc.php
COPY resources/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY resources/exclude.txt /usr/src/phpPgAdmin.exclude

VOLUME /usr/local/phppgadmin

HEALTHCHECK --start-interval=60s --start-period=300s --interval=5s \
    CMD FCGI_CONNECT=${PHP_FPM_LISTEN} FCGI_STATUS_PATH=${PHP_FPM_STATUS_PATH} /usr/local/bin/healthcheck

ENTRYPOINT ["entrypoint.sh"]
CMD ["php-fpm"]

