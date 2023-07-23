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

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo or log in as root and try again."
    exit 1
fi

# Prompt the user if they want to remove the swapaccount parameter from GRUB_CMDLINE_LINUX_DEFAULT
read -p "Do you want to remove 'swapaccount=1' from GRUB_CMDLINE_LINUX_DEFAULT? (Y/n): " remove_swapaccount

# Set default option for removing swapaccount parameter
remove_swapaccount=${remove_swapaccount:-Y}

if [[ $remove_swapaccount == "y" || $remove_swapaccount == "Y" ]]; then
    # Remove the swapaccount parameter from GRUB_CMDLINE_LINUX_DEFAULT
    if grep -q "swapaccount=1" /etc/default/grub; then
        sed -i 's/ swapaccount=1//g' /etc/default/grub
        update-grub
        echo "GRUB_CMDLINE_LINUX_DEFAULT updated successfully."
    else
        echo "GRUB_CMDLINE_LINUX_DEFAULT does not contain 'swapaccount=1'. No changes made."
    fi
fi

# Prompt the user if they want to remove Docker Compose
read -p "Do you want to remove Docker Compose? (Y/n): " remove_docker_compose

# Set default option for removing Docker Compose
remove_docker_compose=${remove_docker_compose:-N}

if [[ $remove_docker_compose == "y" || $remove_docker_compose == "Y" ]]; then
    # Remove Docker Compose
    apt remove docker-compose
    echo "Docker Compose removed."
fi

# Prompt the user if they want to remove Docker
read -p "Do you want to remove Docker? (Y/n): " remove_docker

# Set default option for removing Docker
remove_docker=${remove_docker:-N}

if [[ $remove_docker == "y" || $remove_docker == "Y" ]]; then
    # Stop and disable Docker
    systemctl stop docker
    systemctl disable docker

    # Uninstall Docker if it was installed by the install script
    if command -v docker &>/dev/null; then
        apt remove --purge docker-ce docker-ce-cli containerd.io
        echo "Docker removed."
    fi
fi

# Clean up /etc/pterodactyl directory if it was created by the install script
rm -rf /etc/pterodactyl

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
    echo " ░                                             "
    echo "Uninstallation is complete. You can manually reboot the system later to apply the changes."
fi
