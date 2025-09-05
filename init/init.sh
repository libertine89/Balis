
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
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" # parent directory

    source "$SCRIPT_DIR/balis.conf"         # Source literal because variables held for other confs here

    source "$COMMONS_FILE"                  #SC1090
    source "$COMMONS_CONF_FILE"

    #loadkeys "$KEYS"

    echo ""
    echo -e "${BLUE}   ---> Scripts Initialized.${NC}"
    echo ""
}

function sanitize_variables() {
    print_step "Sanitizing Variables..."

    # VARIABLES in source
    source "$SCRIPT_DIR/init/init-variables-array.conf"
    for var_name in "${VARIABLES[@]}"; do
        variable=$(sanitize_variable "${!var_name}")
        printf -v "$var_name" '%s' "$variable"
    done

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

    #### VALUES,LIST,EQUAL,BOOLEAN in source
    source "$SCRIPT_DIR/init/init-arrays.conf"

    #### Values ####
    for var_name in "${VALUES[@]}"; do
        check_variables_value "$var_name" "${!var_name}"
    done

    #### List ####
    for variable in "${LIST[@]}"; do
        IFS=':' read -r name value allowed required single <<< "$variable"
        check_variables_list "$name" "$value" "$allowed" "$required" "$single"
    done
        check_variables_list "BTRFS_SUBVOLUME_ROOT" "${BTRFS_SUBVOLUME_ROOT[2]}" "/" "true" "true"

    #### Equals ####
    for variable in "${EQUAL[@]}"; do
        IFS=':' read -r keyname1 keyname2 key1 key2 <<<"$variable"
        check_variables_equals "$keyname1" "$keyname2" "$key1" "$key2"
    done

    #### Size ####
    check_variables_size "BTRFS_SUBVOLUME_ROOT" ${#BTRFS_SUBVOLUME_ROOT[@]} 3

    #### Boolean ####
    for var_name in "${BOOLEAN[@]}"; do
        check_variables_boolean "$var_name" "${!var_name}"
    done

    #### Conditional ####
    if [ "$DEVICE" == "auto" ]; then
        local DEVICE_BOOT=$(lsblk -oMOUNTPOINT,PKNAME -P -M | grep 'MOUNTPOINT="/run/archiso/bootmnt"' | sed 's/.*PKNAME="\(.*\)".*/\1/') #SC2155
        if [ -n "$DEVICE_BOOT" ]; then
            local DEVICE_BOOT="/dev/$DEVICE_BOOT"
        fi
        local DEVICE_DETECTED="false"

        declare -A DEVICE_MAP=(
            ["/dev/sda"]="DEVICE_SDA"
            ["/dev/nvme0n1"]="DEVICE_NVME"
            ["/dev/vda"]="DEVICE_VDA"
            ["/dev/mmcblk0"]="DEVICE_MMC"
        )

        for device in "${!DEVICE_MAP[@]}"; do
            if [ -e "$device" ] && [ "$DEVICE_BOOT" != "$device" ]; then
                if [ "$DEVICE_DETECTED" == "true" ]; then
                    echo "Auto device is ambiguous, detected $DEVICE and $device."
                    exit 1
                fi
                DEVICE_DETECTED="true"
                declare -g "${DEVICE_MAP[$device]}=true"   # Dynamically set the variable DEVICE_XXXX to true
                DEVICE="$device"
            fi
        done
    fi
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
    echo " ${NC}"
    echo -e "${GREEN}"
cat <<"EOF"
   ____    __
  / __/__ / /___ _____
 _\ \/ -_) __/ // / _ \
/___/\__/\__/\_,_/ .__/
                /_/

EOF
    echo " ${NC}"
    echo -e "${RED}Warning"'!'"${NC}"
    echo -e "${RED}This script will delete all partitions of the persistent${NC}"
    echo -e "${RED}storage. If you continue all your data will be erased.${NC}"
    echo ""
    echo -e "${WHITE_BOLD}Install device: $DEVICE.${NC}"
    echo -e "${WHITE_BOLD}Mount points: ${PARTITION_MOUNT_POINTS[*]}.${NC}"
    echo ""
    read -r -p "Do you wish to continue? [Y/N] " yn

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
        echo "GPU=$GPU_VENDOR"
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
    START_TIMESTAMP=$(date -u +"%F %T")
    source_files
    execute_step "sanitize_variables"
    execute_step "check_variables"
    execute_step "warning"
    execute_step "init_logs"
    execute_step "facts"
    execute_step "checks"
}