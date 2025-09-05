timestamp() {
    END_TIMESTAMP=$(date -u +"%F %T")
    START_SEC=$(date -d "$START_TIMESTAMP" '+%s')
    END_SEC=$(date -d "$END_TIMESTAMP" '+%s')
    INSTALLATION_TIME=$(date -u -d "@$((END_SEC - START_SEC))" '+%T')
    echo -e "Installation start ${WHITE_BOLD}$START_TIMESTAMP${NC}, end ${WHITE_BOLD}$END_TIMESTAMP${NC}, time ${WHITE_BOLD}$INSTALLATION_TIME${NC}"
}


function reboot() {
    echo ""
    echo -e "${GREEN}Arch Linux installed successfully"'!'"${NC}"
    echo ""

    if [ "$REBOOT" == "true" ]; then
        echo -e "${GREEN}"
        set +e
        cat <<"EOF"
   _____      _     __          __
  / __(_)__  (_)__ / /  ___ ___/ /
 / _// / _ \/ (_-</ _ \/ -_) _  / 
/_/ /_/_//_/_/___/_//_/\__/\_,_/ 

EOF
    echo -e "${NC}"

        for (( i = 15; i >= 1; i-- )); do 
            echo -ne "\rRebooting in $i seconds... Press Esc to abort or R to reboot now. "
            if read -r -s -n 1 -t 1 KEY; then
                case "$KEY" in
                    $'\e') 
                        echo -e "\nReboot aborted. Please reboot manually."; 
                        return ;;
                    [rR])  
                        echo -e "\nRebooting now..."; 
                        reboot; 
                        return ;;
                esac
            fi
        done

    echo -e "\nRebooting...\n"
    copy_logs
    command reboot
    fi
}

function copy_logs() {
    local ESCAPED_LUKS_PASSWORD=${LUKS_PASSWORD//[.[\*^$()+?{|]/[\\&]}
    local ESCAPED_ROOT_PASSWORD=${ROOT_PASSWORD//[.[\*^$()+?{|]/[\\&]}
    local ESCAPED_USER_PASSWORD=${USER_PASSWORD//[.[\*^$()+?{|]/[\\&]}


    FILES_TO_LOG=(
        BALIS_CONF_FILE
        BALIS_LOG_FILE
        BALIS_ASCIINEMA_FILE
    )

    for varname in "${FILES_TO_LOG[@]}"; do
        local SOURCE_FILE="${!varname}"
        if [ -f "$SOURCE_FILE" ]; then
            local FILE="${MNT_DIR}/var/log/alis/$(basename "$SOURCE_FILE")"

            mkdir -p "${MNT_DIR}/var/log/alis"
            cp "$SOURCE_FILE" "$FILE"
            chown root:root "$FILE"
            chmod 600 "$FILE"

            [[ -n "$ESCAPED_LUKS_PASSWORD"  ]] && sed -i "s/${ESCAPED_LUKS_PASSWORD}/******/g" "$FILE"
            [[ -n "$ESCAPED_ROOT_PASSWORD"  ]] && sed -i "s/${ESCAPED_ROOT_PASSWORD}/******/g" "$FILE"
            [[ -n "$ESCAPED_USER_PASSWORD"  ]] && sed -i "s/${ESCAPED_USER_PASSWORD}/******/g" "$FILE"
        fi
    done
}

end(){
    execute_step "timestamp"
    execute_step "reboot"
}
