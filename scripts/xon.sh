#!/bin/bash
# usage: xon remote_host remote_port
# or just: xon (then remote host will be taken from host and remote port will be default 9000)

HOST_IP=$([ -n "$1" ] && echo $1 || /sbin/ip route|awk '/default/ { print $3 }')
HOST_PORT=$([ -n "$2" ] && echo $2 || echo 9000)

mv /usr/local/etc/php/conf.d/xdebug.off /usr/local/etc/php/conf.d/xdebug.ini

sed -i "s|xdebug.remote_host=.*|xdebug.remote_host=$HOST_IP|" $PHP_INI_DIR/conf.d/xdebug.ini
sed -i "s|xdebug.remote_port=.*|xdebug.remote_port=$HOST_PORT|" $PHP_INI_DIR/conf.d/xdebug.ini

pkill -o -USR2 php-fpm