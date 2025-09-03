function mkinitcpio_configuration() {
    print_step "mkinitcpio_configuration()"

    if [ "$KMS" == "true" ]; then
        local MKINITCPIO_KMS_MODULES=""
        case "$DISPLAY_DRIVER" in
            "intel" )
                local MKINITCPIO_KMS_MODULES="i915"
                ;;
            "amdgpu" )
                local MKINITCPIO_KMS_MODULES="amdgpu"
                ;;
            "ati" )
                local MKINITCPIO_KMS_MODULES="radeon"
                ;;
            "nvidia" | "nvidia-lts"  | "nvidia-dkms" )
                local MKINITCPIO_KMS_MODULES="nvidia nvidia_modeset nvidia_uvm nvidia_drm"
                ;;
            "nouveau" )
                local MKINITCPIO_KMS_MODULES="nouveau"
                ;;
        esac
        local MODULES="$MODULES $MKINITCPIO_KMS_MODULES"
    fi
    if [ "$DISPLAY_DRIVER" == "intel" ]; then
        local OPTIONS=""
        if [ "$FASTBOOT" == "true" ]; then
            local OPTIONS="$OPTIONS fastboot=1"
        fi
        if [ "$FRAMEBUFFER_COMPRESSION" == "true" ]; then
            local OPTIONS="$OPTIONS enable_fbc=1"
        fi
        if [ -n "$OPTIONS" ]; then
            echo "options i915 $OPTIONS" > "${MNT_DIR}"/etc/modprobe.d/i915.conf
        fi
    fi

    if [ "$LVM" == "true" ]; then
        HOOKS=${HOOKS//!lvm2/lvm2}
    fi
    if [ "$BOOTLOADER" == "systemd" ]; then
        HOOKS=${HOOKS//!systemd/systemd}
        HOOKS=${HOOKS//!sd-vconsole/sd-vconsole}
        if [ -n "$LUKS_PASSWORD" ]; then
            HOOKS=${HOOKS//!sd-encrypt/sd-encrypt}
        fi
    elif [ "$GPT_AUTOMOUNT" == "true" ] && [ -n "$LUKS_PASSWORD" ]; then
        HOOKS=${HOOKS//!systemd/systemd}
        HOOKS=${HOOKS//!sd-vconsole/sd-vconsole}
        HOOKS=${HOOKS//!sd-encrypt/sd-encrypt}
    else
        HOOKS=${HOOKS//!udev/udev}
        HOOKS=${HOOKS//!usr/usr}
        HOOKS=${HOOKS//!keymap/keymap}
        HOOKS=${HOOKS//!consolefont/consolefont}
        if [ -n "$LUKS_PASSWORD" ]; then
            HOOKS=${HOOKS//!encrypt/encrypt}
        fi
    fi

    HOOKS=$(sanitize_variable "$HOOKS")
    MODULES=$(sanitize_variable "$MODULES")
    arch-chroot "${MNT_DIR}" sed -i "s/^HOOKS=(.*)$/HOOKS=($HOOKS)/" /etc/mkinitcpio.conf
    arch-chroot "${MNT_DIR}" sed -i "s/^MODULES=(.*)/MODULES=($MODULES)/" /etc/mkinitcpio.conf

    if [ "$KERNELS_COMPRESSION" != "" ]; then
        arch-chroot "${MNT_DIR}" sed -i 's/^#COMPRESSION="'"$KERNELS_COMPRESSION"'"/COMPRESSION="'"$KERNELS_COMPRESSION"'"/' /etc/mkinitcpio.conf
    fi

    if [ "$KERNELS_COMPRESSION" == "bzip2" ]; then
        pacman_install "bzip2"
    fi
    if [ "$KERNELS_COMPRESSION" == "lzma" ] || [ "$KERNELS_COMPRESSION" == "xz" ]; then
        pacman_install "xz"
    fi
    if [ "$KERNELS_COMPRESSION" == "lzop" ]; then
        pacman_install "lzop"
    fi
    if [ "$KERNELS_COMPRESSION" == "lz4" ]; then
        pacman_install "lz4"
    fi
    if [ "$KERNELS_COMPRESSION" == "zstd" ]; then
        pacman_install "zstd"
    fi

    if [ "$UKI" == "true" ]; then
        mkdir -p "${MNT_DIR}${ESP_DIRECTORY}/EFI/linux"

        mkinitcpio_preset "linux"
        if [ -n "$KERNELS" ]; then
            IFS=' ' read -r -a KS <<< "$KERNELS"
            for KERNEL in "${KS[@]}"; do
                if [[ "$KERNEL" =~ ^.*-headers$ ]]; then
                    continue
                fi
                mkinitcpio_preset "$KERNEL"
            done
        fi
    fi
}

function mkinitcpio() {
    print_step "mkinitcpio()"

    arch-chroot "${MNT_DIR}" mkinitcpio -P
}

function mkinitcpio_preset() {
    local KERNEL="$1"

    cat <<EOT > "${MNT_DIR}/etc/mkinitcpio.d/$KERNEL.preset"
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-$KERNEL"
ALL_microcode=(/boot/*-ucode.img)

PRESETS=('default' 'fallback')

default_uki="${ESP_DIRECTORY}/EFI/linux/archlinux-$KERNEL.efi"

fallback_uki="${ESP_DIRECTORY}/EFI/linux/archlinux-$KERNEL-fallback.efi"
fallback_options="-S autodetect"
EOT
}

initramfs(){
    execute_step "mkinitcpio_configuration"
    execute_step "mkinitcpio"
}