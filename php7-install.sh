#!/bin/bash

# PHP 7

# Dependencies
apt-get update
apt-get build-dep php5
apt-get install -qqy \
    autoconf \
    bison \
    automake \
    libtool \
    pkg-config \
    build-essential

mkdir -p /usr/local/src/php7-build/php7

if [ -d "/usr/local/src/php7-build/php7/php-src" ]
then
    cd /usr/local/src/php7-build/php7/php-src
    git checkout PHP-7.0.2
    git pull
else
    git clone https://github.com/php/php-src.git
    cd /usr/local/src/php7-build/php7/php-src
    git checkout PHP-7.0.1
    git pull
fi

mkdir -p /etc/php/php7/conf.d
mkdir -p /etc/php/php7/fpm/conf.d

./buildconf --force

CONFIGURE_STRING="
                --prefix=/etc/php/php7 \
                --with-bz2 \
                --with-curl \
                --with-fpm-group=vagrant \
                --with-fpm-user=vagrant \
                --with-gettext \
                --with-gd \
                --with-iconv \
                --with-mcrypt \
                --with-mhash \
                --with-mysqli \
                --with-pdo-mysql \
                --with-openssl \
                --with-pspell \
                --with-readline \
                --with-zlib \
                --enable-bcmath \
                --enable-calendar \
                --enable-dba \
                --enable-exif \
                --enable-fpm
                --enable-ftp \
                --enable-mbstring \
                --enable-mysqlnd \
                --enable-pcntl \
                --enable-shmop \
                --enable-soap \
                --enable-sockets \
                --enable-sysvmsg \
                --enable-sysvsem \
                --enable-sysvshm \
                --enable-wddx \
                --enable-zip \
"

./configure $CONFIGURE_STRING

make --quiet
make install --quiet

# Move configuration files to new location
cp /usr/local/src/php7-build/php7/php-src/php.ini-production /etc/php/php7/lib/php.ini
cp /etc/php/php7/etc/php-fpm.conf.default /etc/php/php7/etc/php-fpm.conf
cp /etc/php/php7/etc/php-fpm.d/www.conf.default /etc/php/php7/etc/php-fpm.d/www.conf

# Copy the init scripts from source to build and make executable
cp /usr/local/src/php7-build/php7/php-src/sapi/fpm/init.d.php-fpm /etc/init.d/php7-fpm
chmod 755 /etc/init.d/php7-fpm
update-rc.d php7-fpm defaults

PATH=$PATH:/etc/php/php7/bin
echo 'export PATH="$PATH:/etc/php/php7/bin"' >> ~/.bashrc
source ~/.bashrc

service php7-fpm start
