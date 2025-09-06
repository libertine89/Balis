#!/usr/bin/env bash
set -e

# -------- CONFIG --------
# Go installation
GO_INSTALL_DIR="/tmp/go"
GOPATH_DIR="/tmp/go-workspace"
GOCACHE_DIR="/tmp/go-cache"
GO_VERSION="1.22.12"
GO_TARBALL="go${GO_VERSION}.linux-amd64.tar.gz"
GO_DOWNLOAD_URL="https://go.dev/dl/${GO_TARBALL}"

# Project
PROJECT_DIR="/tmp/bubbletea-project"
GO_FILE_NAME="gui.go"
MODULE_NAME="bubbletea-test"
GUI_FILE_URL="https://raw.githubusercontent.com/libertine89/Balis/Refactor/gui/gui.go"

# -------- INSTALL GO --------
echo "Creating Go directories..."
mkdir -p "$GO_INSTALL_DIR" "$GOPATH_DIR/bin" "$GOCACHE_DIR"

echo "Downloading Go $GO_VERSION..."
curl -L -o "/tmp/${GO_TARBALL}" "$GO_DOWNLOAD_URL"

echo "Extracting Go to /tmp..."
tar -C /tmp -xzf "/tmp/${GO_TARBALL}"

echo "Setting Go environment variables..."
export PATH="$GO_INSTALL_DIR/bin:$GOPATH_DIR/bin:$PATH"
export GOPATH="$GOPATH_DIR"
export GOCACHE="$GOCACHE_DIR"
export GOMODCACHE="$GOPATH/pkg/mod"

echo "Go installed successfully!"
echo "PATH=$PATH"
echo "GOPATH=$GOPATH"
echo "GOCACHE=$GOCACHE"

echo "Verify installation:"
go version

# -------- SETUP PROJECT --------
echo "Creating project folder at $PROJECT_DIR..."
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

echo "Downloading GUI Go file..."
curl -LO "$GUI_FILE_URL"

echo "Initializing Go module..."
go mod init "$MODULE_NAME"

echo "Downloading required modules..."
go mod tidy

# -------- FINISH --------
cd "$PROJECT_DIR"
echo "Project setup complete! You are now in $PROJECT_DIR"
echo "You can run your program with:"
echo "go run $GO_FILE_NAME"
