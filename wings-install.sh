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

# Check if Docker is installed
if ! command -v docker &>/dev/null; then
  echo "Docker not found. Installing Docker..."
  curl -sSL https://get.docker.com/ | CHANNEL=stable bash
else
  echo "Docker is already installed. Skipping Docker installation."
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &>/dev/null; then
  echo "Docker Compose not found. Installing Docker Compose..."
  apt install docker-compose
else
  echo "Docker Compose is already installed. Skipping Docker Compose installation."
fi

# Enable Docker
systemctl enable --now docker

# Function to add or modify the swapaccount parameter in GRUB_CMDLINE_LINUX_DEFAULT
update_grub_cmdline() {
    # Check if the GRUB_CMDLINE_LINUX_DEFAULT is empty or contains some other parameters
    if grep -q "^GRUB_CMDLINE_LINUX_DEFAULT=\"\"" /etc/default/grub; then
        # GRUB_CMDLINE_LINUX_DEFAULT is empty, so add swapaccount=1 between the ""
        sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=""/GRUB_CMDLINE_LINUX_DEFAULT="swapaccount=1"/' /etc/default/grub
    else
        # GRUB_CMDLINE_LINUX_DEFAULT already contains some parameters, so append swapaccount=1 to the existing ones
        sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"$/\1 swapaccount=1"/' /etc/default/grub
    fi
}

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo or log in as root and try again."
    exit 1
fi

# Run the function to update GRUB_CMDLINE_LINUX_DEFAULT
update_grub_cmdline

# Update GRUB after modifying the file
update-grub

echo "GRUB_CMDLINE_LINUX_DEFAULT updated successfully."

# Install wings
mkdir -p /etc/pterodactyl
curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")"
chmod u+x /usr/local/bin/wings

# Create the wings.service 
cat <<EOL > /etc/systemd/system/wings.service
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOL

# Enable wings
systemctl enable --now wings

# Prompt the user if they want to reboot now
read -p "Do you want to reboot the system now? (Y/n): " reboot_now

# Set default option for rebooting
reboot_now=${reboot_now:-Y}

if [[ $reboot_now == "y" || $reboot_now == "Y" ]]; then
    echo "Rebooting the system now..."
    reboot
else
echo "▓█████▄  ▒█████   ███▄    █ ▓█████  ▐██▌  ▐██▌ ";
echo "▒██▀ ██▌▒██▒  ██▒ ██ ▀█   █ ▓█   ▀  ▐██▌  ▐██▌ ";
echo "░██   █▌▒██░  ██▒▓██  ▀█ ██▒▒███    ▐██▌  ▐██▌ ";
echo "░▓█▄   ▌▒██   ██░▓██▒  ▐▌██▒▒▓█  ▄  ▓██▒  ▓██▒ ";
echo "░▒████▓ ░ ████▓▒░▒██░   ▓██░░▒████▒ ▒▄▄   ▒▄▄  ";
echo " ▒▒▓  ▒ ░ ▒░▒░▒░ ░ ▒░   ▒ ▒ ░░ ▒░ ░ ░▀▀▒  ░▀▀▒ ";
echo " ░ ▒  ▒   ░ ▒ ▒░ ░ ░░   ░ ▒░ ░ ░  ░ ░  ░  ░  ░ ";
echo " ░ ░  ░ ░ ░ ░ ▒     ░   ░ ░    ░       ░     ░ ";
echo "   ░        ░ ░           ░    ░  ░ ░     ░    ";
echo " ░                                             ";
echo "                                               ";
echo "                                               ";
echo "                                               ";
echo "Installation is complete. You can now reboot to apply changes!"
