
function prepare_partition() {
    set +e
    print_step "prepare_partition()"
    if mountpoint -q "${MNT_DIR}"/boot; then
        umount "${MNT_DIR}"/boot
    fi
    if mountpoint -q "${MNT_DIR}"; then
        umount "${MNT_DIR}"
    fi
    if lvs "$LVM_VOLUME_GROUP"-"$LVM_VOLUME_LOGICAL"; then
        lvchange -an "$LVM_VOLUME_GROUP/$LVM_VOLUME_LOGICAL"
    fi
    if vgs "$LVM_VOLUME_GROUP"; then
        vgchange -an "$LVM_VOLUME_GROUP"
    fi
    if [ -e "/dev/mapper/$LUKS_DEVICE_NAME" ]; then
        if cryptsetup status "$LUKS_DEVICE_NAME "| grep -qi "is active"; then
            cryptsetup close "$LUKS_DEVICE_NAME"
        fi
    fi
    set -e
}

function ask_passwords() {
    if [ "$LUKS_PASSWORD" == "ask" ]; then
        ask_password "LUKS" "LUKS_PASSWORD"
    fi

    if [ -n "$WIFI_INTERFACE" ] && [ "$WIFI_KEY" == "ask" ]; then
        ask_password "WIFI" "WIFI_KEY"
    fi

    if [ "$ROOT_PASSWORD" == "ask" ]; then
        ask_password "root" "ROOT_PASSWORD"
    fi

    if [ "$USER_PASSWORD" == "ask" ]; then
        ask_password "user" "USER_PASSWORD"
    fi

    for I in "${!ADDITIONAL_USERS[@]}"; do
        local VALUE=${ADDITIONAL_USERS[$I]}
        local S=()
        IFS='=' read -ra S <<< "$VALUE"
        local USER=${S[0]}
        local PASSWORD=${S[1]}
        local PASSWORD_RETYPE=""

        if [ "$PASSWORD" == "ask" ]; then
            local PASSWORD_TYPED="false"
            while [ "$PASSWORD_TYPED" != "true" ]; do
                read -r -sp "Type user ($USER) password: " PASSWORD
                echo ""
                read -r -sp "Retype user ($USER) password: " PASSWORD_RETYPE
                echo ""
                if [ "$PASSWORD" == "$PASSWORD_RETYPE" ]; then
                    local PASSWORD_TYPED="true"
                    ADDITIONAL_USERS[I]="$USER=$PASSWORD"
                else
                    echo "User ($USER) password don't match. Please, type again."
                fi
            done
        fi
    done
}

function partition() {
    print_step "partition()"

    partprobe -s "$DEVICE"

    # setup
    partition_setup

    # partition
    if [ "$PARTITION_MODE" == "auto" ]; then
        sgdisk --zap-all "$DEVICE"
        sgdisk -o "$DEVICE"
        wipefs -a -f "$DEVICE"
        partprobe -s "$DEVICE"
    fi
    if [ "$PARTITION_MODE" == "auto" ] || [ "$PARTITION_MODE" == "custom" ]; then
        if [ "$BIOS_TYPE" == "uefi" ]; then
            parted -s "$DEVICE" "$PARTITION_PARTED_UEFI"
            if [ -n "$LUKS_PASSWORD" ]; then
                sgdisk -t="$PARTITION_ROOT_NUMBER":8304 "$DEVICE"
            elif [ "$LVM" == "true" ]; then
                sgdisk -t="$PARTITION_ROOT_NUMBER":8e00 "$DEVICE"
            fi
        fi

        if [ "$BIOS_TYPE" == "bios" ]; then
            parted -s "$DEVICE" "$PARTITION_PARTED_BIOS"
        fi

        partprobe -s "$DEVICE"
    fi

    # luks and lvm
    if [ -n "$LUKS_PASSWORD" ]; then
        echo -n "$LUKS_PASSWORD" | cryptsetup --key-size=512 --key-file=- luksFormat --type luks2 "$PARTITION_ROOT"
        echo -n "$LUKS_PASSWORD" | cryptsetup --key-file=- open "$PARTITION_ROOT" "$LUKS_DEVICE_NAME"
        sleep 5
    fi

    if [ "$LVM" == "true" ]; then
        if [ -n "$LUKS_PASSWORD" ]; then
            DEVICE_LVM="/dev/mapper/$LUKS_DEVICE_NAME"
        else
            DEVICE_LVM="$DEVICE_ROOT"
        fi

        if [ "$PARTITION_MODE" == "auto" ]; then
            set +e
            if lvs "$LVM_VOLUME_GROUP"-"$LVM_VOLUME_LOGICAL"; then
                lvremove -y "$LVM_VOLUME_GROUP"/"$LVM_VOLUME_LOGICAL"
            fi
            if vgs "$LVM_VOLUME_GROUP"; then
                vgremove -y "$LVM_VOLUME_GROUP"
            fi
            if pvs "$DEVICE_LVM"; then
                pvremove -y "$DEVICE_LVM"
            fi
            set -e

            pvcreate -y "$DEVICE_LVM"
            vgcreate -y "$LVM_VOLUME_GROUP" "$DEVICE_LVM"
            lvcreate -y -l 100%FREE -n "$LVM_VOLUME_LOGICAL" "$LVM_VOLUME_GROUP"
        fi
    fi

    if [ -n "$LUKS_PASSWORD" ]; then
        DEVICE_ROOT="/dev/mapper/$LUKS_DEVICE_NAME"
    fi
    if [ "$LVM" == "true" ]; then
        DEVICE_ROOT="/dev/mapper/$LVM_VOLUME_GROUP-$LVM_VOLUME_LOGICAL"
    fi

    # format
    if [ "$PARTITION_MODE" != "manual" ]; then
        # Delete patition filesystem in case is reinstalling in an already existing system
        # Not fail on error
        wipefs -a -f "$PARTITION_BOOT" || true
        wipefs -a -f "$DEVICE_ROOT" || true

        ## boot
        if [ "$BIOS_TYPE" == "uefi" ]; then
            mkfs.fat -n ESP -F32 "$PARTITION_BOOT"
        fi
        if [ "$BIOS_TYPE" == "bios" ]; then
            mkfs.ext4 -L boot "$PARTITION_BOOT"
        fi
        ## root
        if [ "$FILE_SYSTEM_TYPE" == "reiserfs" ]; then
            mkfs."$FILE_SYSTEM_TYPE" -f -l root "$DEVICE_ROOT"
        elif [ "$FILE_SYSTEM_TYPE" == "f2fs" ]; then
            mkfs."$FILE_SYSTEM_TYPE" -l root "$DEVICE_ROOT"
        else
            mkfs."$FILE_SYSTEM_TYPE" -L root "$DEVICE_ROOT"
        fi
        ## mountpoint
        for I in "${PARTITION_MOUNT_POINTS[@]}"; do
            if [[ "$I" =~ ^!.* ]]; then
                continue
            fi
            IFS='=' read -ra PARTITION_MOUNT_POINT <<< "$I"
            if [ "${PARTITION_MOUNT_POINT[1]}" == "/boot" ] || [ "${PARTITION_MOUNT_POINT[1]}" == "/" ]; then
                continue
            fi
            local PARTITION_DEVICE="$(partition_device "$DEVICE" "${PARTITION_MOUNT_POINT[0]}")"
            if [ "$FILE_SYSTEM_TYPE" == "reiserfs" ]; then
                mkfs."$FILE_SYSTEM_TYPE" -f "$PARTITION_DEVICE"
            elif [ "$FILE_SYSTEM_TYPE" == "f2fs" ]; then
                mkfs."$FILE_SYSTEM_TYPE" "$PARTITION_DEVICE"
            else
                mkfs."$FILE_SYSTEM_TYPE" "$PARTITION_DEVICE"
            fi
        done
    fi

    # options
    partition_options

    # create
    if [ "$FILE_SYSTEM_TYPE" == "btrfs" ]; then
        # create subvolumes
        mount -o "$PARTITION_OPTIONS" "$DEVICE_ROOT" "${MNT_DIR}"
        for I in "${BTRFS_SUBVOLUMES_MOUNTPOINTS[@]}"; do
            IFS=',' read -ra SUBVOLUME <<< "$I"
            if [ "${SUBVOLUME[0]}" == "swap" ] && [ -z "$SWAP_SIZE" ]; then
                continue
            fi
            btrfs subvolume create "${MNT_DIR}/${SUBVOLUME[1]}"
        done
        umount "${MNT_DIR}"
    fi

    # mount
    partition_mount

    # swap
    if [ -n "$SWAP_SIZE" ]; then
        if [ "$FILE_SYSTEM_TYPE" == "btrfs" ]; then
            SWAPFILE="${BTRFS_SUBVOLUME_SWAP[2]}$SWAPFILE"
            chattr +C "${MNT_DIR}"
            btrfs filesystem mkswapfile --size "${SWAP_SIZE}m" --uuid clear "${MNT_DIR}${SWAPFILE}"
            swapon "${MNT_DIR}${SWAPFILE}"
        else
            dd if=/dev/zero of="${MNT_DIR}$SWAPFILE" bs=1M count="$SWAP_SIZE" status=progress
            chmod 600 "${MNT_DIR}${SWAPFILE}"
            mkswap "${MNT_DIR}${SWAPFILE}"
        fi
    fi

    # set variables
    BOOT_DIRECTORY=/boot
    ESP_DIRECTORY=/boot
    UUID_BOOT=$(blkid -s UUID -o value "$PARTITION_BOOT")
    UUID_ROOT=$(blkid -s UUID -o value "$PARTITION_ROOT")
    PARTUUID_BOOT=$(blkid -s PARTUUID -o value "$PARTITION_BOOT")
    PARTUUID_ROOT=$(blkid -s PARTUUID -o value "$PARTITION_ROOT")
}

disk_setup() {
    execute_step "prepare_partition"
    execute_step "ask_passwords"
    execute_step "partition"

}

