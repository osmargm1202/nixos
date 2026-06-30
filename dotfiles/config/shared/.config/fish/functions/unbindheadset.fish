function unbindheadset
    if type -q hypr-usb-menu
        hypr-usb-menu reconnect $argv
        return $status
    end

    echo "hypr-usb-menu no está instalado" >&2
    return 1
end
