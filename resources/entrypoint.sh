#!/bin/sh

tar -xf /usr/src/phpPgAdmin.tar.gz -C . --exclude-from=/usr/src/phpPgAdmin.exclude --strip-components=1
ln -fs /etc/phppgadmin/config.inc.php /usr/local/phppgadmin/conf/config.inc.php

sed -i "s/\[www\]/\[$PHP_FPM_POOL\]/g" /usr/local/etc/php-fpm.d/docker.conf
sed -i "s/\[www\]/\[$PHP_FPM_POOL\]/g" /usr/local/etc/php-fpm.d/www.conf

envsubst < "/usr/local/etc/php-fpm.conf.docker" > "/usr/local/etc/php-fpm.d/zz-docker.conf"

exec "$@"
