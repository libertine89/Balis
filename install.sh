#!/usr/bin/env bash
#shellcheck disable=SC2034
#SC2034: foo appears unused. Verify it or export it.
set -eu

# Arch Linux Install Script (alis) installs unattended, automated
# and customized Arch Linux system.
# Copyright (C) 2022 picodotdev

GITHUB_USER="libertine89"
BRANCH="Refactor"
HASH=""
ARTIFACT="balis-${BRANCH}"

while getopts "b:h:u:" arg; do
  case ${arg} in
    b)
      BRANCH="${OPTARG}"
      ARTIFACT="Balis-${BRANCH}"
      ;;
    h)
      HASH="${OPTARG}"
      ARTIFACT="Balis-${HASH}"
      ;;
    u)
      GITHUB_USER=${OPTARG}
      ;;
    ?)
      echo "Invalid option: -${OPTARG}."
      exit 1
      ;;
  esac
done

set -o xtrace

# Download repo
if [ -n "$HASH" ]; then
  curl -sL -o "${ARTIFACT}.zip" "https://github.com/${GITHUB_USER}/Balis/archive/${HASH}.zip"
else
  curl -sL -o "${ARTIFACT}.zip" "https://github.com/${GITHUB_USER}/Balis/archive/refs/heads/${BRANCH}.zip"
fi

# Extract
bsdtar -x -f "${ARTIFACT}.zip"

# The extracted folder will be Balis-HASH or Balis-BRANCH
EXTRACTED_DIR=$(find . -maxdepth 1 -type d -name "Balis-*")

# Copy root files
cp -R "${EXTRACTED_DIR}/commons.sh" \
      "${EXTRACTED_DIR}/commons.conf" \
      "${EXTRACTED_DIR}/balis.sh" \
      "${EXTRACTED_DIR}/balis.conf" ./

# Copy subfolder scripts and configs
for dir in init disk_setup system_setup display kernel network initramfs desktop packages end; do
  cp -R "${EXTRACTED_DIR}/${dir}" ./
done

# Copy files and configs folders
cp -R "${EXTRACTED_DIR}/files" ./
cp -R "${EXTRACTED_DIR}/configs" ./

# Make scripts executable
chmod +x ./*.sh
chmod +x */*.sh
chmod +x configs/*.sh 2>/dev/null || true

