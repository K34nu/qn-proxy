#!/bin/sh

#
# (c) Qnetix LTD 2023
#

# Install Docker
echo "Installing Docker..."
apk update && apk add docker
rc-update add docker boot
service docker start
addgroup root docker
echo "Docker installation completed."

# Download and start the MariaDB container
echo "Setting up MariaDB container..."
docker pull mariadb:latest
RANDOM_PASSWORD=$(openssl rand -base64 12)
echo "Generated random password for zabbix user: ${RANDOM_PASSWORD}"

docker run -d --name mariadb \
  -e MYSQL_ROOT_PASSWORD=root_password \
  -e MYSQL_DATABASE=zabbix_proxy \
  -e MYSQL_USER=zabbix \
  -e MYSQL_PASSWORD="${RANDOM_PASSWORD}" \
  mariadb:10.7

# Download the Zabbix-proxy-mysql container
echo "Downloading Zabbix-proxy-mysql container..."
docker pull zabbix/zabbix-proxy-mysql:latest

# Get server address and port from user
read -p "Please enter the server address: " server_address
read -p "Please enter the server port: " server_port

# Start the Zabbix-proxy-mysql container
echo "Starting Zabbix-proxy-mysql container..."
docker run -d --name zabbix_proxy_mysql \
  --link mariadb_container:mysql \
  -e DB_SERVER_HOST="mariadb" \
  -e MYSQL_DATABASE="zabbix_proxy" \
  -e MYSQL_USER="zabbix" \
  -e MYSQL_PASSWORD="${RANDOM_PASSWORD}" \
  -e ZBX_SERVER_HOST="${server_address}" \
  -e ZBX_SERVER_PORT="${server_port}" \
  zabbix/zabbix-proxy-mysql:latest

echo "Zabbix-proxy-mysql container started successfully."
