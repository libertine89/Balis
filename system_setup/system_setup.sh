
function configure_reflector() {
    if [ "$REFLECTOR" == "false" ]; then
        if systemctl is-active --quiet reflector.service; then
            systemctl stop reflector.service
        fi
    fi
}

function configure_time() {
    timedatectl set-ntp true
}

function install() {
    print_step "Installing Filesystem & Reflector"
    local COUNTRIES=()

    pacman-key --init
    pacman-key --populate

    if [ -n "$PACMAN_MIRROR" ]; then
        echo "Server = $PACMAN_MIRROR" > /etc/pacman.d/mirrorlist
    fi
    if [ "$REFLECTOR" == "true" ]; then
        for COUNTRY in "${REFLECTOR_COUNTRIES[@]}"; do
            local COUNTRIES+=(--country "$COUNTRY")
        done
        pacman -Sy --noconfirm reflector
        reflector "${COUNTRIES[@]}" --latest 25 --age 24 --protocol https --completion-percent 100 --sort rate --save /etc/pacman.d/mirrorlist
    fi

    sed -i 's/#Color/Color/' /etc/pacman.conf
    if [ "$PACMAN_PARALLEL_DOWNLOADS" == "true" ]; then
        sed -i 's/#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
    else
        sed -i 's/#ParallelDownloads\(.*\)/#ParallelDownloads\1\nDisableDownloadTimeout/' /etc/pacman.conf
    fi

    local PACKAGES=()
    if [ "$LVM" == "true" ]; then
        local PACKAGES+=("lvm2")
    fi
    if [ "$FILE_SYSTEM_TYPE" == "btrfs" ]; then
        local PACKAGES+=("btrfs-progs")
    fi
    if [ "$FILE_SYSTEM_TYPE" == "xfs" ]; then
        local PACKAGES+=("xfsprogs")
    fi
    if [ "$FILE_SYSTEM_TYPE" == "f2fs" ]; then
        local PACKAGES+=("f2fs-tools")
    fi
    if [ "$FILE_SYSTEM_TYPE" == "reiserfs" ]; then
        local PACKAGES+=("reiserfsprogs")
    fi

    pacstrap "${MNT_DIR}" base base-devel linux linux-firmware "${PACKAGES[@]}"

    if [ "$PACMAN_PARALLEL_DOWNLOADS" == "true" ]; then
        sed -i 's/#ParallelDownloads/ParallelDownloads/' "${MNT_DIR}"/etc/pacman.conf
    else
        sed -i 's/#ParallelDownloads\(.*\)/#ParallelDownloads\1\nDisableDownloadTimeout/' "${MNT_DIR}"/etc/pacman.conf
    fi

    if [ "$REFLECTOR" == "true" ]; then
        pacman_install "reflector"
        cat <<EOT > "${MNT_DIR}/etc/xdg/reflector/reflector.conf"
${COUNTRIES[@]}
--latest 25
--age 24
--protocol https
--completion-percent 100
--sort rate
--save /etc/pacman.d/mirrorlist
EOT
        arch-chroot "${MNT_DIR}" reflector "${COUNTRIES[@]}" --latest 25 --age 24 --protocol https --completion-percent 100 --sort rate --save /etc/pacman.d/mirrorlist
        arch-chroot "${MNT_DIR}" systemctl enable reflector.timer
    fi

    if [ "$PACKAGES_MULTILIB" == "true" ]; then
        sed -z -i 's/#\[multilib\]\n#/[multilib]\n/' "${MNT_DIR}"/etc/pacman.conf
    fi
}

function configuration() {
    print_step "Configuring System Files"

    if [ "$GPT_AUTOMOUNT" != "true" ]; then
        genfstab -U "${MNT_DIR}" >> "${MNT_DIR}/etc/fstab"

        cat <<EOT >> "${MNT_DIR}/etc/fstab"
# efivars
efivarfs /sys/firmware/efi/efivars efivarfs ro,nosuid,nodev,noexec 0 0

EOT

        if [ -n "$SWAP_SIZE" ]; then
            cat <<EOT >> "${MNT_DIR}/etc/fstab"
# swap
$SWAPFILE none swap defaults 0 0

EOT
        fi
    fi

    if [ "$DEVICE_TRIM" == "true" ]; then
        if [ "$GPT_AUTOMOUNT" != "true" ]; then
            if [ "$FILE_SYSTEM_TYPE" == "f2fs" ]; then
                sed -i 's/relatime/noatime,nodiscard/' "${MNT_DIR}"/etc/fstab
            else
                sed -i 's/relatime/noatime/' "${MNT_DIR}"/etc/fstab
            fi
        fi
        arch-chroot "${MNT_DIR}" systemctl enable fstrim.timer
    fi

    arch-chroot "${MNT_DIR}" ln -s -f "$TIMEZONE" /etc/localtime
    arch-chroot "${MNT_DIR}" hwclock --systohc
    for LOCALE in "${LOCALES[@]}"; do
        sed -i "s/#$LOCALE/$LOCALE/" /etc/locale.gen
        sed -i "s/#$LOCALE/$LOCALE/" "${MNT_DIR}"/etc/locale.gen
    done
    for VARIABLE in "${LOCALE_CONF[@]}"; do
        #localectl set-locale "$VARIABLE"
        echo -e "$VARIABLE" >> "${MNT_DIR}"/etc/locale.conf
    done
    locale-gen
    arch-chroot "${MNT_DIR}" locale-gen
    echo -e "$KEYMAP\n$FONT\n$FONT_MAP" > "${MNT_DIR}"/etc/vconsole.conf
    echo "$HOSTNAME" > "${MNT_DIR}"/etc/hostname

    local OPTIONS=""
    if [ -n "$KEYLAYOUT" ]; then
        local OPTIONS="$OPTIONS"$'\n'"    Option \"XkbLayout\" \"$KEYLAYOUT\""
    fi
    if [ -n "$KEYMODEL" ]; then
        local OPTIONS="$OPTIONS"$'\n'"    Option \"XkbModel\" \"$KEYMODEL\""
    fi
    if [ -n "$KEYVARIANT" ]; then
        local OPTIONS="$OPTIONS"$'\n'"    Option \"XkbVariant\" \"$KEYVARIANT\""
    fi
    if [ -n "$KEYOPTIONS" ]; then
        local OPTIONS="$OPTIONS"$'\n'"    Option \"XkbOptions\" \"$KEYOPTIONS\""
    fi

    arch-chroot "${MNT_DIR}" mkdir -p "/etc/X11/xorg.conf.d/"
    cat <<EOT > "${MNT_DIR}/etc/X11/xorg.conf.d/00-keyboard.conf"
# Written by systemd-localed(8), read by systemd-localed and Xorg. It's
# probably wise not to edit this file manually. Use localectl(1) to
# instruct systemd-localed to update it.
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    $OPTIONS
EndSection
EOT

    if [ -n "$SWAP_SIZE" ]; then
        echo "vm.swappiness=10" > "${MNT_DIR}"/etc/sysctl.d/99-sysctl.conf
    fi

    printf "%s\n%s" "$ROOT_PASSWORD" "$ROOT_PASSWORD" | arch-chroot "${MNT_DIR}" passwd
}

function users() {
    print_step "Setting Up Users"

    local USERS_GROUPS="wheel,storage,optical"
    create_user "$USER_NAME" "$USER_PASSWORD" "$USERS_GROUPS"

    for U in "${ADDITIONAL_USERS[@]}"; do
        local S=()
        IFS='=' read -ra S <<< "$U"
        local USER="${S[0]}"
        local PASSWORD="${S[1]}"
        create_user "$USER" "$PASSWORD" "$USERS_GROUPS"
    done

    arch-chroot "${MNT_DIR}" sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

    pacman_install "xdg-user-dirs"

    if [ "$SYSTEMD_HOMED" == "true" ]; then
        arch-chroot "${MNT_DIR}" systemctl enable systemd-homed.service

        cat <<EOT > "${MNT_DIR}/etc/pam.d/nss-auth"
#%PAM-1.0

auth     sufficient pam_unix.so try_first_pass nullok
auth     sufficient pam_systemd_home.so
auth     required   pam_deny.so

account  sufficient pam_unix.so
account  sufficient pam_systemd_home.so
account  required   pam_deny.so

password sufficient pam_unix.so try_first_pass nullok sha512 shadow
password sufficient pam_systemd_home.so
password required   pam_deny.so
EOT

        cat <<EOT > "${MNT_DIR}/etc/pam.d/system-auth"
#%PAM-1.0

auth      substack   nss-auth
auth      optional   pam_permit.so
auth      required   pam_env.so

account   substack   nss-auth
account   optional   pam_permit.so
account   required   pam_time.so

password  substack   nss-auth
password  optional   pam_permit.so

session   required  pam_limits.so
session   optional  pam_systemd_home.so
session   required  pam_unix.so
session   optional  pam_permit.so
EOT
    fi
}

function create_user() {
    local USER=$1
    local PASSWORD=$2
    local USERS_GROUPS=$3
    if [ "$SYSTEMD_HOMED" == "true" ]; then
        create_user_homectl "$USER" "$PASSWORD" "$USERS_GROUPS"
    else
        create_user_useradd "$USER" "$PASSWORD" "$USERS_GROUPS"
    fi
}

function create_user_homectl() {
    local USER=$1
    local PASSWORD=$2
    local USER_GROUPS=$3
    local STORAGE="--storage=directory"
    local IMAGE_PATH="--image-path=${MNT_DIR}/home/$USER"
    local FS_TYPE=""
    local CIFS_DOMAIN=""
    local CIFS_USERNAME=""
    local CIFS_SERVICE=""
    local TZ=${TIMEZONE//\/usr\/share\/zoneinfo\//}
    local L=${LOCALE_CONF[0]//LANG=/}

    if [ "$SYSTEMD_HOMED_STORAGE" != "auto" ]; then
        local STORAGE="--storage=$SYSTEMD_HOMED_STORAGE"
    fi
    if [ "$SYSTEMD_HOMED_STORAGE" == "luks" ] && [ "$SYSTEMD_HOMED_STORAGE_LUKS_TYPE" != "auto" ]; then
        local FS_TYPE="--fs-type=$SYSTEMD_HOMED_STORAGE_LUKS_TYPE"
    fi
    if [ "$SYSTEMD_HOMED_STORAGE" == "luks" ]; then
        local IMAGE_PATH="--image-path=${MNT_DIR}/home/$USER.home"
    fi
    if [ "$SYSTEMD_HOMED_STORAGE" == "cifs" ]; then
        local CIFS_DOMAIN="--cifs-domain=${SYSTEMD_HOMED_CIFS_DOMAIN["domain"]}"
        local CIFS_USERNAME="--cifs-user-name=$USER"
        local CIFS_SERVICE="--cifs-service=${SYSTEMD_HOMED_CIFS_SERVICE["service"]}"
    fi
    if [ "$SYSTEMD_HOMED_STORAGE" == "luks" ] && [ "$SYSTEMD_HOMED_STORAGE_LUKS_TYPE" == "auto" ]; then
        pacman_install "btrfs-progs"
    fi

    systemctl start systemd-homed.service
    sleep 10 # #151 avoid Operation on home <USER> failed: Transport endpoint is not conected.
    # shellcheck disable=SC2086
    homectl create "$USER" --enforce-password-policy=no --real-name="$USER" --timezone="$TZ" --language="$L" $STORAGE $IMAGE_PATH $FS_TYPE $CIFS_DOMAIN $CIFS_USERNAME $CIFS_SERVICE -G "$USER_GROUPS"
    sleep 10 # #151 avoid Operation on home <USER> failed: Transport endpoint is not conected.
    cp -a "/var/lib/systemd/home/." "${MNT_DIR}/var/lib/systemd/home/"
}

function create_user_useradd() {
    local USER=$1
    local PASSWORD=$2
    local USER_GROUPS=$3
    arch-chroot "${MNT_DIR}" useradd -m -G "$USER_GROUPS" -c "$USER" -s /bin/bash "$USER"
    printf "%s\n%s" "$USER_PASSWORD" "$USER_PASSWORD" | arch-chroot "${MNT_DIR}" passwd "$USER"
}

function user_add_groups() {
    local USER="$1"
    local USER_GROUPS="$2"
    if [ "$SYSTEMD_HOMED" == "true" ]; then
        homectl update "$USER" -G "$USER_GROUPS"
    else
        arch-chroot "${MNT_DIR}" usermod -a -G "$USER_GROUPS" "$USER"
    fi
}

function user_add_groups_lightdm() {
    arch-chroot "${MNT_DIR}" groupadd -r "autologin"
    user_add_groups "$USER_NAME" "autologin"

    for U in "${ADDITIONAL_USERS[@]}"; do
        local S=()
        IFS='=' read -ra S <<< "$U"
        local USER=${S[0]}
        user_add_groups "$USER" "autologin"
    done
}


system_setup() {
    execute_step "configure_reflector"
    execute_step "configure_time"
    execute_step "configure_network" #commons
    execute_step "install"
    execute_step "configuration"
    execute_step "users"
    #provisions
    #vagrant
}

