
function splash_screen() {
    print_step "Installing Custom Splash Screen"

    pacman_install "plymouth"

    if [ "$SPLASH_SCREEN_INSTALL" == "true" ]; then
        # Set Plymouth theme and rebuild initramfs
        arch-chroot "${MNT_DIR}" plymouth-set-default-theme -R "$SPLASH_SCREEN_THEME"

        # Add 'quiet splash' to the kernel options
        LOADER_CONF="${MNT_DIR}/boot/loader/entries/arch-linux.conf"
        if ! grep -q "splash" "$LOADER_CONF"; then
            sed -i 's/^\(options.*\)$/\1 quiet splash/' "$LOADER_CONF"
        fi
    fi
}

function custom_shell() {
    print_step "Installing Custom Shell"

    local CUSTOM_SHELL_PATH=""
    case "$CUSTOM_SHELL" in
        "zsh" )
            pacman_install "zsh"
            local CUSTOM_SHELL_PATH="/usr/bin/zsh"
            ;;
        "dash" )
            pacman_install "dash"
            local CUSTOM_SHELL_PATH="/usr/bin/dash"
            ;;
        "fish" )
            pacman_install "fish"
            local CUSTOM_SHELL_PATH="/usr/bin/fish"
            ;;
    esac

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

    case "$DESKTOP_ENVIRONMENT" in
        "hyprland" )
            desktop_environment_hyprland
            ;;
        "gnome" )
            desktop_environment_gnome
            ;;
        "kde" )
            desktop_environment_kde
            ;;
        "xfce" )
            desktop_environment_xfce
            ;;
        "mate" )
            desktop_environment_mate
            ;;
        "cinnamon" )
            desktop_environment_cinnamon
            ;;
        "lxde" )
            desktop_environment_lxde
            ;;
        "i3-wm" )
            desktop_environment_i3_wm
            ;;
        "i3-gaps" )
            desktop_environment_i3_gaps
            ;;
        "deepin" )
            desktop_environment_deepin
            ;;
        "budgie" )
            desktop_environment_budgie
            ;;
        "bspwm" )
            desktop_environment_bspwm
            ;;
        "awesome" )
            desktop_environment_awesome
            ;;
        "qtile" )
            desktop_environment_qtile
            ;;
        "openbox" )
            desktop_environment_openbox
            ;;
        "leftwm" )
            desktop_environment_leftwm
            ;;
        "dusk" )
            desktop_environment_dusk
            ;;
    esac

    arch-chroot "${MNT_DIR}" systemctl set-default graphical.target
}

function desktop_environment_hyprland() {
    pacman_install "hyprland"
}

function desktop_environment_gnome() {
    pacman_install "gnome"
}

function desktop_environment_kde() {
    pacman_install "plasma-meta kde-system-meta kde-utilities-meta kde-graphics-meta kde-multimedia-meta kde-network-meta"
}

function desktop_environment_xfce() {
    pacman_install "xfce4 xfce4-goodies xorg-server pavucontrol pulseaudio"
}

function desktop_environment_mate() {
    pacman_install "mate mate-extra xorg-server"
}

function desktop_environment_cinnamon() {
    pacman_install "cinnamon gnome-terminal xorg-server"
}

function desktop_environment_lxde() {
    pacman_install "lxde"
}

function desktop_environment_i3_wm() {
    pacman_install "i3-wm i3blocks i3lock i3status dmenu rxvt-unicode xorg-server"
}

function desktop_environment_i3_gaps() {
    pacman_install "i3-gaps i3blocks i3lock i3status dmenu rxvt-unicode xorg-server"
}

function desktop_environment_deepin() {
    pacman_install "deepin deepin-extra deepin-kwin xorg xorg-server"
}

function desktop_environment_budgie() {
    pacman_install "budgie-desktop budgie-desktop-view budgie-screensaver gnome-control-center network-manager-applet gnome"
}

function desktop_environment_bspwm() {
    pacman_install "bspwm"
}

function desktop_environment_awesome() {
    pacman_install "awesome vicious xterm xorg-server"
}

function desktop_environment_qtile() {
    pacman_install "qtile xterm xorg-server"
}

function desktop_environment_openbox() {
    pacman_install "openbox obconf xterm xorg-server"
}

function desktop_environment_leftwm() {
    aur_install "leftwm-git leftwm-theme-git dmenu xterm xorg-server"
}

function desktop_environment_dusk() {
    aur_install "dusk-git dmenu xterm xorg-server"
}

function display_manager() {
    print_step "Installing Display Manager"

    if [ "$DISPLAY_MANAGER" == "auto" ]; then
        case "$DESKTOP_ENVIRONMENT" in
            "gnome" | "budgie" )
                display_manager_gdm
                ;;
            "kde" )
                display_manager_sddm
                ;;
            "lxde" )
                display_manager_lxdm
                ;;
            "xfce" | "mate" | "cinnamon" | "i3-wm" | "i3-gaps" | "deepin" | "bspwm" | "awesome" | "qtile" | "openbox" | "leftwm" | "dusk" )
                display_manager_lightdm
                ;;
        esac
    else
        case "$DISPLAY_MANAGER" in
            "gdm" )
                display_manager_gdm
                ;;
            "sddm" )
                display_manager_sddm
                ;;
            "lightdm" )
                display_manager_lightdm
                ;;
            "lxdm" )
                display_manager_lxdm
                ;;
        esac
    fi
}

function display_manager_gdm() {
    pacman_install "gdm"
    arch-chroot "${MNT_DIR}" systemctl enable gdm.service
}

function display_manager_sddm() {
    pacman_install "sddm"
    arch-chroot "${MNT_DIR}" systemctl enable sddm.service
}

function display_manager_lightdm() {
    pacman_install "lightdm lightdm-gtk-greeter"
    arch-chroot "${MNT_DIR}" systemctl enable lightdm.service
    user_add_groups_lightdm

    if [ "$DESKTOP_ENVIRONMENT" == "deepin" ]; then
        arch-chroot "${MNT_DIR}" sed -i 's/^#greeter-session=.*/greeter-session=lightdm-deepin-greeter/' /etc/lightdm/lightdm.conf
        arch-chroot "${MNT_DIR}" systemctl enable lightdm.service
    fi
}

function display_manager_lxdm() {
    pacman_install "lxdm"
    arch-chroot "${MNT_DIR}" systemctl enable lxdm.service
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