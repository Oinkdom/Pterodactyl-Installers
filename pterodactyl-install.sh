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

# Add "add-apt-repository" command
apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg

# Add additional repositories for PHP, Redis, and MariaDB
LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php

# Add Redis official APT repository
curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list


# Install Dependencies
apt -y install php8.1 php8.1-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip} mariadb-server nginx tar unzip git redis-server

# Install Composer
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer

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

# Set Perms
chown -R www-data:www-data /var/www/pterodactyl/*

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

# Nginx Config File

echo 'server {
    listen 80;
    server_name <domain>;

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

