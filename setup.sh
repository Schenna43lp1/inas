#!/bin/bash

# Update package list
apt update -y

# Install prerequisites
apt -y install software-properties-common curl ca-certificates gnupg2 sudo lsb-release

# Add Sury PHP repository
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/sury-php.list

# Add Sury PHP repository GPG key
curl -fsSL https://packages.sury.org/php/apt.gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/sury-keyring.gpg

# Update package list again
apt update -y

# Install PHP 8.2 and necessary extensions
apt install -y php8.2 php8.2-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip}

# Setup MariaDB repository and install MariaDB server
curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version="mariadb-10.11"
apt install -y mariadb-server

# Install additional packages
apt install -y nginx tar unzip git redis-server

echo "Installation complete."
