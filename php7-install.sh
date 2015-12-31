#!/bin/bash

# PHP 7

# Dependencies
apt-get update
apt-get install -qqy \
    autoconf \
    bison \
    libxml2-dev \
    libbz2-dev \
    libmcrypt-dev \
    libcurl4-openssl-dev \
    libltdl-dev \
    libpng-dev \
    libpspell-dev \
    libreadline-dev

mkdir -p /usr/local/src/php7-build/php7

if [ -d "/usr/local/src/php7-build/php7/php-src" ]
then
    cd /usr/local/src/php7-build/php7/php-src
    git checkout PHP-7.0.1
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

CONFIGURE_STRING="--prefix=/etc/php/php7 \
                  --enable-bcmath \
                  --with-bz2 \
                  --enable-calendar \
                  --enable-exif \
                  --enable-dba \
                  --enable-ftp \
                  --with-gettext \
                  --with-gd \
                  --enable-mbstring \
                  --with-mcrypt \
                  --with-mhash \
                  --enable-mysqlnd \
                  --with-mysqli \
                  --with-pdo-mysql \
                  --with-openssl \
                  --enable-pcntl \
                  --with-pspell \
                  --enable-shmop \
                  --enable-soap \
                  --enable-sockets \
                  --enable-sysvmsg \
                  --enable-sysvsem \
                  --enable-sysvshm \
                  --enable-wddx \
                  --with-zlib \
                  --enable-zip \
                  --with-readline \
                  --with-curl \
                  --enable-fpm \
                  --with-fpm-user=vagrant \
                  --with-fpm-group=vagrant"

./configure $CONFIGURE_STRING

make
make install

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
