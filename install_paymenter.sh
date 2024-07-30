#!/bin/bash

# Update package list
apt update -y

# Install prerequisites
apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg

# Add PHP repository
LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php

# Add MariaDB repository and update package list
curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version="mariadb-10.11"
apt update -y

# Install necessary packages
apt install -y php8.2 php8.2-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip} mariadb-server nginx tar unzip git redis-server

# Install Composer
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer

# Download Paymenter code
mkdir /var/www/paymenter
cd /var/www/paymenter
curl -Lo paymenter.tar.gz https://github.com/paymenter/paymenter/releases/latest/download/paymenter.tar.gz
tar -xzvf paymenter.tar.gz
chmod -R 755 storage/* bootstrap/cache/

# Set up MySQL database
mysql -u root -p -e "
CREATE USER 'paymenter'@'127.0.0.1' IDENTIFIED BY 'yourPassword';
CREATE DATABASE paymenter;
GRANT ALL PRIVILEGES ON paymenter.* TO 'paymenter'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
"

# Set up Paymenter
cp .env.example .env
composer install --no-dev --optimize-autoloader
php artisan key:generate --force
php artisan storage:link

# Configure environment settings
sed -i 's/DB_DATABASE=homestead/DB_DATABASE=paymenter/' .env
sed -i 's/DB_USERNAME=homestead/DB_USERNAME=paymenter/' .env
sed -i 's/DB_PASSWORD=secret/DB_PASSWORD=yourPassword/' .env

# Set up database
php artisan migrate --force --seed

# Create admin user
php artisan p:user:create

# Configure Nginx
cat <<EOF > /etc/nginx/sites-available/paymenter.conf
server {
    listen 80;
    listen [::]:80;
    server_name your_domain;
    root /var/www/paymenter/public;

    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
    }
}
EOF

# Enable Nginx site and restart service
ln -s /etc/nginx/sites-available/paymenter.conf /etc/nginx/sites-enabled/
systemctl restart nginx

# Set permissions
chown -R www-data:www-data /var/www/paymenter/*

# Set up cronjob for Paymenter tasks
(crontab -l 2>/dev/null; echo "* * * * * php /var/www/paymenter/artisan schedule:run >> /dev/null 2>&1") | crontab -

# Set up queue worker
cat <<EOF > /etc/systemd/system/paymenter.service
[Unit]
Description=Paymenter Queue Worker

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/paymenter/artisan queue:work
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# Enable and start queue worker service
systemctl enable --now paymenter.service

echo "Installation complete. Please replace 'your_domain' and 'yourPassword' with actual values."
