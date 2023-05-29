#!/usr/bin/env bash

set -euo pipefail -o errtrace

BASE_DIR=$HOME
NAME=$(hostname)
PIN=''
CONFIG=/boot/config.txt

BT_SPEAKER_REPO_PATH="$BASE_DIR""/bt-speaker"
BT_SPEAKER_CLONE_URL=git@github.com:dasl-/bt-speaker.git

usage(){
    echo "Usage: $(basename "${0}") [-d <BASE_DIRECTORY>] [-n <NAME>] [-p <PIN>]"
    echo "Installs or updates a bluetooth audio server on a raspberry pi. Uses bt-speaker: https://github.com/dasl-/bt-speaker"
    echo "  -d BASE_DIRECTORY : Base directory in which to download files. Trailing slash optional."
    echo "                      Defaults to $BASE_DIR."
    echo "  -n NAME           : The name the bluetooth server will advertise."
    echo "                      Defaults to the hostname: $NAME"
    echo "  -p PIN            : The PIN to use for bluetooth connections, e.g. 1234. Default is no PIN."
    exit 1
}

main(){
    trap 'fail $? $LINENO' ERR

    parseOpts "$@"

    updatePackages
    installBtSpeaker
    configureBtSpeaker
    updateBluetoothConfig
    startServices

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
    # See: https://github.com/dasl-/bt-speaker/blob/master/install.sh
    sudo apt -y install git bluez python3 python3-gi python3-gi-cairo python3-cffi python3-dbus python3-alsaaudio sound-theme-freedesktop vorbis-tools
    sudo apt -y full-upgrade
}

# See: https://github.com/dasl-/bt-speaker/blob/master/install.sh
installBtSpeaker(){
    info "Installing bt-speaker..."

    # Add btspeaker user if not exist already
    id -u btspeaker &>/dev/null || useradd btspeaker -G audio -d /opt/bt_speaker
    # Also add user to bluetooth group if it exists (required in debian stretch)
    getent group bluetooth &>/dev/null && usermod -a -G bluetooth btspeaker

    # Give the btspeaker user passwordless sudo for running hciconfig commands
    if ! sudo grep -q '^btspeaker ALL=(ALL) NOPASSWD: ALL' /etc/sudoers ; then
        printf "\nbtspeaker ALL=(ALL) NOPASSWD: ALL\n" | sudo tee --append /etc/sudoers >/dev/null
    fi

    cloneOrPullRepo "$BT_SPEAKER_REPO_PATH" "$BT_SPEAKER_CLONE_URL"

    mkdir -p /etc/bt_speaker/hooks
    cp -n "$BT_SPEAKER_REPO_PATH"/config.ini.default /etc/bt_speaker/config.ini
    cp -n "$BT_SPEAKER_REPO_PATH"/hooks.default/connect /etc/bt_speaker/hooks/connect
    cp -n "$BT_SPEAKER_REPO_PATH"/hooks.default/disconnect /etc/bt_speaker/hooks/disconnect
    cp -n "$BT_SPEAKER_REPO_PATH"/hooks.default/startup /etc/bt_speaker/hooks/startup
    cp -n "$BT_SPEAKER_REPO_PATH"/hooks.default/track /etc/bt_speaker/hooks/track

    local sspmode='1'
    if [ -n "${PIN}" ]; then
        sspmode='0'
    fi

cat <<-EOF | sudo tee /etc/systemd/system/bt-speaker.service >/dev/null
[Unit]
Description="Simple bluetooth speaker for the Raspberry Pi"
After=sound.target
Requires=avahi-daemon.service bluetooth.service
After=avahi-daemon.service
After=bluetooth.service

[Service]
WorkingDirectory=$BT_SPEAKER_REPO_PATH
# Enable PIN authorization for the bluetooth server
ExecStartPre=sudo hciconfig hci0 sspmode $sspmode
ExecStartPre=sudo hciconfig hci0 reset
ExecStart=$BT_SPEAKER_REPO_PATH/bt_speaker.py
Restart=always
User=btspeaker

[Install]
WantedBy=multi-user.target
EOF
}

# See: https://github.com/dasl-/bt-speaker/tree/master#config
configureBtSpeaker(){
    info "Configuring bt-speaker..."
    if [ -n "${PIN}" ]; then
        sudo sed /etc/bt_speaker/config.ini -i -e "s/^pin_code = .*/pin_code = $PIN/"
    fi
}

cloneOrPullRepo(){
    local repo_path="$1"
    local clone_url="$2"

    if [[ ${SKIP_CLONE_AND_PULL} == "true" ]]; then
        info "Skipping clone and pull of $repo_path ..."
        return
    fi

    mkdir -p "$BASE_DIR"
    if [ ! -d "$repo_path" ]
    then
        info "Cloning repo: $clone_url into $repo_path ..."
        git clone "$clone_url" "$repo_path"
    else
        info "Pulling repo in $repo_path ..."
        git -C "$repo_path" pull
    fi
}

updateBluetoothConfig(){
    info "Updating bluetooth config..."

    # Class = 0x040414 : this makes clients use a speaker icon for the bluetooth server, if the client supports showing icons.
    if ! grep -q '^Class = 0x040414' /etc/bluetooth/main.conf ; then
        printf "\n[General]\nClass = 0x040414\n" | sudo tee --append /etc/bluetooth/main.conf >/dev/null
    fi

    # Keep it discoverable
    if ! grep -q '^DiscoverableTimeout = 0' /etc/bluetooth/main.conf ; then
        printf "\n[General]\nDiscoverableTimeout = 0\n" | sudo tee --append /etc/bluetooth/main.conf >/dev/null
    fi

    bluetoothctl system-alias "$NAME"
}

startServices(){
    info "Restarting bluetooth and bt-speaker services..."

    sudo chown root:root /etc/systemd/system/bt-speaker.service
    sudo chmod 644 /etc/systemd/system/bt-speaker.service
    sudo systemctl enable /etc/systemd/system/bt-speaker.service

    sudo systemctl daemon-reload

    sudo systemctl restart bluetooth.service
    sudo systemctl restart bt-speaker.service
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
