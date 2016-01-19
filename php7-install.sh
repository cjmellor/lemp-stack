#!/bin/bash

env=p

# Customer error message
error() {
    reset=$(tput sgr0)

    # Set colours
    if [ "$2" == 'warn' ]; then
        msg=$(tput setaf 1)WARNING${reset}
    elif [ "$2" == 'info' ]; then
        msg=$(tput setaf 2)INFO${reset}
    elif [ "$2" == 'error' ]; then
        msg=$(tput setaf 3)ERROR${reset}
    fi

    echo -e "
        ${msg}:
        =========================${reset}
        $1
    "
    exit 1
}

# Custom options/arguments
usage() {
    echo "
        PHP 7 Installation script

        $0 -- Installs and configures PHP 7 in almost one command

        USAGE:
            $0 [-sd][-s site_name][-d env]

        OPTIONS:

            -s      Choose a website name using the pattern 'example.com'

            -d      (Optional) This will install for development use. Default: production
    "
    exit 0
}

while getopts ":s:dh" opt; do
    case $opt in
        s)
            site=$(echo "${OPTARG}" | sed -E "s#([a-zA-Z0-9]+).([a-zA-Z0-9]+)#\1-\2#")
            ;;
        d)
            env=d
            ;;
        \?)
            error "-$OPTARG is not a valid option. Use '-h' for more options" 'warn'
            ;;
        :)
            error "-$OPTARG requires an argument" 'error'
            ;;

        *|h)
            usage
            ;;
    esac
done

shift $((OPTIND-1))

if [ -z "${site}" ]; then
    error "No website name provided\n\tMissing: -s <example.com>" 'warn'
fi

# Dependencies
apt-get update -y
apt-get install -y \
    autoconf \
    automake \
    bison \
    build-essential \
    libbz2-dev \
    libcurl4-openssl-dev \
    libicu-dev \
    libjpeg-dev \
    libltdl-dev \
    libmcrypt-dev \
    libpng-dev \
    libreadline-dev \
    libpspell-dev \
    libssl-dev \
    libtool \
    libxml2-dev \
    pkg-config

mkdir -p /usr/local/src/php7-build/php7
# Just here to make the installation quicker - DELETE WHEN NOT NEEDED
cp -ap php-src /usr/local/src/php7-build/php7
cd /usr/local/src/php7-build/php7 || exit 1

if [ -d "/usr/local/src/php7-build/php7/php-src" ]
then
    cd /usr/local/src/php7-build/php7/php-src || exit 1
    git checkout PHP-7.0.2
else
    git clone https://github.com/php/php-src.git
    cd /usr/local/src/php7-build/php7/php-src || exit 1
    git checkout PHP-7.0.2
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
                --enable-opcache \
                --enable-pcntl \
                --enable-shmop \
                --enable-soap \
                --enable-sockets \
                --enable-sysvmsg \
                --enable-sysvsem \
                --enable-sysvshm \
                --enable-wddx \
                --enable-zip
"

./configure $CONFIGURE_STRING

make # --quiet
make install # --quiet

# Move configuration files to new location
cp /usr/local/src/php7-build/php7/php-src/php.ini-production /etc/php/php7/lib/php.ini
cp /etc/php/php7/etc/php-fpm.conf.default /etc/php/php7/etc/php-fpm.conf
cp /etc/php/php7/etc/php-fpm.d/www.conf.default /etc/php/php7/etc/php-fpm.d/${site}.conf

# Copy the init scripts from source to build and make executable
cp /usr/local/src/php7-build/php7/php-src/sapi/fpm/init.d.php-fpm /etc/init.d/php7-fpm
chmod 755 /etc/init.d/php7-fpm
update-rc.d php7-fpm defaults

# Create the logs
mkdir -p /var/log/php
touch /var/log/php/{php-fpm.log,${site}.log.slow}

# Amend some config settings
sed -i "s#;error_log = log/php-fpm.log#error_log = /var/log/php/php-fpm.log#" /etc/php/php7/etc/php-fpm.conf
sed -i "s#;emergency_restart_threshold = 0#emergency_restart_threshold = 10#" /etc/php/php7/etc/php-fpm.conf
sed -i "s#;emergency_restart_interval = 0#emergency_restart_interval = 1m" /etc/php/php7/etc/php-fpm.conf
sed -i "s#;process_control_timeout = 0#process_control_timeout = 5#" /etc/php/php7/etc/php-fpm.conf
sed -i "s#;daemonize = yes#daemonize = yes#" /etc/php/php7/etc/php-fpm.conf
# Amend the PHP-FPM config
sed -i "s#[www]#[${site}]#" /etc/php/php7/etc/php-fpm.d/${site}.conf
sed -i "s#listen = 127.0.0.1:9000#listen = /var/run/php-fpm.sock#" /etc/php/php7/etc/php-fpm.d/${site}.conf
sed -i "s#pm.max_children = 5#pm.max_children = 6#" /etc/php/php7/etc/php-fpm.d/${site}.conf
sed -i "s#pm.start_servers = 2#pm.start_servers = 3#" /etc/php/php7/etc/php-fpm.d/${site}.conf
sed -i "s#pm.min_spare_servers = 1#pm.min_spare_servers = 3#" /etc/php/php7/etc/php-fpm.d/${site}.conf
sed -i "s#pm.max_spare_servers = 3#pm.max_spare_servers = 5#" /etc/php/php7/etc/php-fpm.d/${site}.conf
sed -i "s#;pm.status_path = /status#pm.status_path = /fpm-status-zwei#" /etc/php/php7/etc/php-fpm.d/${site}.conf
sed -i "s#;ping.path = /ping#ping.path = /ping-zwei#" /etc/php/php7/etc/php-fpm.d/${site}.conf
sed -i "s#;request_terminate_timeout = 0#request_terminate_timeout = 120s#" /etc/php/php7/etc/php-fpm.d/${site}.conf
sed -i "s#;rlimit_files = 1024#rlimit_files = 4096#" /etc/php/php7/etc/php-fpm.d/${site}.conf
sed -i "s#;slowlog = log/\$pool.log.slow#slowlog = /var/log/php/\$pool.log.slow#" /etc/php/php7/etc/php-fpm.d/${site}.conf
sed -i "s#;request_slowlog_timeout = 0#request_slowlog_timeout = 5s#" /etc/php/php7/etc/php-fpm.d/${site}.conf

# Use an external script to fix the php.ini and make it more secure
cd /etc/php/php7/lib || exit 1
git clone https://github.com/perusio/php-ini-cleanup.git
cp -ap /etc/php/php7/lib/php.ini{,.bak} # Backup just in case
/etc/php/php7/lib/php-ini-cleanup/php_cleanup -${env} /etc/php/php7/lib/php.ini

# Enable OPCACHE
echo "zend_extension=opcache.so" >> /etc/php/php7/lib/php.ini

HOME=$(cd ~ || exit 1; pwd)
PATH=$PATH:/etc/php/php7/bin
echo 'export PATH="$PATH:/etc/php/php7/bin"' >> $HOME/.bashrc
source $HOME.bashrc

service php7-fpm start
