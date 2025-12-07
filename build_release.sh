#!/bin/bash

# Script برای build و ساخت release
# Usage: ./build_release.sh [version]

set -e

VERSION=${1:-$(git describe --tags --abbrev=0 2>/dev/null || echo "v1.0.0")}
VERSION=${VERSION#v}  # Remove 'v' prefix if exists

echo "Building x-ui version: $VERSION"

# Clean previous builds
rm -rf release-* x-ui-linux-*.tar.gz

# Build for each architecture
ARCHES=("amd64" "arm64" "armv7")

for ARCH in "${ARCHES[@]}"; do
    echo "Building for $ARCH..."
    
    # Set Go environment
    export GOOS=linux
    if [ "$ARCH" = "armv7" ]; then
        export GOARCH=arm
        export GOARM=7
    else
        export GOARCH=$ARCH
        unset GOARM
    fi
    
    # Build x-ui
    go build -ldflags "-w -s" -o x-ui main.go
    
    # Download Xray binary
    mkdir -p bin-$ARCH
    cd bin-$ARCH
    
    XRAY_ARCH=$ARCH
    XRAY_FILENAME="Xray-linux-${ARCH}.zip"
    
    if [ "$ARCH" = "armv7" ]; then
        XRAY_ARCH="arm32-v7a"
        XRAY_FILENAME="Xray-linux-arm32-v7a.zip"
    elif [ "$ARCH" = "arm64" ]; then
        XRAY_ARCH="arm64-v8a"
        XRAY_FILENAME="Xray-linux-arm64-v8a.zip"
    fi
    
    # Get latest Xray version
    XRAY_VERSION=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$XRAY_VERSION" ]; then
        echo "Failed to get Xray version, trying to download latest..."
        XRAY_VERSION="latest"
    fi
    
    echo "Downloading Xray $XRAY_VERSION for $XRAY_ARCH..."
    
    # Try different URL formats
    XRAY_URL="https://github.com/XTLS/Xray-core/releases/${XRAY_VERSION}/download/${XRAY_FILENAME}"
    if [ "$XRAY_VERSION" = "latest" ]; then
        XRAY_URL="https://github.com/XTLS/Xray-core/releases/latest/download/${XRAY_FILENAME}"
    fi
    
    # Download with retry
    MAX_RETRIES=3
    RETRY=0
    while [ $RETRY -lt $MAX_RETRIES ]; do
        if wget -q --timeout=30 ${XRAY_URL} -O ${XRAY_FILENAME}; then
            break
        fi
        RETRY=$((RETRY+1))
        echo "Download failed, retrying... ($RETRY/$MAX_RETRIES)"
        sleep 2
    done
    
    if [ ! -f "${XRAY_FILENAME}" ]; then
        echo "ERROR: Failed to download Xray binary for $ARCH"
        echo "URL tried: $XRAY_URL"
        cd ..
        exit 1
    fi
    
    unzip -q ${XRAY_FILENAME}
    rm ${XRAY_FILENAME}
    
    # Rename xray binary
    if [ "$ARCH" = "armv7" ]; then
        mv xray xray-linux-armv7 2>/dev/null || true
        chmod +x xray-linux-armv7
    else
        mv xray xray-linux-$ARCH 2>/dev/null || true
        chmod +x xray-linux-$ARCH
    fi
    
    # Check if file exists
    if [ ! -f "xray-linux-$ARCH" ] && [ ! -f "xray-linux-armv7" ]; then
        echo "ERROR: Xray binary not found after extraction"
        ls -la
        cd ..
        exit 1
    fi
    
    cd ..
    
    # Create release directory
    mkdir -p release-$ARCH
    cp x-ui release-$ARCH/
    cp x-ui.sh release-$ARCH/
    cp x-ui.service release-$ARCH/
    mkdir -p release-$ARCH/bin
    cp bin-$ARCH/xray-linux-* release-$ARCH/bin/
    
    # Create tarball
    cd release-$ARCH
    tar czf ../x-ui-linux-$ARCH.tar.gz *
    cd ..
    
    echo "Created x-ui-linux-$ARCH.tar.gz"
done

# Cleanup
rm -rf release-* bin-* x-ui

echo ""
echo "Build completed!"
echo "Release files:"
ls -lh x-ui-linux-*.tar.gz
echo ""
echo "Next steps:"
echo "1. Create a release on GitHub with tag: v$VERSION"
echo "2. Upload these files to the release:"
echo "   - x-ui-linux-amd64.tar.gz"
echo "   - x-ui-linux-arm64.tar.gz"
echo "   - x-ui-linux-armv7.tar.gz"

