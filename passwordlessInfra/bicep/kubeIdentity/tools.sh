#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Update system packages
echo "Updating system packages..."
sudo apt-get update -y

# Install Git
echo "Installing Git..."
sudo apt-get install -y git

# Install K9s
echo "Installing K9s..."

# Determine the latest version of K9s
echo "Fetching the latest version of K9s..."
K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')

echo "Latest K9s version is $K9S_VERSION"

# Download the latest release for Linux AMD64
echo "Downloading K9s version $K9S_VERSION..."
curl -Lo k9s_Linux_x86_64.tar.gz https://github.com/derailed/k9s/releases/download/$K9S_VERSION/k9s_Linux_amd64.tar.gz

# Extract and install K9s
echo "Installing K9s..."
tar -xzf k9s_Linux_x86_64.tar.gz
sudo install k9s /usr/local/bin/

# Clean up
echo "Cleaning up..."
rm k9s_Linux_x86_64.tar.gz k9s LICENSE README.md

# Verify installation
echo "Verifying K9s installation..."
k9s version

# Clone the repository
echo "Cloning the repository..."
git clone https://github.com/DrBushyTop/blogExamples.git

echo "Installation and repository clone complete!"
