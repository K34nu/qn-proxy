#!/bin/sh

#
# (c) Qnetix LTD 2023
#

# Set Variables
DB_VERS=10.7
PRXY_VERS=alpine-6.0-latest

# Get server address and port from user
read -p "Please enter the server address: " server_address
read -p "Please enter the server port: " server_port

# Setup mariadb
docker pull mariadb:${DB_VERS}

if [ $? -ne 0 ]; then
  echo "An error occurred, aborting script." | tee -a install_log.txt
  exit 1
else
  echo "Pull MariaDB step completed successfully." | tee -a install_log.txt
fi

# Generate random password
DBROOT_RAND_PASSWD=$(openssl rand -base64 12) && echo "Generated random password for MariaDB user: ${DBROOT_RAND_PASSWD}"
ZABX_RAND_PASSWD=$(openssl rand -base64 12) && echo "Generated Random password for zabbix user: ${ZBX_RAND_PASSWD}"

# Run the MariaDB Container
docker run -d --name mariadb \
  -e MYSQL_ROOT_PASSWORD="${DBROOT_RAND_PASSWD}" \
  -e MYSQL_DATABASE=zabbix_proxy \
  -e MYSQL_USER=zabbix \
  -e MYSQL_PASSWORD="${ZABX_RAND_PASSWD}" \
  --restart always
  mariadb:${DB_VERS}

if [ $? -ne 0 ]; then
  echo "An error occurred, aborting script." | tee -a install_log.txt
  exit 1
else
  echo "Run MariaDB step completed successfully." | tee -a install_log.txt
fi

# Download the Zabbix-proxy-mysql container
echo "Downloading Zabbix-proxy-mysql container..."
docker pull zabbix/zabbix-proxy-mysql:${PRXY_VERS}

if [ $? -ne 0 ]; then
  echo "An error occurred, aborting script." | tee -a install_log.txt
  exit 1
else
  echo "Pull Zabbix-Proxy-MySQL step completed successfully." | tee -a install_log.txt
fi

# Start the Zabbix-proxy-mysql container
echo "Starting Zabbix-proxy-mysql container..."

docker run -d --name zproxy \
  --link mariadb:mysql \
  -e DB_SERVER_HOST="mariadb" \
  -e MYSQL_DATABASE="zabbix_proxy" \
  -e MYSQL_USER="zabbix" \
  -e MYSQL_PASSWORD="${RANDOM_PASSWORD}" \
  -e ZBX_SERVER_HOST="${server_address}" \
  -e ZBX_SERVER_PORT="${server_port}" \
  --restart always
  zabbix/zabbix-proxy-mysql:${PRXY_VERS}

if [ $? -ne 0 ]; then
  echo "An error occurred, aborting script." | tee -a install_log.txt
  exit 1
else
  echo "Run Zabbix-Proxy-MySQL step completed successfully." | tee -a install_log.txt
fi

echo "Zabbix-proxy-mysql container started successfully."

echo "#===================================================================#"
echo "#  PLEASE MAKE NOTE OF THE FOLLOWING INFORMATION AND KEEP IT SAFE.  #"
echo "#           IT MAY BE REQUIRED FOR DEBUGGING IN FUTURE              #"
echo "#===================================================================#"
echo "#                       Generated Passwords:                        #"
echo "# Generated random password for MariaDB user: ${DBROOT_RAND_PASSWD} #"
echo "# Generated Random password for zabbix user: ${ZBX_RAND_PASSWD}     #"
echo "#===================================================================#"

rm -f install_log.txt
