#!/bin/bash

mkdir -p /usr/local/src/mysql57-build
cd /usr/local/src/mysql57-build

# Download the MySQL pubkey
wget -q https://raw.githubusercontent.com/cjmellor/lemp-stack/master/mysql_pubkey.asc

# Add the key
apt-key add mysql_pubkey.asc

# Add the MySQL repository
touch /etc/apt/sources.list.d/mysql.list
chown $(whoami): /etc/apt/sources.list.d/mysql.list

cat << EOF > /etc/apt/sources.list.d/mysql.list
deb http://repo.mysql.com/apt/ubuntu/ trusty mysql-5.7
EOF

apt-get update -qq

# Install MySQL without interaction
export DEBIAN_FRONTEND=noninteractive

echo "mysql-server mysql-server/root_password password root" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password root" | debconf-set-selections

apt-get install -qqy mysql-server

# Automatic way to run 'mysql_secure_installation'
mysql -u root <<-EOF
    UPDATE mysql.user SET Password=PASSWORD('test1234') WHERE User='root';
    DELETE FROM mysql.user WHERE User='';
    DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
    DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';
    FLUSH PRIVILEGES;
EOF
