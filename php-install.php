#!/bin/bash

env=p # Production

# Include functions
. functions.cfg

usage() {
    echo "
        PHP Installation script

        $0 -- Installs and configures 1 or multipe versions of PHP

        USAGE:

            $0 [-sdv][-s site_name][-d env][-v version]

        OPTIONS:

            -s      Choose a website name using the pattern 'example.com'

            -d      (Optional) This will install for development use. Default: production

            -v      (Optional) Which version of PHP. Default: 7.0.0
    "
    exit 0
}

while getopts ":s:vdh" opt; do
    case $opt in
        s )
            site=$(echo $OPTARG | sed -E "s#([a-z0-9-]+).([a-z0-9]+)#\1-\2#")
            ;;
        d )
            env=d
            ;;
        v )
            version=$OPTARG
            ;;
        \? )
            error "-$OPTARG is not a valid option. Use '-h' for more options" 'warn'
            ;;
        : )
            error "-$OPTARG requires an argument" 'error'
            ;;

        *|h )
            usage
            ;;
    esac
done

shift $((OPTIND-1))

[[ -z "${site}" ]] &&
    error "No website name provided\n\tMissing: -s <example.com>" 'warn'

[[ -z "${version}" ]] &&
    version=7.0.0

[[ "$version" < "7.0.0" ]] &&
    php=php5 || php=php7

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

mkdir -p /usr/local/src/${php}-build/${php}
# Just here to make the installation quicker - DELETE WHEN NOT NEEDED
cp -apv php-src /usr/local/src/${php}-build/${php}
cd /usr/local/src/${php}-build/${php} || exit 1

if [ -d "/usr/local/src/${php}-build/${php}/php-src" ]
then
    cd /usr/local/src/${php}-build/${php}/php-src || exit 1
    git checkout PHP-${version}
else
    git clone https://github.com/php/php-src.git
    cd /usr/local/src/${php}-build/${php}/php-src || exit 1
    git checkout PHP-${version}
fi

mkdir -p /etc/php/${php}/conf.d
mkdir -p /etc/php/${php}/fpm/conf.d

./buildconf --force

CONFIGURE_STRING="
                --prefix=/etc/php/${php} \
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
                --with-pear=/etc/php/${php}/lib \
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
cp /usr/local/src/${php}-build/${php}/php-src/php.ini-production /etc/php/${php}/lib/php.ini
cp /etc/php/${php}/etc/php-fpm.conf.default /etc/php/${php}/etc/php-fpm.conf
cp /etc/php/${php}/etc/php-fpm.d/www.conf.default /etc/php/${php}/etc/php-fpm.d/${site}.conf

# Copy the init scripts from source to build and make executable
cp /usr/local/src/${php}-build/${php}/php-src/sapi/fpm/init.d.php-fpm /etc/init.d/${php}-fpm
chmod 755 /etc/init.d/${php}-fpm
update-rc.d ${php}-fpm defaults

# Create the logs
mkdir -p /var/log/php
touch /var/log/php/{${php}-fpm.log,${site}.log.slow}

# Amend some config settings
sed -i "s#;error_log = log/php-fpm.log#error_log = /var/log/php/${php}-fpm.log#" /etc/php/${php}/etc/php-fpm.conf
sed -i "s#;emergency_restart_threshold = 0#emergency_restart_threshold = 10#" /etc/php/${php}/etc/php-fpm.conf
sed -i "s#;emergency_restart_interval = 0#emergency_restart_interval = 1m#" /etc/php/${php}/etc/php-fpm.conf
sed -i "s#;process_control_timeout = 0#process_control_timeout = 5#" /etc/php/${php}/etc/php-fpm.conf
sed -i "s#;daemonize = yes#daemonize = yes#" /etc/php/${php}/etc/php-fpm.conf
# Amend the PHP-FPM config
sed -i "s#\[www\]#[${site}]#" /etc/php/${php}/etc/php-fpm.d/${site}.conf
sed -i "s#;user = root#user = vagrant#" /etc/php/${php}/etc/php-fpm.d/${site}.conf
sed -i "s#;group = root#group = vagrant#" /etc/php/${php}/etc/php-fpm.d/${site}.conf
sed -i "s#;listen.owner = vagrant#listen.owner = vagrant#" /etc/php/${php}/etc/php-fpm.d/${site}.conf
sed -i "s#;listen.group = vagrant#listen.group = vagrant#" /etc/php/${php}/etc/php-fpm.d/${site}.conf
sed -i "s#listen = 127.0.0.1:9000#listen = /var/run/${php}-fpm.sock#" /etc/php/${php}/etc/php-fpm.d/${site}.conf
sed -i "s#pm.max_children = 5#pm.max_children = 6#" /etc/php/${php}/etc/php-fpm.d/${site}.conf
sed -i "s#pm.start_servers = 2#pm.start_servers = 3#" /etc/php/${php}/etc/php-fpm.d/${site}.conf
sed -i "s#pm.min_spare_servers = 1#pm.min_spare_servers = 3#" /etc/php/${php}/etc/php-fpm.d/${site}.conf
sed -i "s#pm.max_spare_servers = 3#pm.max_spare_servers = 5#" /etc/php/${php}/etc/php-fpm.d/${site}.conf
sed -i "s#;pm.status_path = /status#pm.status_path = /fpm-status-zwei#" /etc/php/${php}/etc/php-fpm.d/${site}.conf
sed -i "s#;ping.path = /ping#ping.path = /ping-zwei#" /etc/php/${php}/etc/php-fpm.d/${site}.conf
sed -i "s#;request_terminate_timeout = 0#request_terminate_timeout = 120s#" /etc/php/${php}/etc/php-fpm.d/${site}.conf
sed -i "s#;rlimit_files = 1024#rlimit_files = 4096#" /etc/php/${php}/etc/php-fpm.d/${site}.conf
sed -i "s#;slowlog = log/\$pool.log.slow#slowlog = /var/log/php/\$pool.log.slow#" /etc/php/${php}/etc/php-fpm.d/${site}.conf
sed -i "s#;request_slowlog_timeout = 0#request_slowlog_timeout = 5s#" /etc/php/${php}/etc/php-fpm.d/${site}.conf
# Need to change the sock path in an NGINX config - outside of this script
site=$(echo ${site} | sed -E "s#([a-z0-9-]+)-([a-z0-9]+)#\1.\2#")
sed -i "s#fastcgi_pass unix:/var/run/php-fpm.sock;#fastcgi_pass unix:/var/run/${php}-fpm.sock;#" /etc/nginx/sites-available/${site}

# Use an external script to fix the php.ini and make it more secure
git clone https://github.com/perusio/php-ini-cleanup.git /etc/php/${php}/lib/php-ini-cleanup
cp -ap /etc/php/${php}/lib/php.ini{,.bak} # Backup just in case
/etc/php/${php}/lib/php-ini-cleanup/php_cleanup -${env} /etc/php/${php}/lib/php.ini

# Enable OPCACHE
echo "zend_extension=opcache.so" >> /etc/php/${php}/lib/php.ini

HOME=$(cd ~ || exit 1; pwd)
PATH=$PATH:/etc/php/${php}/bin
echo 'export PATH="$PATH:/etc/php/'${php}'/bin"' >> $HOME/.zshrc
source $HOME/.zshrc

service ${php}-fpm start
