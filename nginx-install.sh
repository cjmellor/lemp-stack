#!/bin/bash

rm -rf nginx_ensite # DEBUGGING ONLY!

branch=stable
secure=example.com

# Include functions
. functions.cfg

# Custom options/arguments
usage() {
    echo "
        NGINX Installation script

        $0 -- Installs and configures NGINX in almost one command

        USAGE:
            $0 [-bst][-b branch_version][-s site_name][-t secure]

        OPTIONS:

            -b      (Optional) This option selects the 'development' build. Default: stable

            -s      Choose a website name using the pattern 'example.com'

            -t      (Optional) Choose if to use this for SSL sites. Default: Non-SSL
    "
    exit 0
}

while getopts ":bs:ht" opt; do
    case $opt in
        b )
            branch=development
            ;;
        s )
            site=${OPTARG}
            ;;
        t )
            secure=ssl.example.com
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

# Download the NGINX vhost enabler
git clone https://github.com/perusio/nginx_ensite.git
cd nginx_ensite || exit 1
make install
cd ../ || exit 1
rm -rf nginx_ensite

# Add NGINX key
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C300EE8C

# Add the NGINX repository
touch /etc/apt/sources.list.d/nginx-$branch-trusty.list
chown vagrant: /etc/apt/sources.list.d/nginx-$branch-trusty.list

cat << EOF > /etc/apt/sources.list.d/nginx-$branch-trusty.list
deb http://ppa.launchpad.net/nginx/$branch/ubuntu trusty main
EOF

# Update and Install NGINX
apt-get update
apt-get install -y nginx

cp -r nginx-config/{extra,mime.types,nginx.conf} /etc/nginx/
cp -r nginx-config/sites-available/${secure} /etc/nginx/sites-available/
touch /var/log/nginx/static.log
chown vagrant: /var/log/nginx/{error.log,access.log,static.log}

# Remove the default sites and add new sites
rm /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
mv /etc/nginx/sites-available/${secure} /etc/nginx/sites-available/"${site}"
nginx_ensite "${site}"
chown -R vagrant: /var/www
mkdir -p /var/www/"${site}"/html

# Create a PHP Info to show it's working
cat << EOF > /var/www/${site}/html/index.php
<?php
phpinfo();
EOF

########## CONFIGURATION ##########

# Change the user to run NGINX
sed -i "s#user www-data;#user vagrant;#" /etc/nginx/nginx.conf
sed -i "s#${secure}#${site}#g" /etc/nginx/sites-available/"${site}"
sed -i "s#worker_processes auto;#worker_processes $(cat /proc/cpuinfo | grep -c processor);#" /etc/nginx/nginx.conf
sed -i "s#worker_connections 8000;#worker_connections 1024;#" /etc/nginx/nginx.conf

service nginx restart
