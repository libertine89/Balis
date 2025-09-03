timestamp(){
    local END_TIMESTAMP=$(date -u +"%F %T")
    local INSTALLATION_TIME=$(date -u -d @$(($(date -d "$END_TIMESTAMP" '+%s') - $(date -d "$START_TIMESTAMP" '+%s'))) '+%T')
    echo -e "Installation start ${WHITE}$START_TIMESTAMP${NC}, end ${WHITE}$END_TIMESTAMP${NC}, time ${WHITE}$INSTALLATION_TIME${NC}"
}

function reboot() {
    echo ""
    echo -e "${GREEN}Arch Linux installed successfully"'!'"${NC}"
    echo ""

    if [ "$REBOOT" == "true" ]; then
        REBOOT="true"

        set +e
        for (( i = 15; i >= 1; i-- )); do
            read -r -s -n 1 -t 1 -p "Rebooting in $i seconds... Press Esc key to abort or press R key to reboot now."$'\n' KEY
            local CODE="$?"
            if [ "$CODE" != "0" ]; then
                continue
            fi
            if [ "$KEY" == $'\e' ]; then
                REBOOT="false"
                break
            elif [ "$KEY" == "r" ] || [ "$KEY" == "R" ]; then
                REBOOT="true"
                break
            fi
        done
        set -e

        if [ "$REBOOT" == 'true' ]; then
            echo "Rebooting..."
            echo ""

            copy_logs
            do_reboot
        else
            if [ "$ASCIINEMA" == "true" ]; then
                echo "Reboot aborted. You will must terminate asciinema recording and do a explicit reboot (exit, ./alis-reboot.sh)."
                echo ""
            else
                echo "Reboot aborted. You will must do a explicit reboot (./alis-reboot.sh)."
                echo ""
            fi

            copy_logs
        fi
    else
        if [ "$ASCIINEMA" == "true" ]; then
            echo "No reboot. You will must terminate asciinema recording and do a explicit reboot (exit, ./alis-reboot.sh)."
            echo ""
        else
            echo "No reboot. You will must do a explicit reboot (./alis-reboot.sh)."
            echo ""
        fi

        copy_logs
    fi
}

function copy_logs() {
    local ESCAPED_LUKS_PASSWORD=${LUKS_PASSWORD//[.[\*^$()+?{|]/[\\&]}
    local ESCAPED_ROOT_PASSWORD=${ROOT_PASSWORD//[.[\*^$()+?{|]/[\\&]}
    local ESCAPED_USER_PASSWORD=${USER_PASSWORD//[.[\*^$()+?{|]/[\\&]}

    if [ -f "$BALIS_CONF_FILE" ]; then
        local SOURCE_FILE="$BALIS_CONF_FILE"
        local FILE="${MNT_DIR}/var/log/alis/$BALIS_CONF_FILE"

        mkdir -p "${MNT_DIR}"/var/log/alis
        cp "$SOURCE_FILE" "$FILE"
        chown root:root "$FILE"
        chmod 600 "$FILE"
        if [ -n "$ESCAPED_LUKS_PASSWORD" ]; then
            sed -i "s/${ESCAPED_LUKS_PASSWORD}/******/g" "$FILE"
        fi
        if [ -n "$ESCAPED_ROOT_PASSWORD" ]; then
            sed -i "s/${ESCAPED_ROOT_PASSWORD}/******/g" "$FILE"
        fi
        if [ -n "$ESCAPED_USER_PASSWORD" ]; then
            sed -i "s/${ESCAPED_USER_PASSWORD}/******/g" "$FILE"
        fi
    fi
    if [ -f "$BALIS_LOG_FILE" ]; then
        local SOURCE_FILE="$BALIS_LOG_FILE"
        local FILE="${MNT_DIR}/var/log/alis/$BALIS_LOG_FILE"

        mkdir -p "${MNT_DIR}"/var/log/alis
        cp "$SOURCE_FILE" "$FILE"
        chown root:root "$FILE"
        chmod 600 "$FILE"
        if [ -n "$ESCAPED_LUKS_PASSWORD" ]; then
            sed -i "s/${ESCAPED_LUKS_PASSWORD}/******/g" "$FILE"
        fi
        if [ -n "$ESCAPED_ROOT_PASSWORD" ]; then
            sed -i "s/${ESCAPED_ROOT_PASSWORD}/******/g" "$FILE"
        fi
        if [ -n "$ESCAPED_USER_PASSWORD" ]; then
            sed -i "s/${ESCAPED_USER_PASSWORD}/******/g" "$FILE"
        fi
    fi
    if [ -f "$BALIS_ASCIINEMA_FILE" ]; then
        local SOURCE_FILE="$BALIS_ASCIINEMA_FILE"
        local FILE="${MNT_DIR}/var/log/alis/$BALIS_ASCIINEMA_FILE"

        mkdir -p "${MNT_DIR}"/var/log/alis
        cp "$SOURCE_FILE" "$FILE"
        chown root:root "$FILE"
        chmod 600 "$FILE"
        if [ -n "$ESCAPED_LUKS_PASSWORD" ]; then
            sed -i "s/${ESCAPED_LUKS_PASSWORD}/******/g" "$FILE"
        fi
        if [ -n "$ESCAPED_ROOT_PASSWORD" ]; then
            sed -i "s/${ESCAPED_ROOT_PASSWORD}/******/g" "$FILE"
        fi
        if [ -n "$ESCAPED_USER_PASSWORD" ]; then
            sed -i "s/${ESCAPED_USER_PASSWORD}/******/g" "$FILE"
        fi
    fi
}

end(){
    execute_step "timestamp"
    execute_step "reboot"
}
