#!/usr/bin/env bash
set -e

# -------- CONFIG --------
# Go installation
GO_INSTALL_DIR="/tmp/go"
GOPATH_DIR="/tmp/go-workspace"
GO_VERSION="1.22.12"
GO_TARBALL="go${GO_VERSION}.linux-amd64.tar.gz"
GO_DOWNLOAD_URL="https://go.dev/dl/${GO_TARBALL}"

# Project
PROJECT_DIR="/tmp/bubbletea-project"
GO_FILE_NAME="gui.go"
MODULE_NAME="bubbletea-test"

# -------- INSTALL GO --------
echo "Creating directories..."
mkdir -p "$GO_INSTALL_DIR"
mkdir -p "$GOPATH_DIR/bin"

echo "Downloading Go $GO_VERSION..."
curl -L -o "/tmp/${GO_TARBALL}" "$GO_DOWNLOAD_URL"

echo "Extracting Go to /tmp..."
tar -C /tmp -xzf "/tmp/${GO_TARBALL}"

echo "Setting environment variables..."
export PATH="$GO_INSTALL_DIR/bin:$GOPATH_DIR/bin:$PATH"
export GOPATH="$GOPATH_DIR"

echo "Go installed successfully!"
echo "PATH=$PATH"
echo "GOPATH=$GOPATH"

echo "Verify installation:"
go version

# -------- SETUP PROJECT --------
echo "Creating project folder at $PROJECT_DIR..."
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

echo "Downloading GUI Go file..."
curl -LO https://raw.githubusercontent.com/libertine89/Balis/Refactor/gui/gui.go

echo "Initializing Go module..."
go mod init "$MODULE_NAME"

echo "Downloading required modules..."
go mod tidy

# -------- FINISH --------
cd "$PROJECT_DIR"
echo "Project setup complete! You are now in $PROJECT_DIR"
echo "You can run your program with:"
echo "go run $GO_FILE_NAME"
