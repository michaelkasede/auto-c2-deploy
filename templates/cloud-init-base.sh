#!/bin/bash
# Reusable Base Cloud-init script
# Prepares the OS for Ansible configuration

# Set hostname
hostnamectl set-hostname ${hostname}

# Update system and install Ansible prerequisites
apt-get update
apt-get install -y python3 python3-pip python3-apt htop curl

# Create a marker for Ansible to know bootstrapping is complete
touch /var/lib/cloud/instance/boot-finished
