#!/bin/bash

# Include functions
. functions.cfg

usage() {
    echo "
        MySQL Installation Script

        $0 -- Installs MySQL

        USAGE:
            $0 [-m][-m mysql_version]

        OPTIONS:
            -m      (Optional) Install a version (5.5 | 5.6) of MySQL. Default: 5.7
    "
    exit 0
}

while getopts ":m:h" opt; do
    case $opt in
        m)
            version="${OPTARG}"
            ;;
        \?)
            error "-$OPTARG is not a valid option. Use '-h' for more options" 'warn'
            ;;
        *|h)
            usage
            ;;
    esac
done

shift $((OPTIND-1))

[[ -z ${version} ]] && version=5.7

[[ "${version}" < 5.5 || "${version}" > 5.7 ]] &&
    error "Valid MySQL versions: 5.5 - 5.6 - 5.7" 'error'

# Import MySQL public key
apt-key adv --recv-keys --keyserver hkp://keys.gnupg.net 8C718D3B5072E1F5

# Add the MySQL repository
touch /etc/apt/sources.list.d/mysql.list
chown "$(whoami)": /etc/apt/sources.list.d/mysql.list

cat << EOF > /etc/apt/sources.list.d/mysql.list
deb http://repo.mysql.com/apt/ubuntu/ trusty mysql-${version}
EOF

apt-get update

# Install MySQL without interaction
export DEBIAN_FRONTEND=noninteractive

echo "mysql-server mysql-server/root_password password *" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password *" | debconf-set-selections

apt-get install -y mysql-server

# Automatic way to run 'mysql_secure_installation'
mysql -u root <<-EOF
    UPDATE mysql.user SET Authentication_string=PASSWORD('test1234') WHERE User='root';
    DELETE FROM mysql.user WHERE User='';
    DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
    DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';
    FLUSH PRIVILEGES;
EOF
