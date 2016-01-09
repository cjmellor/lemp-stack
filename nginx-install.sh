#!/bin/bash

branch=stable

# Custom options/arguments
usage() {
    echo "
        NGINX Installation script

        $0 -- Installs and configures NGINX in almost one command

        USAGE:
            $0 [-bs][-b branch_version][-s site_name]

        OPTIONS:

            -b      Choose which branch to use - stable|development

            -s      Choose a website name using the pattern 'example.com'
    "
    1>&2;
    exit 1;
}

while getopts "bs:" opt; do
    case $opt in
        b)
            branch=development
            ;;
        s)
            site=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done

shift $((OPTIND-1))

if [ -z "${s}" ]; then
    echo "
        No website name provided:
            Format: <example.com>
    "
    exit 1;
fi

# Add NGINX key
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C300EE8C

# Add the NGINX repository
touch /etc/apt/sources.list.d/nginx-$branch-trusty.list
chown $(whoami): /etc/apt/sources.list.d/nginx-$branch-trusty.list

cat << EOF > /etc/apt/sources.list.d/nginx-$branch-trusty.list
deb http://ppa.launchpad.net/nginx/$branch/ubuntu trusty main
EOF

# Update and Install NGINX
apt-get update
apt-get install -y nginx

# Add the HTML5 Boilerplate NGINX Configuration
cd /tmp
wget https://github.com/cjmellor/nginx-config/archive/master.zip
unzip master.zip
cp -r nginx-config-master/{extra,mime.types,nginx.conf} /etc/nginx/
cp -r nginx-config-master/sites-available/example.com /etc/nginx/sites-available/
rm -rf {master.zip,nginx-config-master}

service nginx reload

# Remove the default sites and add new sites
cd /etc/nginx/sites-available
rm default
# mv example.com <site-name.com>

########## CONFIGURATION ##########
# Make edit changes to configuration files.
###################################

# First need to get to the config file
cd /etc/nginx

# Change the user to run NGINX
sed -i "s/user chris;/user $(whoami);/g" nginx.conf
