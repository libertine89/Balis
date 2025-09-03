function kernels() {
    print_step "Installing Kernel"

    pacman_install "linux-headers"
    if [ -n "$KERNELS" ]; then
        pacman_install "$KERNELS"
    fi
}


function bootloader() {
    print_step "Installing Bootloader"

    BOOTLOADER_ALLOW_DISCARDS=""

    if [ "$VIRTUALBOX" != "true" ] && [ "$VMWARE" != "true" ]; then
        if [ "$CPU_VENDOR" == "intel" ]; then
            pacman_install "intel-ucode"
        fi
        if [ "$CPU_VENDOR" == "amd" ]; then
            pacman_install "amd-ucode"
        fi
    fi
    if [ "$LVM" == "true" ] || [ -n "$LUKS_PASSWORD" ]; then
        CMDLINE_LINUX_ROOT="root=$DEVICE_ROOT"
    else
        CMDLINE_LINUX_ROOT="root=UUID=$UUID_ROOT"
    fi
    if [ -n "$LUKS_PASSWORD" ]; then
        case "$BOOTLOADER" in
            "grub" | "refind" | "efistub" )
                if [ "$DEVICE_TRIM" == "true" ]; then
                    BOOTLOADER_ALLOW_DISCARDS=":allow-discards"
                fi
                CMDLINE_LINUX="cryptdevice=UUID=$UUID_ROOT:$LUKS_DEVICE_NAME$BOOTLOADER_ALLOW_DISCARDS"
                ;;
            "systemd" )
                if [ "$DEVICE_TRIM" == "true" ]; then
                    BOOTLOADER_ALLOW_DISCARDS=" rd.luks.options=discard"
                fi
                CMDLINE_LINUX="rd.luks.name=$UUID_ROOT=$LUKS_DEVICE_NAME$BOOTLOADER_ALLOW_DISCARDS"
                ;;
        esac
    fi
    if [ "$FILE_SYSTEM_TYPE" == "btrfs" ]; then
        CMDLINE_LINUX="$CMDLINE_LINUX rootflags=subvol=${BTRFS_SUBVOLUME_ROOT[1]}"
    fi
    if [ "$KMS" == "true" ]; then
        case "$DISPLAY_DRIVER" in
            "nvidia" )
                CMDLINE_LINUX="$CMDLINE_LINUX nvidia-drm.modeset=1"
                ;;
        esac
    fi

    if [ -n "$KERNELS_PARAMETERS" ]; then
        CMDLINE_LINUX="$CMDLINE_LINUX $KERNELS_PARAMETERS"
    fi

    CMDLINE_LINUX=$(trim_variable "$CMDLINE_LINUX")

    if [ "$BIOS_TYPE" == "uefi" ] || [ "$SECURE_BOOT" == "true" ]; then
        pacman_install "efibootmgr"
    fi
    if [ "$SECURE_BOOT" == "true" ]; then
        curl --output PreLoader.efi https://blog.hansenpartnership.com/wp-uploads/2013/PreLoader.efi
        curl --output HashTool.efi https://blog.hansenpartnership.com/wp-uploads/2013/HashTool.efi
        md5sum PreLoader.efi > PreLoader.efi.md5
        md5sum HashTool.efi > HashTool.efi.md5
        echo "4f7a4f566781869d252a09dc84923a82  PreLoader.efi" | md5sum -c -
        echo "45639d23aa5f2a394b03a65fc732acf2  HashTool.efi" | md5sum -c -
    fi

    case "$BOOTLOADER" in
        "grub" )
            bootloader_grub
            ;;
        "refind" )
            bootloader_refind
            ;;
        "systemd" )
            bootloader_systemd
            ;;
        "efistub")
            bootloader_efistub
            ;;
    esac

    if [ "$UKI" == "true" ]; then
        if [ "$GPT_AUTOMOUNT" == "true" ]; then
            echo "$CMDLINE_LINUX rw" > "${MNT_DIR}/etc/kernel/cmdline"
        else
            echo "$CMDLINE_LINUX $CMDLINE_LINUX_ROOT rw" > "${MNT_DIR}/etc/kernel/cmdline" 
        fi
    fi

    arch-chroot "${MNT_DIR}" systemctl set-default multi-user.target
}

function bootloader_grub() {
    pacman_install "grub dosfstools"
    arch-chroot "${MNT_DIR}" sed -i 's/GRUB_DEFAULT=0/GRUB_DEFAULT=saved/' /etc/default/grub
    arch-chroot "${MNT_DIR}" sed -i 's/#GRUB_SAVEDEFAULT="true"/GRUB_SAVEDEFAULT="true"/' /etc/default/grub
    arch-chroot "${MNT_DIR}" sed -i -E 's/GRUB_CMDLINE_LINUX_DEFAULT="(.*) quiet"/GRUB_CMDLINE_LINUX_DEFAULT="\1"/' /etc/default/grub
    arch-chroot "${MNT_DIR}" sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="'"$CMDLINE_LINUX"'"/' /etc/default/grub
    {
        echo ""
        echo "# alis"
        echo "GRUB_DISABLE_SUBMENU=y"
    }>> "${MNT_DIR}"/etc/default/grub

    if [ "$BIOS_TYPE" == "uefi" ]; then
        arch-chroot "${MNT_DIR}" grub-install --target=x86_64-efi --bootloader-id=grub --efi-directory="${ESP_DIRECTORY}" --recheck
    fi
    if [ "$BIOS_TYPE" == "bios" ]; then
        arch-chroot "${MNT_DIR}" grub-install --target=i386-pc --recheck "$DEVICE"
    fi

    arch-chroot "${MNT_DIR}" grub-mkconfig -o "${BOOT_DIRECTORY}/grub/grub.cfg"

    if [ "$SECURE_BOOT" == "true" ]; then
        mv {PreLoader,HashTool}.efi "${MNT_DIR}${ESP_DIRECTORY}/EFI/grub"
        cp "${MNT_DIR}${ESP_DIRECTORY}/EFI/grub/grubx64.efi" "${MNT_DIR}${ESP_DIRECTORY}/EFI/systemd/loader.efi"
        arch-chroot "${MNT_DIR}" efibootmgr --unicode --disk "$DEVICE" --part 1 --create --label "Arch Linux (PreLoader)" --loader "/EFI/grub/PreLoader.efi"
    fi

    if [ "$VIRTUALBOX" == "true" ]; then
        echo -n "\EFI\grub\grubx64.efi" > "${MNT_DIR}${ESP_DIRECTORY}/startup.nsh"
    fi
}

function bootloader_refind() {
    pacman_install "refind"
    arch-chroot "${MNT_DIR}" refind-install

    arch-chroot "${MNT_DIR}" rm /boot/refind_linux.conf
    arch-chroot "${MNT_DIR}" sed -i 's/^timeout.*/timeout 5/' "${ESP_DIRECTORY}/EFI/refind/refind.conf"
    arch-chroot "${MNT_DIR}" sed -i 's/^#scan_all_linux_kernels.*/scan_all_linux_kernels false/' "${ESP_DIRECTORY}/EFI/refind/refind.conf"
    #arch-chroot "${MNT_DIR}" sed -i 's/^#default_selection "+,bzImage,vmlinuz"/default_selection "+,bzImage,vmlinuz"/' "${ESP_DIRECTORY}/EFI/refind/refind.conf"

    if [ "$SECURE_BOOT" == "true" ]; then
        mv {PreLoader,HashTool}.efi "${MNT_DIR}${ESP_DIRECTORY}/EFI/refind"
        cp "${MNT_DIR}${ESP_DIRECTORY}/EFI/refind/refind_x64.efi" "${MNT_DIR}${ESP_DIRECTORY}/EFI/refind/loader.efi"
        arch-chroot "${MNT_DIR}" efibootmgr --unicode --disk "$DEVICE" --part 1 --create --label "Arch Linux (PreLoader)" --loader "/EFI/refind/PreLoader.efi"
    fi

    if [ "$UKI" == "false" ]; then
        bootloader_refind_entry "linux"
        if [ -n "$KERNELS" ]; then
            IFS=' ' read -r -a KS <<< "$KERNELS"
            for KERNEL in "${KS[@]}"; do
                if [[ "$KERNEL" =~ ^.*-headers$ ]]; then
                    continue
                fi
                bootloader_refind_entry "$KERNEL"
            done
        fi

        if [ "$VIRTUALBOX" == "true" ]; then
            echo -ne "\EFI\refind\refind_x64.efi" > "${MNT_DIR}${ESP_DIRECTORY}/startup.nsh"
        fi
    fi
}

function bootloader_systemd() {
    arch-chroot "${MNT_DIR}" systemd-machine-id-setup
    arch-chroot "${MNT_DIR}" bootctl install

    #arch-chroot "${MNT_DIR}" systemctl enable systemd-boot-update.service

    arch-chroot "${MNT_DIR}" mkdir -p "/etc/pacman.d/hooks/"
    cat <<EOT > "${MNT_DIR}/etc/pacman.d/hooks/systemd-boot.hook"
[Trigger]
Type = Package
Operation = Upgrade
Target = systemd

[Action]
Description = Updating systemd-boot...
When = PostTransaction
Exec = /usr/bin/systemctl restart systemd-boot-update.service
EOT

    if [ "$SECURE_BOOT" == "true" ]; then
        mv {PreLoader,HashTool}.efi "${MNT_DIR}${ESP_DIRECTORY}/EFI/systemd"
        cp "${MNT_DIR}${ESP_DIRECTORY}/EFI/systemd/systemd-bootx64.efi" "${MNT_DIR}${ESP_DIRECTORY}/EFI/systemd/loader.efi"
        arch-chroot "${MNT_DIR}" efibootmgr --unicode --disk "$DEVICE" --part 1 --create --label "Arch Linux (PreLoader)" --loader "/EFI/systemd/PreLoader.efi"
    fi

    if [ "$UKI" == "true" ]; then
        cat <<EOT > "${MNT_DIR}${ESP_DIRECTORY}/loader/loader.conf"
# alis
timeout ${SYSTEMD_BOOT_TIMEOUT}
editor 0
EOT
    else
        cat <<EOT > "${MNT_DIR}${ESP_DIRECTORY}/loader/loader.conf"
# alis
timeout ${SYSTEMD_BOOT_TIMEOUT}
default archlinux.conf
editor 0
EOT

        arch-chroot "${MNT_DIR}" mkdir -p "${ESP_DIRECTORY}/loader/entries/"

        bootloader_systemd_entry "linux"
        if [ -n "$KERNELS" ]; then
            IFS=' ' read -r -a KS <<< "$KERNELS"
            for KERNEL in "${KS[@]}"; do
                if [[ "$KERNEL" =~ ^.*-headers$ ]]; then
                    continue
                fi
                bootloader_systemd_entry "$KERNEL"
            done
        fi

        if [ "$VIRTUALBOX" == "true" ]; then
            echo -n "\EFI\systemd\systemd-bootx64.efi" > "${MNT_DIR}${ESP_DIRECTORY}/startup.nsh"
        fi
    fi
}

function bootloader_efistub() {
    pacman_install "efibootmgr"

    bootloader_efistub_entry "linux"
    if [ -n "$KERNELS" ]; then
        IFS=' ' read -r -a KS <<< "$KERNELS"
        for KERNEL in "${KS[@]}"; do
            if [[ "$KERNEL" =~ ^.*-headers$ ]]; then
                continue
            fi
            bootloader_efistub_entry "$KERNEL"
        done
    fi
}

function bootloader_refind_entry() {
    local KERNEL="$1"
    local MICROCODE=""

    if [ -n "$INITRD_MICROCODE" ]; then
        local MICROCODE="initrd=/$INITRD_MICROCODE"
    fi

    cat <<EOT >> "${MNT_DIR}${ESP_DIRECTORY}/EFI/refind/refind.conf"
# alis
menuentry "Arch Linux ($KERNEL)" {
    volume   $PARTUUID_BOOT
    loader   /vmlinuz-$KERNEL
    initrd   /initramfs-$KERNEL.img
    icon     /EFI/refind/icons/os_arch.png
    options  "$MICROCODE $CMDLINE_LINUX_ROOT rw $CMDLINE_LINUX"
    submenuentry "Boot using fallback initramfs"
        initrd /initramfs-$KERNEL-fallback.img"
    }
    submenuentry "Boot to terminal"
        add_options "systemd.unit=multi-user.target"
    }
}
EOT
}

function bootloader_systemd_entry() {
    local KERNEL="$1"
    local MICROCODE=""

    if [ -n "$INITRD_MICROCODE" ]; then
        local MICROCODE="initrd /$INITRD_MICROCODE"
    fi

    cat <<EOT >> "${MNT_DIR}${ESP_DIRECTORY}/loader/entries/arch-$KERNEL.conf"
title Arch Linux ($KERNEL)
efi /vmlinuz-linux
$MICROCODE
initrd /initramfs-$KERNEL.img
options initrd=initramfs-$KERNEL.img $CMDLINE_LINUX_ROOT rw $CMDLINE_LINUX
EOT

    cat <<EOT >> "${MNT_DIR}${ESP_DIRECTORY}/loader/entries/arch-$KERNEL-fallback.conf"
title Arch Linux ($KERNEL, fallback)
efi /vmlinuz-linux
$MICROCODE
initrd /initramfs-$KERNEL-fallback.img
options initrd=initramfs-$KERNEL-fallback.img $CMDLINE_LINUX_ROOT rw $CMDLINE_LINUX
EOT
}

function bootloader_efistub_entry() {
    local KERNEL="$1"
    local MICROCODE=""

    if [ "$UKI" == "true" ]; then
        arch-chroot "${MNT_DIR}" efibootmgr --unicode --disk "$DEVICE" --part 1 --create --label "Arch Linux ($KERNEL fallback)" --loader "EFI\linux\archlinux-$KERNEL-fallback.efi" --unicode --verbose
        arch-chroot "${MNT_DIR}" efibootmgr --unicode --disk "$DEVICE" --part 1 --create --label "Arch Linux ($KERNEL)" --loader "EFI\linux\archlinux-$KERNEL.efi" --unicode --verbose
    else
        if [ -n "$INITRD_MICROCODE" ]; then
            local MICROCODE="initrd=\\$INITRD_MICROCODE"
        fi

        arch-chroot "${MNT_DIR}" efibootmgr --unicode --disk "$DEVICE" --part 1 --create --label "Arch Linux ($KERNEL)" --loader /vmlinuz-"$KERNEL" --unicode "$CMDLINE_LINUX $CMDLINE_LINUX_ROOT rw $MICROCODE initrd=\initramfs-$KERNEL.img" --verbose
        arch-chroot "${MNT_DIR}" efibootmgr --unicode --disk "$DEVICE" --part 1 --create --label "Arch Linux ($KERNEL fallback)" --loader /vmlinuz-"$KERNEL" --unicode "$CMDLINE_LINUX $CMDLINE_LINUX_ROOT rw $MICROCODE initrd=\initramfs-$KERNEL-fallback.img" --verbose
    fi
}

kernel(){
    execute_step "kernels"
    execute_step "bootloader"
}