#!/bin/bash

set -e

echo "[+] Updating system..."
sudo apt update && sudo apt upgrade -y

echo "[+] Installing Apache and PHP..."
sudo apt install -y apache2 php-mysql libapache2-mod-php

echo "[+] Installing PHP Extensions..."
sudo apt install -y php-xml php-ldap php-mbstring php-gd php-gmp php-intl

echo "[+] Installing MariaDB..."
sudo apt install -y mariadb-server mariadb-client

echo "[+] Installing SNMP and RRDTool..."
sudo apt install -y snmp php-snmp rrdtool librrds-perl

echo "[+] Tuning MariaDB config..."
sudo tee -a /etc/mysql/mariadb.conf.d/50-server.cnf > /dev/null <<EOF

# Cacti Tuning
collation-server = utf8mb4_unicode_ci
max_heap_table_size = 128M
tmp_table_size = 64M
join_buffer_size = 64M
innodb_file_format = Barracuda
innodb_large_prefix = 1
innodb_buffer_pool_size = 512M
innodb_flush_log_at_timeout = 3
innodb_read_io_threads = 32
innodb_write_io_threads = 16
innodb_io_capacity = 5000
innodb_io_capacity_max = 10000
innodb_doublewrite = OFF
EOF

sudo systemctl restart mariadb

echo "[+] Updating PHP config..."
PHPVER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')

sudo sed -i "s|;date.timezone =.*|date.timezone = US/Central|" /etc/php/$PHPVER/apache2/php.ini
sudo sed -i "s|memory_limit = .*|memory_limit = 512M|" /etc/php/$PHPVER/apache2/php.ini
sudo sed -i "s|max_execution_time = .*|max_execution_time = 60|" /etc/php/$PHPVER/apache2/php.ini

sudo sed -i "s|;date.timezone =.*|date.timezone = US/Central|" /etc/php/$PHPVER/cli/php.ini
sudo sed -i "s|memory_limit = .*|memory_limit = 512M|" /etc/php/$PHPVER/cli/php.ini
sudo sed -i "s|max_execution_time = .*|max_execution_time = 60|" /etc/php/$PHPVER/cli/php.ini

echo "[+] Creating database for Cacti..."
sudo mysql -e "CREATE DATABASE cacti;"
sudo mysql -e "GRANT ALL ON cacti.* TO cacti@localhost IDENTIFIED BY 'cacti';"
sudo mysql -e "FLUSH PRIVILEGES;"
sudo mysql mysql < /usr/share/mysql/mysql_test_data_timezone.sql
sudo mysql -e "GRANT SELECT ON mysql.time_zone_name TO cacti@localhost;"
sudo mysql -e "FLUSH PRIVILEGES;"

echo "[+] Downloading and configuring Cacti..."
wget https://www.cacti.net/downloads/cacti-latest.tar.gz
tar -zxvf cacti-latest.tar.gz
sudo mv cacti-1* /opt/cacti
sudo mysql cacti < /opt/cacti/cacti.sql
sudo cp /opt/cacti/include/config.php.dist /opt/cacti/include/config.php

sudo sed -i "s/\$database_username =.*/\$database_username = 'cacti';/" /opt/cacti/include/config.php
sudo sed -i "s/\$database_password =.*/\$database_password = 'cacti';/" /opt/cacti/include/config.php

echo "[+] Setting up cron job..."
echo "*/5 * * * * www-data php /opt/cacti/poller.php > /dev/null 2>&1" | sudo tee /etc/cron.d/cacti

echo "[+] Creating Apache site config for Cacti..."
sudo tee /etc/apache2/sites-available/cacti.conf > /dev/null <<EOF
Alias /cacti /opt/cacti

<Directory /opt/cacti>
    Options +FollowSymLinks
    AllowOverride None
    <IfVersion >= 2.3>
        Require all granted
    </IfVersion>
    <IfVersion < 2.3>
        Order Allow,Deny
        Allow from all
    </IfVersion>

    AddType application/x-httpd-php .php

    <IfModule mod_php.c>
        php_flag magic_quotes_gpc Off
        php_flag short_open_tag On
        php_flag register_globals Off
        php_flag register_argc_argv On
        php_flag track_vars On
        php_value mbstring.func_overload 0
        php_value include_path .
    </IfModule>

    DirectoryIndex index.php
</Directory>
EOF

sudo a2ensite cacti
sudo systemctl reload apache2

echo "[+] Creating log file and setting permissions..."
sudo mkdir -p /opt/cacti/log
sudo touch /opt/cacti/log/cacti.log
sudo chown -R www-data:www-data /opt/cacti

echo "[+] Done! Open http://your_ip_address/cacti"
echo "Username: admin | Password: admin"
