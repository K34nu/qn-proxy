#!/bin/sh

# Update the system
apk update && apk upgrade

# Install Zabbix repository
echo "http://repo.zabbix.com/zabbix/6.0/alpine/v3.14/main" >> /etc/apk/repositories

# Add Zabbix public key
wget https://repo.zabbix.com/zabbix-official-repo.key -O - | apk add --allow-untrusted - gpg

# Install Zabbix proxy, PostgreSQL, and related tools
apk add zabbix-proxy-pgsql postgresql postgresql-client zabbix-sql-scripts

# Initialize the PostgreSQL database
mkdir -p /var/lib/postgresql/data
chown -R postgres:postgres /var/lib/postgresql
su - postgres -c 'initdb -D /var/lib/postgresql/data'

# Start the PostgreSQL service
rc-update add postgresql default
rc-service postgresql start

# Generate a random database password
db_password=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 12)

# Set up the initial steps on PostgreSQL
su - postgres -c "createuser zabbix"
su - postgres -c "createdb -O zabbix zabbix_proxy"
su - postgres -c "psql -c \"ALTER USER zabbix WITH ENCRYPTED PASSWORD '${db_password}';\""

# Import the Zabbix proxy database schema
zcat /usr/share/zabbix-sql-scripts/postgresql/proxy.sql.gz | PGPASSWORD=${db_password} su - postgres -c "psql -U zabbix zabbix_proxy"

# Ask the user for a server address and port number
printf "Enter the Zabbix server address: "
read server_address
printf "Enter the Zabbix server port number: "
read server_port

# Update the zabbix_proxy.conf file
server_address_port="${server_address}:${server_port}"
sed -i "s/^Server=.*/Server=${server_address_port}/" /etc/zabbix/zabbix_proxy.conf
sed -i "s/^DBUser=.*/DBUser=zabbix/" /etc/zabbix/zabbix_proxy.conf
sed -i "s/^DBPassword=.*/DBPassword=${db_password}/" /etc/zabbix/zabbix_proxy.conf
sed -i "s/^DBName=.*/DBName=zabbix_proxy/" /etc/zabbix/zabbix_proxy.conf

# Enable and restart the Zabbix proxy service
rc-update add zabbix-proxy default
rc-service zabbix-proxy restart

# Unset variables
unset server_address
unset server_port
unset db_password
unset server_address_port

echo "Zabbix proxy installation and configuration completed."
