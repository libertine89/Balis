
    function display() {
    source display/display.conf
    print_step "display_driver()"

    local PACKAGES_DRIVER_PACMAN="true"
    local PACKAGES_DRIVER=""
    local PACKAGES_DRIVER_MULTILIB=""
    local PACKAGES_DDX=""
    local PACKAGES_VULKAN=""
    local PACKAGES_VULKAN_MULTILIB=""
    local PACKAGES_HARDWARE_ACCELERATION=""
    local PACKAGES_HARDWARE_ACCELERATION_MULTILIB=""
    case "$DISPLAY_DRIVER" in
        "intel" )
            local PACKAGES_DRIVER_MULTILIB="lib32-mesa"
            ;;
        "amdgpu" )
            local PACKAGES_DRIVER_MULTILIB="lib32-mesa"
            ;;
        "ati" )
            local PACKAGES_DRIVER_MULTILIB="lib32-mesa"
            ;;
        "nvidia" )
            local PACKAGES_DRIVER="nvidia"
            local PACKAGES_DRIVER_MULTILIB="lib32-nvidia-utils"
            ;;
        "nvidia-lts" )
            local PACKAGES_DRIVER="nvidia-lts"
            local PACKAGES_DRIVER_MULTILIB="lib32-nvidia-utils"
            ;;
        "nvidia-dkms" )
            local PACKAGES_DRIVER="nvidia-dkms"
            local PACKAGES_DRIVER_MULTILIB="lib32-nvidia-utils"
            ;;
        "nvidia-470xx-dkms" )
            local PACKAGES_DRIVER_PACMAN="false"
            local PACKAGES_DRIVER="nvidia-470xx-dkms"
            local PACKAGES_DRIVER_MULTILIB="lib32-nvidia-utils"
            ;;
        "nvidia-390xx-dkms" )
            local PACKAGES_DRIVER_PACMAN="false"
            local PACKAGES_DRIVER="nvidia-390xx-dkms"
            local PACKAGES_DRIVER_MULTILIB="lib32-nvidia-utils"
            ;;
        "nvidia-340xx-dkms" )
            local PACKAGES_DRIVER_PACMAN="false"
            local PACKAGES_DRIVER="nvidia-340xx-dkms"
            local PACKAGES_DRIVER_MULTILIB="lib32-nvidia-utils"
            ;;
        "nouveau" )
            local PACKAGES_DRIVER_MULTILIB="lib32-mesa"
            ;;
    esac
    if [ "$DISPLAY_DRIVER_DDX" == "true" ]; then
        case "$DISPLAY_DRIVER" in
            "intel" )
                local PACKAGES_DDX="xf86-video-intel"
                ;;
            "amdgpu" )
                local PACKAGES_DDX="xf86-video-amdgpu"
                ;;
            "ati" )
                local PACKAGES_DDX="xf86-video-ati"
                ;;
            "nouveau" )
                local PACKAGES_DDX="xf86-video-nouveau"
                ;;
        esac
    fi
    if [ "$VULKAN" == "true" ]; then
        case "$DISPLAY_DRIVER" in
            "intel" )
                local PACKAGES_VULKAN="vulkan-intel vulkan-icd-loader"
                local PACKAGES_VULKAN_MULTILIB="lib32-vulkan-intel lib32-vulkan-icd-loader"
                ;;
            "amdgpu" )
                local PACKAGES_VULKAN="vulkan-radeon vulkan-icd-loader"
                local PACKAGES_VULKAN_MULTILIB="lib32-vulkan-radeon lib32-vulkan-icd-loader"
                ;;
            "ati" )
                local PACKAGES_VULKAN="vulkan-radeon vulkan-icd-loader"
                local PACKAGES_VULKAN_MULTILIB="lib32-vulkan-radeon lib32-vulkan-icd-loader"
                ;;
            "nvidia" )
                local PACKAGES_VULKAN="nvidia-utils vulkan-icd-loader"
                local PACKAGES_VULKAN_MULTILIB="lib32-nvidia-utils lib32-vulkan-icd-loader"
                ;;
            "nvidia-lts" )
                local PACKAGES_VULKAN="nvidia-utils vulkan-icd-loader"
                local PACKAGES_VULKAN_MULTILIB="lib32-nvidia-utils lib32-vulkan-icd-loader"
                ;;
            "nvidia-dkms" )
                local PACKAGES_VULKAN="nvidia-utils vulkan-icd-loader"
                local PACKAGES_VULKAN_MULTILIB="lib32-nvidia-utils lib32-vulkan-icd-loader"
                ;;
            "nouveau" )
                local PACKAGES_VULKAN=""
                local PACKAGES_VULKAN_MULTILIB=""
                ;;
        esac
    fi
    if [ "$DISPLAY_DRIVER_HARDWARE_VIDEO_ACCELERATION" == "true" ]; then
        case "$DISPLAY_DRIVER" in
            "intel" )
                if [ -n "$DISPLAY_DRIVER_HARDWARE_VIDEO_ACCELERATION_INTEL" ]; then
                    local PACKAGES_HARDWARE_ACCELERATION="$DISPLAY_DRIVER_HARDWARE_VIDEO_ACCELERATION_INTEL"
                    local PACKAGES_HARDWARE_ACCELERATION_MULTILIB=""
                fi
                ;;
            "amdgpu" )
                local PACKAGES_HARDWARE_ACCELERATION="libva-mesa-driver"
                local PACKAGES_HARDWARE_ACCELERATION_MULTILIB="lib32-libva-mesa-driver"
                ;;
            "ati" )
                local PACKAGES_HARDWARE_ACCELERATION="mesa-vdpau"
                local PACKAGES_HARDWARE_ACCELERATION_MULTILIB="lib32-mesa-vdpau"
                ;;
            "nvidia" )
                local PACKAGES_HARDWARE_ACCELERATION="libva-mesa-driver"
                local PACKAGES_HARDWARE_ACCELERATION_MULTILIB="lib32-libva-mesa-driver"
                ;;
            "nvidia-lts" )
                local PACKAGES_HARDWARE_ACCELERATION="libva-mesa-driver"
                local PACKAGES_HARDWARE_ACCELERATION_MULTILIB="lib32-libva-mesa-driver"
                ;;
            "nvidia-dkms" )
                local PACKAGES_HARDWARE_ACCELERATION="libva-mesa-driver"
                local PACKAGES_HARDWARE_ACCELERATION_MULTILIB="lib32-libva-mesa-driver"
                ;;
            "nvidia-470xx-dkms" )
                local PACKAGES_HARDWARE_ACCELERATION="libva-mesa-driver"
                local PACKAGES_HARDWARE_ACCELERATION_MULTILIB="lib32-libva-mesa-driver"
                ;;
            "nvidia-390xx-dkms" )
                local PACKAGES_HARDWARE_ACCELERATION="libva-mesa-driver"
                local PACKAGES_HARDWARE_ACCELERATION_MULTILIB="lib32-libva-mesa-driver"
                ;;
            "nvidia-340xx-dkms" )
                local PACKAGES_HARDWARE_ACCELERATION="libva-mesa-driver"
                local PACKAGES_HARDWARE_ACCELERATION_MULTILIB="lib32-libva-mesa-driver"
                ;;
            "nouveau" )
                local PACKAGES_HARDWARE_ACCELERATION="libva-mesa-driver"
                local PACKAGES_HARDWARE_ACCELERATION_MULTILIB="lib32-libva-mesa-driver"
                ;;
        esac
    fi

    if [ "$PACKAGES_DRIVER_PACMAN" == "true" ]; then
        pacman_install "mesa $PACKAGES_DRIVER $PACKAGES_DDX $PACKAGES_VULKAN $PACKAGES_HARDWARE_ACCELERATION"
    else
        aur_install "mesa $PACKAGES_DRIVER $PACKAGES_DDX $PACKAGES_VULKAN $PACKAGES_HARDWARE_ACCELERATION"
    fi

    if [ "$PACKAGES_MULTILIB" == "true" ]; then
        pacman_install "$PACKAGES_DRIVER_MULTILIB $PACKAGES_VULKAN_MULTILIB $PACKAGES_HARDWARE_ACCELERATION_MULTILIB"
    fi
}