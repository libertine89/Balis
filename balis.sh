
# shellcheck disable=SC1090,SC2153,SC2034,SC2155,SC2181
# SC1090: Can't follow non-constant source. Use a directive to specify location.
# SC2034: foo appears unused. Verify it or export it.
# SC2155 Declare and assign separately to avoid masking return values
# SC2153: Possible Misspelling: MYVARIABLE may not be assigned. Did you mean MY_VARIABLE?
# SC2181: Check exit code directly with e.g. if mycmd;, not indirectly with $?.

# Arch Linux Install Script (alis) installs unattended, automated
# and customized Arch Linux system.
# Copyright (C) 2022 picodotdev

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

# This script is hosted at https://github.com/picodotdev/alis. For new features,
# improvements and bugs fill an issue in GitHub or make a pull request.
# Pull Request are welcome!
#
# If you test it in real hardware please send me an email to pico.dev@gmail.com with
# the machine description and tell me if somethig goes wrong or all works fine.
#
# Please, don't ask for support for this script in Arch Linux forums, first read
# the Arch Linux wiki [1], the Installation Guide [2] and the General
# Recomendations [3], later compare the commands with those of this script.
#
# [1] https://wiki.archlinux.org
# [2] https://wiki.archlinux.org/index.php/Installation_guide
# [3] https://wiki.archlinux.org/index.php/General_recommendations

# Script to install an Arch Linux system.
#
# Usage:
# # loadkeys es
# # curl https://raw.githubusercontent.com/picodotdev/alis/main/download.sh | bash
# # vim alis.conf
# # ./alis.sh

#!/usr/bin/env bash
set -eu





function provision() {
    print_step "provision()"

    (cd "$PROVISION_DIRECTORY" && cp -vr --parents . "${MNT_DIR}")
}




function main() {
    init                                                     # Sources,Script,Variable Checks & Logs
    execute_section "Setting up Disks..." disk_setup                                # Drive, Partitions & Passwords
    execute_section "Setting up System & Users..." system_setup                     # Reflector,Time,Users,Network & FSTAB
    if [ -n "$DISPLAY_DRIVER" ]; then               
    execute_section "Setting up Display Drivers..." display                         # Auto detect for display drivers if not set
    fi              
    execute_section "Setting up Kernel & Bootloader..." kernel                      # Kernel & Bootloader
    execute_section "Setting up Network and Vagrant..." network
    execute_section "Setting mkinitcpio..." initramfs                               # Mkinitcio & Mkinitcpio Config
    execute_section "Setting up Splash, Shell DDM & Desktop Enviroment..." desktop  # Splash Screen,Custom Shell,Display Manager & Desktop Enviroment
    if [ "$PACKAGES_INSTALL" == "true" ]; then
    execute_section "Installing Packages" packages                                  # Pacman, Flatpak, SDK & AUR Packages,Provision & Systemd Files
    fi
    execute_section "Finishing up Script & Logs" end                                # Copy Logs & End timer
}
source init/init.sh
main "$@"
