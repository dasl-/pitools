#!/usr/bin/env bash

set -euo pipefail -o errtrace

BASE_DIR=$HOME
NAME=''
PIN=''
CONFIG=/boot/config.txt

DOWNLOAD_DIR="$BASE_DIR""/cornrow"
CORNROW_PACKAGE_URL='https://github.com/mincequi/cornrow/releases/download/v0.8.1/cornrowd_0.8.1_armhf.deb'
PIN_FILE='/etc/bluetooth/pin.conf'

usage(){
    echo "Usage: $(basename "${0}") [-d <BASE_DIRECTORY>] [-n <NAME>] [-p <PIN>]"
    echo "Installs or updates a bluetooth audio server on a raspberry pi. Uses cornrow: https://github.com/mincequi/cornrow"
    echo "  -d BASE_DIRECTORY : Base directory in which to download files. Trailing slash optional."
    echo "                      Defaults to $BASE_DIR."
    echo "  -n NAME           : The name the service will advertise to iTunes."
    echo "                      Use %h for the hostname and %H for the Hostname. Defaults to %H."
    echo "  -p PIN            : The pin to use for bluetooth connections, e.g. 1234. Leave blank or omit for no pin."
    exit 1
}

main(){
    trap 'fail $? $LINENO' ERR

    parseOpts "$@"

    updatePackages

    installCornrow
    configureBluetoothPin
    updateBluetoothConfig

    info "Success!"
}

parseOpts(){
    while getopts ":d:n:p:h" opt; do
        case ${opt} in
            d)
                BASE_DIR=${OPTARG%/}  # remove trailing slash if present
                ;;
            n) NAME=${OPTARG} ;;
            p) PIN=${OPTARG} ;;
            \?)
                warn "Invalid option: -$OPTARG"
                usage
                ;;
            :)
                warn "Option -$OPTARG requires an argument."
                usage
                ;;
            *) usage ;;
        esac
    done
}

updatePackages(){
    info "Updating and installing packages..."
    sudo apt update
    sudo apt -y install bluez-tools # gives us bt-agent
    sudo apt -y full-upgrade
}

# See: https://github.com/mincequi/cornrow/#installation-binary
installCornrow(){
    info "Removing cornrow package if installed..."
    # Remove it first to ensure the systemd unit files get created freshly. This is important because we 
    # modify them later, so it's easier to assume they have an "untouched" state before we modify them.
    sudo apt remove -y cornrowd

    info "Downloading and installing cornrow package..."
    mkdir -p "$DOWNLOAD_DIR"
    pushd "$DOWNLOAD_DIR"
    wget --no-clobber "$CORNROW_PACKAGE_URL"
    sudo apt install ./"$(basename $CORNROW_PACKAGE_URL)"
    popd

    # Ensure cornrow can be active if and only if the bluetooth server is protected by the PIN.
    printf "\n[Unit]\nAfter=pitools-bluetooth-pin.service\nBindsTo=pitools-bluetooth-pin.service\n" | sudo tee --append /lib/systemd/system/cornrowd.service >/dev/null
}

configureBluetoothPin(){
    local pin_arg=''

    # If a blank pin was given, running btagent should be a no-op
    if [ -n "${PIN}" ]; then
         pin_arg="--pin=$PIN_FILE"
    fi

    cat <<-EOF | sudo tee /etc/systemd/system/pitools-bluetooth-pin.service >/dev/null
[Unit]
Description=Ensures clients must enter a pin to connect to the bluetooth server
After=sound.target
Requires=avahi-daemon.service bluetooth.service
After=avahi-daemon.service
After=bluetooth.service

[Service]
ExecStart=btagent --capability=NoInputNoOutput $pin_arg 
Restart=on-failure
StandardOutput=syslog
StandardError=syslog

[Install]
WantedBy=multi-user.target
EOF
}

updateBluetoothConfig(){
    info "Updating bluetooth config..."

    # Class = 0x040414 : this makes clients use a speaker icon for the bluetooth server, if the client supports showing icons.
    if ! grep -q '^Class = 0x040414' /etc/bluetooth/main.conf ; then
        printf "\n[General]\nClass = 0x040414\n" | sudo tee --append /etc/bluetooth/main.conf >/dev/null
    fi

    # JustWorksRepairing = always : I was having issues reconnecting if the client "forgot" the server. This fixes it. 
    #                               See: https://github.com/mincequi/cornrow/issues/27
    if ! grep -q '^JustWorksRepairing = always' /etc/bluetooth/main.conf ; then
        printf "\n[General]\nJustWorksRepairing = always\n" | sudo tee --append /etc/bluetooth/main.conf >/dev/null
    fi

    bluetoothctl system-alias \'"$NAME"\'

    if [ -n "${PIN}" ]; then
    cat <<-EOF | sudo tee "$PIN_FILE" >/dev/null
* $PIN
EOF
    else
        sudo rm -rf "$PIN_FILE"
    fi
}

startServices(){
    info "Starting cornrow service ..."
    sudo systemctl enable pitools-bluetooth-pin.service
    sudo systemctl unmask cornrowd.service
    sudo systemctl enable cornrowd.service
    sudo systemctl daemon-reload
    sudo systemctl restart pitools-bluetooth-pin.service
    sudo systemctl restart cornrowd.service
}

fail(){
    local exit_code=$1
    local line_no=$2
    local script_name
    script_name=$(basename "${BASH_SOURCE[0]}")
    die "Error in $script_name at line number: $line_no with exit code: $exit_code"
}

info(){
    echo -e "\x1b[32m$*\x1b[0m" # green stdout
}

warn(){
    echo -e "\x1b[33m$*\x1b[0m" # yellow stdout
}

die(){
    echo
    echo -e "\x1b[31m$*\x1b[0m" >&2 # red stderr
    exit 1
}

main "$@"
