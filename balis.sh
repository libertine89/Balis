
# shellcheck disable=SC1090,SC2153,SC2034,SC2155,SC2181
# SC1090: Can't follow non-constant source. Use a directive to specify location.
# SC2034: foo appears unused. Verify it or export it.
# SC2155 Declare and assign separately to avoid masking return values
# SC2153: Possible Misspelling: MYVARIABLE may not be assigned. Did you mean MY_VARIABLE?
# SC2181: Check exit code directly with e.g. if mycmd;, not indirectly with $?.
# shellcheck disable=SC2034
# SC2034: foo appears unused. Verify it or export it.

#!/usr/bin/env bash
set -eu

download(){
    local GITHUB_USER="libertine89"
    local BRANCH="Refactor"
    local HASH=""
    local ARTIFACT="balis-${BRANCH}"

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

    if [ -n "$HASH" ]; then                 # Download repo
        curl -sL -o "${ARTIFACT}.zip" "https://github.com/${GITHUB_USER}/Balis/archive/${HASH}.zip"
    else
        curl -sL -o "${ARTIFACT}.zip" "https://github.com/${GITHUB_USER}/Balis/archive/refs/heads/${BRANCH}.zip"
    fi

    bsdtar -x -f "${ARTIFACT}.zip"          # Extraxt
}

copy_files(){
    # The extracted folder will be Balis-HASH or Balis-BRANCH
    EXTRACTED_DIR=$(find . -maxdepth 1 -type d -name "Balis-*")

    cp -R "${EXTRACTED_DIR}/commons.sh" \
        "${EXTRACTED_DIR}/commons.conf" \
        "${EXTRACTED_DIR}/balis.sh" \
        "${EXTRACTED_DIR}/balis.conf" ./

    for dir in init disk_setup system_setup display kernel network initramfs desktop packages end; do
        cp -R "${EXTRACTED_DIR}/${dir}" ./
    done

    # Copy files and configs folders
    if [ -d "${EXTRACTED_DIR}/files" ]; then
        cp -R "${EXTRACTED_DIR}/files" ./
    else
        echo "Warning: files directory does not exist, skipping..."
    fi
    cp -R "${EXTRACTED_DIR}/configs" ./

    chmod +x ./*.sh
    chmod +x */*.sh
    chmod +x configs/*.sh 2>/dev/null || true
}

function main() {
    download                                                                        #
    copy_files                                                                      #
    source init/init.sh
    init                                                                            # Sources,Script,Variable Checks & Logs
    execute_section "Setting up Disks..."  disk_setup                               # Drive, Partitions & Passwords
    execute_section "Setting up System & Users..." system_setup                     # Reflector,Time,Users,Network & FSTAB
    if [ -n "$DISPLAY_DRIVER" ]; then                                               #
    execute_section "Setting up Display Drivers..." display                         # Auto detect for display drivers if not set
    fi                                                                              #                                                                   
    execute_section "Setting up Kernel & Bootloader..." kernel                      # Kernel & Bootloader
    execute_section "Setting up Network and Vagrant..." network                     # Network & Vagrant
    execute_section "Setting mkinitcpio..." initramfs                               # Mkinitcio & Mkinitcpio Config
    execute_section "Setting up Splash, Shell DDM & Desktop Enviroment..." desktop  # Splash Screen,Custom Shell,Display Manager & Desktop Enviroment
    if [ "$PACKAGES_INSTALL" == "true" ]; then                                      #
    execute_section "Installing Packages" packages                                  # Pacman, Flatpak, SDK & AUR Packages,Provision & Systemd Files
    fi                                                                              #
    execute_section "Finishing up Script & Logs" end                                # Copy Logs & End
}

main "$@"

##### TO DO #####
# disk setup refactor
# end refactor
# initramfs refactor
# kernel and bootloader refactor
# packages refactor
# system setup refactor
# commons refactor
# remove ascinema features
# remove unused commons functions
# merge commons.conf into balis.conf
# comment all of balis.conf
# readme & gnu license