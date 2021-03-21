FROM php:7.4.16-fpm

MAINTAINER Marek Miernik <miernikmarek@gmail.com>

WORKDIR /opt/app/

ENV USER_LOGIN    www-data
ENV USER_HOME_DIR /home/$USER_LOGIN
ENV APP_DIR       /opt/app

############ PHP-FPM ############
# CREATE WWW-DATA HOME DIRECTORY
RUN set -x \
    && mkdir /home/www-data \
    && chown -R www-data:www-data /home/www-data \
    && usermod -u 1000 --shell /bin/bash -d /home/www-data www-data \
    && groupmod -g 1000 www-data

# INSTALL ESSENTIALS LIBS TO COMPILE PHP EXTENSTIONS
RUN set -x \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y \
        # for zip ext
        zlib1g-dev libzip-dev\
        # for pg_pgsql ext
        libpq-dev \
        # for soap and xml related ext
        libxml2-dev \
        # for xslt ext
        libxslt-dev \
        # for gd ext
        libjpeg-dev libpng-dev \
        # for intl ext
        libicu-dev openssl \
        # for mbstring ext
        libonig-dev \
        # openssl
        libssl-dev \
        # htop for resource monitoring
        htop \
        # for pkill
        procps \
        vim iputils-ping curl iproute2 \
        #
        supervisor \
        cron \
        # for rabbit-query
        librabbitmq-dev

# INSTALL PHP EXTENSIONS VIA docker-php-ext-install SCRIPT
RUN docker-php-ext-install \
  bcmath \
  calendar \
  ctype \
  dba \
  dom \
  exif \
  fileinfo \
  ftp \
  gettext \
  gd \
  iconv \
  intl \
  mbstring \
  opcache \
  pcntl \
  pdo \
  pdo_pgsql \
  pdo_mysql \
  posix \
  session \
  simplexml \
  soap \
  sockets \
  xsl \
  zip

COPY scripts/xoff.sh /usr/bin/xoff
COPY scripts/xon.sh /usr/bin/xon

# INSTALL XDEBUG
RUN set -x \
    && pecl install xdebug \
    && bash -c 'echo -e "\n[xdebug]\nzend_extension=xdebug.so\nxdebug.remote_enable=1\nxdebug.remote_connect_back=0\nxdebug.remote_autostart=1\nxdebug.remote_port=9000\nxdebug.remote_host=" >> /usr/local/etc/php/conf.d/xdebug.ini' \
    # Add global functions for turn on/off xdebug
    && chmod +x /usr/bin/xoff \
    && chmod +x /usr/bin/xon \
    # turn off xdebug as default
    && mv /usr/local/etc/php/conf.d/xdebug.ini /usr/local/etc/php/conf.d/xdebug.off  \
    && echo 'PS1="[\$(test -e /usr/local/etc/php/conf.d/xdebug.off && echo XOFF || echo XON)] $HC$FYEL[ $FBLE${debian_chroot:+($debian_chroot)}\u$FYEL: $FBLE\w $FYEL]\\$ $RS"' | tee /etc/bash.bashrc /etc/skel/.bashrc

RUN set -x \
    && pecl install amqp \
    && docker-php-ext-enable amqp

# INSTALL COMPOSER
ENV COMPOSER_HOME /usr/local/composer
# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER 1
RUN set -x \
    && php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php composer-setup.php --install-dir=/usr/bin --filename=composer \
    && rm composer-setup.php \
    && bash -c 'echo -e "{ \"config\" : { \"bin-dir\" : \"/usr/local/bin\" } }\n" > /usr/local/composer/composer.json' \
    && echo "export COMPOSER_HOME=/usr/local/composer" >> /etc/bash.bashrc

############ NGINX ############
## INSTALL NGINX (based on the official nginx image)
RUN set -x \
  && apt-get update \
  && apt-get install --no-install-recommends --no-install-suggests -y gnupg1 apt-transport-https ca-certificates \
  && NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62; \
  found=''; \
  for server in \
    ha.pool.sks-keyservers.net \
    hkp://keyserver.ubuntu.com:80 \
    hkp://p80.pool.sks-keyservers.net:80 \
    pgp.mit.edu \
  ; do \
    echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
    apt-key adv --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$NGINX_GPGKEY" && found=yes && break; \
  done; \
  test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \
  echo "deb https://nginx.org/packages/mainline/debian/ stretch nginx" >> /etc/apt/sources.list.d/nginx.list \
  && apt-get update \
  && apt-get install --no-install-recommends --no-install-suggests -y \
      nginx=1.17.9-1~stretch \
      gettext-base \
  && apt-get clean \
  && apt-get autoremove \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log \
  && sed -i "s/^user .*/user www-data;/" /etc/nginx/nginx.conf

# install dockerize - useful tool to check if other sevices are ready to use (eg. db, queue)
RUN set -x \
    && DOCKERIZE_VERSION=v0.6.1; \
       curl https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz -L --output dockerize.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize.tar.gz \
    && rm dockerize.tar.gz

# COPY HTTP SERVER CONFIGURATION
COPY conf.d/nginx-default.conf /etc/nginx/conf.d/default.conf

RUN set -x \
   && bash -c 'echo "alias sf=bin/console" >> ~/.bashrc'

EXPOSE 8080

STOPSIGNAL SIGTERM