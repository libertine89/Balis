function enable_network() {
    print_step "network()"

    pacman_install "networkmanager"
    arch-chroot "${MNT_DIR}" systemctl enable NetworkManager.service
}
    
function vagrant() {
    pacman_install "openssh"
    create_user "vagrant" "vagrant"
    arch-chroot "${MNT_DIR}" systemctl enable sshd.service
    arch-chroot "${MNT_DIR}" ssh-keygen -A
    arch-chroot "${MNT_DIR}" sshd -t
}
    
network(){
    execute_step "enable_network"
    if [ "$VAGRANT" == "true" ]; then
        execute_step "vagrant"
    fi
}