
function source_files() {

    RED='\033[0;91m'
    GREEN='\033[1;32m'
    WHITE_BOLD='\033[1;97m'
    BLUE='\033[1;34m'
    NC='\033[0m'

    step_name="Initializing Script..."
    step_length=${#step_name}
    total_length=$((step_length + 4))  # 4 accounts for brackets and spaces
    line=$(printf '=%.0s' $(seq 1 $total_length))

    echo -e "${GREEN}>>>${WHITE_BOLD}${line}${GREEN}<<<${NC}"
    echo -e "${GREEN}>>>${WHITE_BOLD}  $step_name  ${GREEN}<<<${NC}"
    echo -e "${GREEN}>>>${WHITE_BOLD}${line}${GREEN}<<<${NC}"

    echo ""
    echo -e "${BLUE}    ---> Sourcing Files...${NC}"
    echo ""

    # Get parent directory of script
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "$SCRIPT_DIR/init/init.conf"     # Source literal because holds scipt/conf array. 
    source "$SCRIPT_DIR/balis.conf"         # Source literal because variables held for other confs here
    source "$COMMONS_FILE"                  #SC1090
    source "$COMMONS_CONF_FILE"

    # Source all confs except init. because .sh called in main() and .conf above
#    for conf in "${CONF[@]}"; do
#        source "$SCRIPT_DIR/$conf/$conf.conf"
#    done

    loadkeys "$KEYS"

    echo ""
    echo -e "${BLUE}    ---> Scripts Initialized.${NC}"
    echo ""
}

function sanitize_variables() {
    print_step "Sanitizing Variables..."
    DEVICE=$(sanitize_variable "$DEVICE")
    PARTITION_MODE=$(sanitize_variable "$PARTITION_MODE")
    PARTITION_CUSTOM_PARTED_UEFI=$(sanitize_variable "$PARTITION_CUSTOM_PARTED_UEFI")
    PARTITION_CUSTOM_PARTED_BIOS=$(sanitize_variable "$PARTITION_CUSTOM_PARTED_BIOS")
    FILE_SYSTEM_TYPE=$(sanitize_variable "$FILE_SYSTEM_TYPE")
    SWAP_SIZE=$(sanitize_variable "$SWAP_SIZE")
    KERNELS=$(sanitize_variable "$KERNELS")
    KERNELS_COMPRESSION=$(sanitize_variable "$KERNELS_COMPRESSION")
    KERNELS_PARAMETERS=$(sanitize_variable "$KERNELS_PARAMETERS")
    AUR_PACKAGE=$(sanitize_variable "$AUR_PACKAGE")
    DISPLAY_DRIVER=$(sanitize_variable "$DISPLAY_DRIVER")
    DISPLAY_DRIVER_HARDWARE_VIDEO_ACCELERATION_INTEL=$(sanitize_variable "$DISPLAY_DRIVER_HARDWARE_VIDEO_ACCELERATION_INTEL")
    SYSTEMD_HOMED_STORAGE=$(sanitize_variable "$SYSTEMD_HOMED_STORAGE")
    SYSTEMD_HOMED_STORAGE_LUKS_TYPE=$(sanitize_variable "$SYSTEMD_HOMED_STORAGE_LUKS_TYPE")
    BOOTLOADER=$(sanitize_variable "$BOOTLOADER")
    CUSTOM_SHELL=$(sanitize_variable "$CUSTOM_SHELL")
    DESKTOP_ENVIRONMENT=$(sanitize_variable "$DESKTOP_ENVIRONMENT")
    DISPLAY_MANAGER=$(sanitize_variable "$DISPLAY_MANAGER")
    SYSTEMD_UNITS=$(sanitize_variable "$SYSTEMD_UNITS")
    SYSTEMD_BOOT_TIMEOUT=$(sanitize_variable "$SYSTEMD_BOOT_TIMEOUT")
    SPLASH_SCREEN_INSTALL=$(sanitize_variable "$SPLASH_SCREEN_INSTALL")
    SPLASH_SCREEN_THEME=$(sanitize_variable "$SPLASH_SCREEN_THEME")

    for I in "${BTRFS_SUBVOLUMES_MOUNTPOINTS[@]}"; do
        IFS=',' read -ra SUBVOLUME <<< "$I"
        if [ "${SUBVOLUME[0]}" == "root" ]; then
            BTRFS_SUBVOLUME_ROOT=("${SUBVOLUME[@]}")
        elif [ "${SUBVOLUME[0]}" == "swap" ]; then
            BTRFS_SUBVOLUME_SWAP=("${SUBVOLUME[@]}")
        fi
    done
    ### --- ###

    for I in "${PARTITION_MOUNT_POINTS[@]}"; do #SC2153
        IFS='=' read -ra PARTITION_MOUNT_POINT <<< "$I"
        if [ "${PARTITION_MOUNT_POINT[1]}" == "/boot" ]; then
            PARTITION_BOOT_NUMBER="${PARTITION_MOUNT_POINT[0]}"
        elif [ "${PARTITION_MOUNT_POINT[1]}" == "/" ]; then
            PARTITION_ROOT_NUMBER="${PARTITION_MOUNT_POINT[0]}"
        fi
    done
    ### --- ###
}

function check_variables() {
    print_step "Checking Variables & Arrays..."

    #### Values ####
    check_variables_value "KEYS" "$KEYS"
    check_variables_value "DEVICE" "$DEVICE"
    check_variables_value "PARTITION_BOOT_NUMBER" "$PARTITION_BOOT_NUMBER"
    check_variables_value "PARTITION_ROOT_NUMBER" "$PARTITION_ROOT_NUMBER"
    check_variables_value "TIMEZONE" "$TIMEZONE"
    check_variables_value "LOCALES" "$LOCALES"
    check_variables_value "LOCALE_CONF" "$LOCALE_CONF"
    check_variables_value "KEYMAP" "$KEYMAP"
    check_variables_value "HOSTNAME" "$HOSTNAME"
    check_variables_value "USER_NAME" "$USER_NAME"
    check_variables_value "USER_PASSWORD" "$USER_PASSWORD"
    check_variables_value "PING_HOSTNAME" "$PING_HOSTNAME"
    check_variables_value "PACMAN_MIRROR" "$PACMAN_MIRROR"
    check_variables_value "HOOKS" "$HOOKS"

    #### Equals ####
    check_variables_equals "LUKS_PASSWORD" "LUKS_PASSWORD_RETYPE" "$LUKS_PASSWORD" "$LUKS_PASSWORD_RETYPE"
    check_variables_equals "WIFI_KEY" "WIFI_KEY_RETYPE" "$WIFI_KEY" "$WIFI_KEY_RETYPE"
    check_variables_equals "ROOT_PASSWORD" "ROOT_PASSWORD_RETYPE" "$ROOT_PASSWORD" "$ROOT_PASSWORD_RETYPE"
    check_variables_equals "USER_PASSWORD" "USER_PASSWORD_RETYPE" "$USER_PASSWORD" "$USER_PASSWORD_RETYPE"

    #### Size ####
    check_variables_size "BTRFS_SUBVOLUME_ROOT" ${#BTRFS_SUBVOLUME_ROOT[@]} 3

    #### List ####
    check_variables_list "FILE_SYSTEM_TYPE" "$FILE_SYSTEM_TYPE" "ext4 btrfs xfs f2fs reiserfs" "true" "true"
    check_variables_list "BTRFS_SUBVOLUME_ROOT" "${BTRFS_SUBVOLUME_ROOT[2]}" "/" "true" "true"
    check_variables_list "PARTITION_MODE" "$PARTITION_MODE" "auto custom manual" "true" "true"
    check_variables_list "KERNELS" "$KERNELS" "linux-lts linux-lts-headers linux-hardened linux-hardened-headers linux-zen linux-zen-headers" "false" "false"
    check_variables_list "KERNELS_COMPRESSION" "$KERNELS_COMPRESSION" "gzip bzip2 lzma xz lzop lz4 zstd" "false" "true"
    check_variables_list "AUR_PACKAGE" "$AUR_PACKAGE" "paru-bin yay-bin paru yay aurman" "true" "true"
    check_variables_list "DISPLAY_DRIVER" "$DISPLAY_DRIVER" "auto intel amdgpu ati nvidia nvidia-lts nvidia-dkms nvidia-470xx-dkms nvidia-390xx-dkms nvidia-340xx-dkms nouveau" "false" "true"
    check_variables_list "DISPLAY_DRIVER_HARDWARE_VIDEO_ACCELERATION_INTEL" "$DISPLAY_DRIVER_HARDWARE_VIDEO_ACCELERATION_INTEL" "intel-media-driver libva-intel-driver" "false" "true"
    check_variables_list "SYSTEMD_HOMED_STORAGE" "$SYSTEMD_HOMED_STORAGE" "auto luks subvolume directory fscrypt cifs" "true" "true"
    check_variables_list "SYSTEMD_HOMED_STORAGE_LUKS_TYPE" "$SYSTEMD_HOMED_STORAGE_LUKS_TYPE" "auto ext4 btrfs xfs" "true" "true"
    check_variables_list "BOOTLOADER" "$BOOTLOADER" "auto grub refind systemd efistub" "true" "true"
    check_variables_list "CUSTOM_SHELL" "$CUSTOM_SHELL" "bash zsh dash fish" "true" "true"
    check_variables_list "DESKTOP_ENVIRONMENT" "$DESKTOP_ENVIRONMENT" "hyprland gnome kde xfce mate cinnamon lxde i3-wm i3-gaps deepin budgie bspwm awesome qtile openbox leftwm dusk" "false" "true"
    check_variables_list "DISPLAY_MANAGER" "$DISPLAY_MANAGER" "auto gdm sddm lightdm lxdm" "true" "true"
    check_variables_list "SPLASH_SCREEN_THEME" "$SPLASH_SCREEN_THEME" "bgrt fade-in glow script solar spinfinity text tribar" "true" "falseS"

    #### Boolean ####
    check_variables_boolean "LOG_TRACE" "$LOG_TRACE"
    check_variables_boolean "LOG_FILE" "$LOG_FILE"
    check_variables_boolean "DEVICE_TRIM" "$DEVICE_TRIM"
    check_variables_boolean "LVM" "$LVM"
    check_variables_boolean "GPT_AUTOMOUNT" "$GPT_AUTOMOUNT"
    check_variables_boolean "REFLECTOR" "$REFLECTOR"
    check_variables_boolean "PACMAN_PARALLEL_DOWNLOADS" "$PACMAN_PARALLEL_DOWNLOADS"
    check_variables_boolean "KMS" "$KMS"
    check_variables_boolean "FASTBOOT" "$FASTBOOT"
    check_variables_boolean "FRAMEBUFFER_COMPRESSION" "$FRAMEBUFFER_COMPRESSION"
    check_variables_boolean "DISPLAY_DRIVER_DDX" "$DISPLAY_DRIVER_DDX"
    check_variables_boolean "DISPLAY_DRIVER_HARDWARE_VIDEO_ACCELERATION" "$DISPLAY_DRIVER_HARDWARE_VIDEO_ACCELERATION"
    check_variables_boolean "SYSTEMD_HOMED" "$SYSTEMD_HOMED"
    check_variables_boolean "UKI" "$UKI"
    check_variables_boolean "SECURE_BOOT" "$SECURE_BOOT"
    check_variables_boolean "PACKAGES_MULTILIB" "$PACKAGES_MULTILIB"
    check_variables_boolean "PACKAGES_INSTALL" "$PACKAGES_INSTALL"
    check_variables_boolean "PROVISION" "$PROVISION"
    #check_variables_boolean "VAGRANT" "$VAGRANT"
    check_variables_boolean "REBOOT" "$REBOOT"
    check_variables_boolean "SPLASH_SCREEN_INSTALL" "$SPLASH_SCREEN_INSTALL"

    #### Conditional ####
    if [ "$DEVICE" == "auto" ]; then
        local DEVICE_BOOT=$(lsblk -oMOUNTPOINT,PKNAME -P -M | grep 'MOUNTPOINT="/run/archiso/bootmnt"' | sed 's/.*PKNAME="\(.*\)".*/\1/') #SC2155
        if [ -n "$DEVICE_BOOT" ]; then
            local DEVICE_BOOT="/dev/$DEVICE_BOOT"
        fi
        local DEVICE_DETECTED="false"
        if [ -e "/dev/sda" ] && [ "$DEVICE_BOOT" != "/dev/sda" ]; then
            if [ "$DEVICE_DETECTED" == "true" ]; then
                echo "Auto device is ambigous, detected $DEVICE and /dev/sda."
                exit 1
            fi
            DEVICE_DETECTED="true"
            DEVICE_SDA="true"
            DEVICE="/dev/sda"
        fi
        if [ -e "/dev/nvme0n1" ] && [ "$DEVICE_BOOT" != "/dev/nvme0n1" ]; then
            if [ "$DEVICE_DETECTED" == "true" ]; then
                echo "Auto device is ambigous, detected $DEVICE and /dev/nvme0n1."
                exit 1
            fi
            DEVICE_DETECTED="true"
            DEVICE_NVME="true"
            DEVICE="/dev/nvme0n1"
        fi
        if [ -e "/dev/vda" ] && [ "$DEVICE_BOOT" != "/dev/vda" ]; then
            if [ "$DEVICE_DETECTED" == "true" ]; then
                echo "Auto device is ambigous, detected $DEVICE and /dev/vda."
                exit 1
            fi
            DEVICE_DETECTED="true"
            DEVICE_VDA="true"
            DEVICE="/dev/vda"
        fi
        if [ -e "/dev/mmcblk0" ] && [ "$DEVICE_BOOT" != "/dev/mmcblk0" ]; then
            if [ "$DEVICE_DETECTED" == "true" ]; then
                echo "Auto device is ambigous, detected $DEVICE and /dev/mmcblk0."
                exit 1
            fi
            DEVICE_DETECTED="true"
            DEVICE_MMC="true"
            DEVICE="/dev/mmcblk0"
        fi
    fi
#        declare -A DEVICE_MAP=(
#            ["/dev/sda"]="DEVICE_SDA"
#            ["/dev/nvme0n1"]="DEVICE_NVME"
#            ["/dev/vda"]="DEVICE_VDA"
#            ["/dev/mmcblk0"]="DEVICE_MMC"
#        )
#
#        for device in "${!DEVICE_MAP[@]}"; do
#            if [ -e "$device" ] && [ "$DEVICE_BOOT" != "$device" ]; then
#                if [ "$DEVICE_DETECTED" == "true" ]; then
#                    echo "Auto device is ambiguous, detected $DEVICE and $device."
#                    exit 1
#                fi
#                DEVICE_DETECTED="true"
#                declare -g "${DEVICE_MAP[$device]}=true"   # Dynamically set the variable DEVICE_XXXX to true
#                DEVICE="$device"
 #           fi
 #       done
 #   fi
    ### --- ###

    if [ -n "$SWAP_SIZE" ]; then
        check_variables_size "BTRFS_SUBVOLUME_SWAP" ${#BTRFS_SUBVOLUME_SWAP[@]} 3
    fi
    ### --- ###

    for I in "${BTRFS_SUBVOLUMES_MOUNTPOINTS[@]}"; do
        IFS=',' read -ra SUBVOLUME <<< "$I"
        check_variables_size "SUBVOLUME" ${#SUBVOLUME[@]} 3
    done
    ### --- ###

    if [ "$GPT_AUTOMOUNT" == "true" ] && [ "$LVM" == "true" ]; then
        echo "LVM not possible in combination with GPT partition automounting."
        exit 1
    fi
    ### --- ###

    if [ "$SYSTEMD_HOMED" == "true" ]; then
        if [ "$SYSTEMD_HOMED_STORAGE" == "fscrypt" ]; then
            check_variables_list "FILE_SYSTEM_TYPE" "$FILE_SYSTEM_TYPE" "ext4 f2fs" "true" "true"
        fi
        if [ "$SYSTEMD_HOMED_STORAGE" == "cifs" ]; then
            check_variables_value "SYSTEMD_HOMED_CIFS[\"domain]\"" "${SYSTEMD_HOMED_CIFS_DOMAIN["domain"]}"
            check_variables_value "SYSTEMD_HOMED_CIFS[\"service\"]" "${SYSTEMD_HOMED_CIFS_SERVICE["size"]}"
        fi
    fi
    ### --- ###
}

function warning() {
    echo -e "${BLUE}Welcome to Arch Linux Install Script${NC}"
    echo ""
    echo -e "${RED}Warning"'!'"${NC}"
    echo -e "${RED}This script can delete all partitions of the persistent${NC}"
    echo -e "${RED}storage and continuing all your data can be lost.${NC}"
    echo ""
    echo -e "Install device: $DEVICE."
    echo -e "Mount points: ${PARTITION_MOUNT_POINTS[*]}."
    echo ""
    read -r -p "Do you want to continue? [Y/N] " yn

    case $yn in
        [Yy]* )
            ;;
        [Nn]* )
            exit 0
            ;;
        * )
            exit 0
            ;;
    esac
}

function init_logs() {
    print_step "Initializing Logs..."
    init_log_trace "$LOG_TRACE"
    init_log_file "$LOG_FILE" "$BALIS_LOG_FILE"
}

function facts() {
    print_step "Checking System Facts..."
    facts_commons

    if echo "$DEVICE" | grep -q "^/dev/sd[a-z]"; then
        DEVICE_SDA="true" #SC2034
    elif echo "$DEVICE" | grep -q "^/dev/nvme"; then
        DEVICE_NVME="true"
    elif echo "$DEVICE" | grep -q "^/dev/vd[a-z]"; then
        DEVICE_VDA="true"
    elif echo "$DEVICE" | grep -q "^/dev/mmc"; then
        DEVICE_MMC="true"
    fi
}

function checks() {
    print_step "Resolving Automatic Variable Assignment()"

    if [ "$DISPLAY_DRIVER" == "auto" ]; then
        case "$GPU_VENDOR" in
            "intel" )
                DISPLAY_DRIVER="intel"
                ;;
            "amd" )
                DISPLAY_DRIVER="amdgpu"
                ;;
            "nvidia" )
                DISPLAY_DRIVER="nvidia"
                ;;
        esac
    fi
    ### --- ###

    if [ "$BOOTLOADER" == "auto" ]; then
        if [ "$BIOS_TYPE" == "uefi" ]; then
            BOOTLOADER="systemd"
        elif [ "$BIOS_TYPE" == "bios" ]; then
            BOOTLOADER="grub"
        fi
    fi
    ### --- ###

    case "$AUR_PACKAGE" in
        "aurman" )
            AUR_COMMAND="aurman"
            ;;
        "yay" )
            AUR_COMMAND="yay"
            ;;
        "paru" )
            AUR_COMMAND="paru"
            ;;
        "yay-bin" )
            AUR_COMMAND="yay"
            ;;
        "paru-bin" | *)
            AUR_COMMAND="paru"
            ;;
    esac
    ### --- ###
    
    if [ "$BIOS_TYPE" == "bios" ]; then
        check_variables_list "BOOTLOADER" "$BOOTLOADER" "grub" "true" "true"
    fi
    ### --- ###

    if [ "$SECURE_BOOT" == "true" ]; then
        check_variables_list "BOOTLOADER" "$BOOTLOADER" "grub refind systemd" "true" "true"
    fi
    ### --- ###
}


init(){
    local START_TIMESTAMP=$(date -u +"%F %T")
    source_files
    execute_step "sanitize_variables"
    execute_step "check_variables"
    execute_step "warning"
    execute_step "init_logs"
    execute_step "facts"
    execute_step "checks"
}