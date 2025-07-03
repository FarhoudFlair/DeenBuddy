#!/bin/bash
set -e

echo "🚀 Setting up DeenBuddy development environment..."

# Update system packages
sudo apt-get update -y

# Install Node.js 20 (for content pipeline) - skip if already installed
if ! command -v node &> /dev/null; then
    echo "📦 Installing Node.js 20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "📦 Node.js already installed: $(node --version)"
fi

# Install content pipeline dependencies
echo "📦 Installing content pipeline dependencies..."
cd /mnt/persist/workspace/content-pipeline
npm install
cd /mnt/persist/workspace

# Set up environment file for content pipeline
echo "⚙️ Setting up content pipeline environment..."
cd content-pipeline
if [ ! -f .env ]; then
    cp .env.example .env
    echo "NODE_ENV=test" >> .env
    echo "LOG_LEVEL=error" >> .env
fi
cd ..

# Install Swift dependencies first
echo "🔧 Installing Swift dependencies..."
sudo apt-get install -y \
    binutils \
    git \
    gnupg2 \
    libc6-dev \
    libcurl4-openssl-dev \
    libedit2 \
    libgcc-9-dev \
    libpython3.8 \
    libsqlite3-0 \
    libstdc++-9-dev \
    libxml2-dev \
    libz3-dev \
    pkg-config \
    tzdata \
    unzip \
    zlib1g-dev \
    wget

# Try to install Swift using the official installer script
echo "🔧 Installing Swift using official installer..."
curl -fsSL https://download.swift.org/install.sh | bash -s -- --install-dir /opt/swift --version 5.9.2 --platform ubuntu22.04 || {
    echo "⚠️  Official Swift installer failed, trying manual installation..."
    
    # Manual Swift installation as fallback
    cd /tmp
    wget -q --timeout=60 https://download.swift.org/swift-5.9.2-release/ubuntu2204/swift-5.9.2-RELEASE-ubuntu22.04.tar.gz || {
        echo "⚠️  Swift download failed, continuing without Swift..."
        SWIFT_AVAILABLE=false
    }
    
    if [ -f "swift-5.9.2-RELEASE-ubuntu22.04.tar.gz" ]; then
        echo "📦 Extracting Swift..."
        tar xzf swift-5.9.2-RELEASE-ubuntu22.04.tar.gz
        sudo mv swift-5.9.2-RELEASE-ubuntu22.04 /opt/swift
        SWIFT_AVAILABLE=true
    else
        SWIFT_AVAILABLE=false
    fi
}

# Add Swift to PATH if available
if [ -d "/opt/swift" ]; then
    echo 'export PATH="/opt/swift/usr/bin:$PATH"' >> $HOME/.profile
    export PATH="/opt/swift/usr/bin:$PATH"
    SWIFT_AVAILABLE=true
    echo "✅ Swift installed: $(/opt/swift/usr/bin/swift --version | head -1)"
else
    SWIFT_AVAILABLE=false
    echo "⚠️  Swift is not available"
fi

# If Swift is available, try to resolve dependencies
if [ "$SWIFT_AVAILABLE" = true ]; then
    echo "📦 Resolving Swift package dependencies..."
    
    # Set environment variables for Swift
    export PATH="/opt/swift/usr/bin:$PATH"
    
    # Resolve main package dependencies with timeout
    echo "📦 Resolving main package dependencies..."
    timeout 300 /opt/swift/usr/bin/swift package resolve || echo "Main package resolve timed out or failed, continuing..."
    
    # Resolve DeenAssist package dependencies
    echo "📦 Resolving DeenAssist package dependencies..."
    cd DeenAssist
    timeout 300 /opt/swift/usr/bin/swift package resolve || echo "DeenAssist package resolve timed out or failed, continuing..."
    cd ..
    
    # Resolve QiblaKit package dependencies
    echo "📦 Resolving QiblaKit package dependencies..."
    cd QiblaKit
    timeout 300 /opt/swift/usr/bin/swift package resolve || echo "QiblaKit package resolve timed out or failed, continuing..."
    cd ..
fi

echo "✅ Setup completed successfully!"
echo "🧪 Ready to run tests..."

# Show what tests are available
echo ""
echo "📋 Available tests:"
echo "  - Content Pipeline: npm test (in content-pipeline directory)"
if [ "$SWIFT_AVAILABLE" = true ]; then
    echo "  - Main Swift Package: swift test"
    echo "  - DeenAssist Package: swift test (in DeenAssist directory)"
    echo "  - QiblaKit Package: swift test (in QiblaKit directory)"
else
    echo "  - Swift tests: Not available (Swift not installed)"
fi