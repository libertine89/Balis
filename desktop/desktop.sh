function splash_screen() {
    print_step "Installing Custom Splash Screen"

    pacman_install "plymouth"

    if [ "$SPLASH_SCREEN_INSTALL" == "true" ]; then
        arch-chroot "${MNT_DIR}" plymouth-set-default-theme -R "$SPLASH_SCREEN_THEME"   # Install Theme, Rebuild Initramfs

        LOADER_CONF="${MNT_DIR}/boot/loader/entries/arch-linux.conf"
        if ! grep -q "splash" "$LOADER_CONF"; then
            sed -i 's/^\(options.*\)$/\1 quiet splash/' "$LOADER_CONF"                  # Set Quiet Splash
        fi
    fi
}

function custom_shell() {
    print_step "Installing Custom Shell"

    pacman_install "$CUSTOM_SHELL"
    local CUSTOM_SHELL_PATH="/usr/bin/${CUSTOM_SHELL}"

    if [ -n "$CUSTOM_SHELL_PATH" ]; then
        custom_shell_user "root" $CUSTOM_SHELL_PATH
        custom_shell_user "$USER_NAME" $CUSTOM_SHELL_PATH
        for U in "${ADDITIONAL_USERS[@]}"; do
            local S=()
            IFS='=' read -ra S <<< "$U"
            local USER=${S[0]}
            custom_shell_user "$USER" $CUSTOM_SHELL_PATH
        done
    fi
}

function custom_shell_user() {
    local USER="$1"
    local CUSTOM_SHELL_PATH="$2"

    if [ "$SYSTEMD_HOMED" == "true" ] && [ "$USER" != "root" ]; then
        homectl update --shell="$CUSTOM_SHELL_PATH" "$USER"
    else
        arch-chroot "${MNT_DIR}" chsh -s "$CUSTOM_SHELL_PATH" "$USER"
    fi
}

function desktop_environment() {
    print_step "Installing Desktop Environment"

    #### Arrays in desktop.conf
    if [ -n "${DESKTOP_INSTALLER[$DESKTOP_ENVIRONMENT]}" ] && [ -n "${DESKTOP_DEPENDENCIES[$DESKTOP_ENVIRONMENT]}" ]; then
        "${DESKTOP_INSTALLER[$DESKTOP_ENVIRONMENT]}_install" "${DESKTOP_DEPENDENCIES[$DESKTOP_ENVIRONMENT]}"
    else
        echo "Unknown desktop environment or empty string: $DESKTOP_ENVIRONMENT"
        exit 1
    fi

    arch-chroot "${MNT_DIR}" systemctl set-default graphical.target
}

function display_manager() {
    print_step "Installing Display Manager"

    #### Arrays in desktop.conf
    if [ "$DISPLAY_MANAGER" == "auto" ]; then
        DISPLAY_MANAGER="${AUTO_DISPLAY_PAIRS[$DESKTOP_ENVIRONMENT]}"
    fi

    pacman_install "${DISPLAY_DEPENDENCIES[$DISPLAY_MANAGER]}"

    if [[ "$DISPLAY_MANAGER" == "lightdm" && "$DESKTOP_ENVIRONMENT" == "deepin" ]]; then
        user_add_groups_lightdm
        arch-chroot "${MNT_DIR}" sed -i 's/^#greeter-session=.*/greeter-session=lightdm-deepin-greeter/' /etc/lightdm/lightdm.conf
    elif [ "$DISPLAY_MANAGER" == "lightdm" ]; then
        user_add_groups_lightdm
    fi

    arch-chroot "${MNT_DIR}" systemctl enable "$DISPLAY_MANAGER".service
}

desktop(){
    execute_step "splash_screen"
    if [ -n "$CUSTOM_SHELL" ]; then
        execute_step "custom_shell"
    fi
    if [ -n "$DESKTOP_ENVIRONMENT" ]; then
        execute_step "desktop_environment"
        execute_step "display_manager"
    fi
}
