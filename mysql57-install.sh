#!/bin/bash

# Import MySQL public key
apt-key adv --recv-keys --keyserver hkp://keys.gnupg.net 8C718D3B5072E1F5

# Add the MySQL repository
touch /etc/apt/sources.list.d/mysql.list
chown "$(whoami)": /etc/apt/sources.list.d/mysql.list

cat << EOF > /etc/apt/sources.list.d/mysql.list
deb http://repo.mysql.com/apt/ubuntu/ trusty mysql-5.7
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
