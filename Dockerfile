FROM php:7.3.14-fpm-stretch

MAINTAINER eXo Platform <docker@exoplatform.com>

ENV FPM_STATUS_ENABLED=true
ENV FPM_PING_ENABLED=true
ENV FPM_PROCESS_MANAGER=dynamic
ENV FPM_MAX_CHILDREN=5
ENV FPM_START_CHILDREN=2
ENV FPM_MIN_SPARE_SERVERS=1
ENV FPM_MAX_SPARE_SERVERS=3

ARG WP_CLI_VERSION=2.4.0

# Install wp command line
RUN apt-get update && apt-get install -y less wget mysql-client sudo imagemagick libmagickwand-dev && rm -rf /var/lib/apt/ && \
  cd /tmp && wget -O wp-cli.phar https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar && \
  chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp && \
  docker-php-ext-install pdo_mysql && docker-php-ext-install mysqli && \
  pecl install imagick && \
  docker-php-ext-install gd

ENTRYPOINT /entrypoint.sh

ARG WORDPRESS_VERSION=5.7.2

RUN chown www-data:www-data /var/www/
USER www-data
RUN wp core download --version=${WORDPRESS_VERSION}
USER root

COPY entrypoint.sh /
RUN echo "extension=imagick.so" > /usr/local/etc/php/conf.d/imagick.ini
RUN chmod a+x /entrypoint.sh
