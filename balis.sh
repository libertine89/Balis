
# shellcheck disable=SC1090,SC2153,SC2034,SC2155,SC2181
# SC1090: Can't follow non-constant source. Use a directive to specify location.
# SC2034: foo appears unused. Verify it or export it.
# SC2155 Declare and assign separately to avoid masking return values
# SC2153: Possible Misspelling: MYVARIABLE may not be assigned. Did you mean MY_VARIABLE?
# SC2181: Check exit code directly with e.g. if mycmd;, not indirectly with $?.

#!/usr/bin/env bash
set -eu

function main() {
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
source init/init.sh
main "$@"
