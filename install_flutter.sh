#!/bin/bash

# Flutter installation script for Vercel deployment
echo "Installing Flutter SDK..."

# Set Flutter version
FLUTTER_VERSION="3.16.0"
FLUTTER_CHANNEL="stable"

# Create Flutter directory
mkdir -p $HOME/flutter

# Download Flutter if not cached
if [ ! -d "$HOME/flutter/bin" ]; then
    echo "Downloading Flutter $FLUTTER_VERSION..."
    cd $HOME
    wget -q https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz
    tar xf flutter_linux_${FLUTTER_VERSION}-stable.tar.xz
    rm flutter_linux_${FLUTTER_VERSION}-stable.tar.xz
else
    echo "Flutter SDK already exists in cache"
fi

# Add Flutter to PATH
export PATH="$HOME/flutter/bin:$PATH"

# Configure Flutter
flutter config --no-analytics
flutter config --no-cli-animations
flutter config --enable-web

# Verify installation
echo "Flutter version:"
flutter --version

echo "Flutter doctor:"
flutter doctor

echo "Flutter installation complete!"