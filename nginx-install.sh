#!/bin/bash

branch=stable
secure=example.com

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
        NGINX Installation script

        $0 -- Installs and configures NGINX in almost one command

        USAGE:
            $0 [-bs][-b branch_version][-s site_name]

        OPTIONS:

            -b      Choose which branch to use - stable|development

            -s      Choose a website name using the pattern 'example.com'
    "
    exit 0
}

while getopts ":bs:ht" opt; do
    case $opt in
        b)
            branch=development
            ;;
        s)
            site=${OPTARG}
            ;;
        t)
            secure=ssl.example.com
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

# Add NGINX key
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C300EE8C

# Add the NGINX repository
touch /etc/apt/sources.list.d/nginx-$branch-trusty.list
chown "$(whoami)": /etc/apt/sources.list.d/nginx-$branch-trusty.list

cat << EOF > /etc/apt/sources.list.d/nginx-$branch-trusty.list
deb http://ppa.launchpad.net/nginx/$branch/ubuntu trusty main
EOF

# Update and Install NGINX
apt-get update
apt-get install -y nginx

cp -r nginx-config/{extra,mime.types,nginx.conf} /etc/nginx/
cp -r nginx-config/sites-available/${secure} /etc/nginx/sites-available/

service nginx reload

# Remove the default sites and add new sites
cd /etc/nginx/sites-available || exit 1
rm default
mv ${secure} "${site}"
mkdir -p /var/www/"${site}"/html

########## CONFIGURATION ##########

# First need to get to the config file
cd /etc/nginx || exit 1

# Change the user to run NGINX
sed -i "s/user nginx;/user $(whoami);/" nginx.conf
sed -i "s/${secure}/${site}/g" sites-available/"${site}"
