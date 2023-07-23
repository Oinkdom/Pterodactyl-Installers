#!/bin/bash

echo " ▒█████   ██▓ ███▄    █  ██ ▄█▀ ▐██▌  ▐██▌ ";
echo "▒██▒  ██▒▓██▒ ██ ▀█   █  ██▄█▒  ▐██▌  ▐██▌ ";
echo "▒██░  ██▒▒██▒▓██  ▀█ ██▒▓███▄░  ▐██▌  ▐██▌ ";
echo "▒██   ██░░██░▓██▒  ▐▌██▒▓██ █▄  ▓██▒  ▓██▒ ";
echo "░ ████▓▒░░██░▒██░   ▓██░▒██▒ █▄ ▒▄▄   ▒▄▄  ";
echo "░ ▒░▒░▒░ ░▓  ░ ▒░   ▒ ▒ ▒ ▒▒ ▓▒ ░▀▀▒  ░▀▀▒ ";
echo "  ░ ▒ ▒░  ▒ ░░ ░░   ░ ▒░░ ░▒ ▒░ ░  ░  ░  ░ ";
echo "░ ░ ░ ▒   ▒ ░   ░   ░ ░ ░ ░░ ░     ░     ░ ";
echo "    ░ ░   ░           ░ ░  ░    ░     ░    ";
echo "                                           ";

# Function to check if a package is installed
is_package_installed() {
    dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -q "install ok installed"
}


# Function to check if Composer is installed
is_composer_installed() {
    command -v composer &>/dev/null
}

# Check if the OS supports the apt command
if ! command -v apt &>/dev/null; then
    echo "Unsupported OS: apt command not found."
    exit 1
fi

# Add "add-apt-repository" command if it's missing
if ! is_package_installed software-properties-common; then
    apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg
fi

# Add "universe" repository for Ubuntu 18.04
if grep -q "Ubuntu 18.04" /etc/os-release; then
    if ! grep -q "universe" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
        apt-add-repository universe
    fi
fi

# Add additional repositories for PHP, Redis, and MariaDB (for Debian 11 and Ubuntu 22.04)
if ! grep -q "ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
    LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
fi

if ! is_package_installed mariadb-server; then
    curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
fi

# Update repositories list
apt update

# Install Dependencies if they are missing
packages=("php8.1" "php8.1-cli" "php8.1-gd" "php8.1-mysql" "php8.1-pdo" "php8.1-mbstring" "php8.1-tokenizer" "php8.1-bcmath" "php8.1-xml" "php8.1-fpm" "php8.1-curl" "php8.1-zip" "mariadb-server" "nginx" "tar" "unzip" "git" "redis-server" "php8.1-intl" "git")
missing_packages=()

for package in "${packages[@]}"; do
    if ! is_package_installed "$package"; then
        missing_packages+=("$package")
    fi
done

if [ "${#missing_packages[@]}" -gt 0 ]; then
    apt -y install "${missing_packages[@]}"
fi

# Install Composer if it's missing
if ! is_composer_installed; then
    curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
fi


# Download files
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl
curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/

# Create a Database
mysql -u root -p <<EOF
CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY 'yourPassword';
CREATE DATABASE panel;
GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
exit
EOF

# ENV Config
cp .env.example .env
composer install --no-dev --optimize-autoloader
php artisan key:generate --force
php artisan p:environment:setup
php artisan p:environment:database
php artisan p:environment:mail

# Database Setup
php artisan migrate --seed --force

# Add The First User
php artisan p:user:make

# Function to check if the OS is CentOS
is_centos() {
    [[ -f "/etc/centos-release" ]]
}

# Function to set ownership and permissions based on the OS
set_ownership_and_permissions() {
    if is_centos; then
        # CentOS commands
        chown -R nginx:nginx /var/www/pterodactyl/
        chmod -R 755 /var/www/pterodactyl/storage/* /var/www/pterodactyl/bootstrap/cache/
    else
        # Non-CentOS commands
        chown -R www-data:www-data /var/www/pterodactyl/
        chmod -R 755 /var/www/pterodactyl/storage/* /var/www/pterodactyl/bootstrap/cache/
    fi
}

# Call the function to set ownership and permissions
set_ownership_and_permissions

# Pterodactyl Cron Job
(crontab -l ; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -

# Create the pteroq.service 
cat <<EOL > /etc/systemd/system/pteroq.service
# Pterodactyl Queue Worker File
# ----------------------------------

[Unit]


Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
# On some systems the user and group might be different.
# Some systems use \`apache\` or \`nginx\` as the user and group.
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd daemon to recognize the new service
systemctl daemon-reload

# Enable and start the pteroq and redis services
sudo systemctl enable --now pteroq.service
sudo systemctl enable --now redis-server

echo " ███▄    █   ▄████  ██▓ ███▄    █ ▒██   ██▒      ";
echo " ██ ▀█   █  ██▒ ▀█▒▓██▒ ██ ▀█   █ ▒▒ █ █ ▒░      ";
echo "▓██  ▀█ ██▒▒██░▄▄▄░▒██▒▓██  ▀█ ██▒░░  █   ░      ";
echo "▓██▒  ▐▌██▒░▓█  ██▓░██░▓██▒  ▐▌██▒ ░ █ █ ▒       ";
echo "▒██░   ▓██░░▒▓███▀▒░██░▒██░   ▓██░▒██▒ ▒██▒      ";
echo "░ ▒░   ▒ ▒  ░▒   ▒ ░▓  ░ ▒░   ▒ ▒ ▒▒ ░ ░▓ ░      ";
echo "░ ░░   ░ ▒░  ░   ░  ▒ ░░ ░░   ░ ▒░░░   ░▒ ░      ";
echo "   ░   ░ ░ ░ ░   ░  ▒ ░   ░   ░ ░  ░    ░        ";
echo "         ░       ░  ░           ░  ░    ░        ";
echo "                                                 ";
echo "  ██████  ▄████▄   ██▀███   ██▓ ██▓███  ▄▄▄█████▓";
echo "▒██    ▒ ▒██▀ ▀█  ▓██ ▒ ██▒▓██▒▓██░  ██▒▓  ██▒ ▓▒";
echo "░ ▓██▄   ▒▓█    ▄ ▓██ ░▄█ ▒▒██▒▓██░ ██▓▒▒ ▓██░ ▒░";
echo "  ▒   ██▒▒▓▓▄ ▄██▒▒██▀▀█▄  ░██░▒██▄█▓▒ ▒░ ▓██▓ ░ ";
echo "▒██████▒▒▒ ▓███▀ ░░██▓ ▒██▒░██░▒██▒ ░  ░  ▒██▒ ░ ";
echo "▒ ▒▓▒ ▒ ░░ ░▒ ▒  ░░ ▒▓ ░▒▓░░▓  ▒▓▒░ ░  ░  ▒ ░░   ";
echo "░ ░▒  ░ ░  ░  ▒     ░▒ ░ ▒░ ▒ ░░▒ ░         ░    ";
echo "░  ░  ░  ░          ░░   ░  ▒ ░░░         ░      ";
echo "      ░  ░ ░         ░      ░                    ";
echo "         ░                                       ";

# Remove NGINX default conf
rm /etc/nginx/sites-enabled/default

read -p "Enter the server name (e.g., panel.example.com): " server_name

# Nginx Config File

echo 'server {
    listen 80;
    server_name $server_name;

    root /var/www/pterodactyl/public;
    index index.html index.htm index.php;
    charset utf-8;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    add_header Access-Control-Allow-Origin *;

    access_log off;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;

    # allow larger file uploads and longer script runtimes
    client_max_body_size 100m;
    client_body_timeout 120s;

    sendfile off;

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }
}' > /etc/nginx/sites-available/pterodactyl.conf



# Enabling config
sudo ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
nginx -t
sudo systemctl restart nginx

