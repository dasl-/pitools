#!/usr/bin/env bash

# This installation script is based on: https://github.com/mikebrady/shairport-sync/blob/development/BUILDFORAP2.md
# See also:
# https://github.com/mikebrady/shairport-sync/blob/development/RELEASENOTES-DEVELOPMENT.md
# https://github.com/mikebrady/shairport-sync/blob/development/AIRPLAY2.md

set -euo pipefail

BASE_DIR=/home/pi
NAME=''

SHAIRPORT_SYNC_REPO_PATH="$BASE_DIR""/shairport-sync"
SHAIRPORT_SYNC_CLONE_URL=https://github.com/mikebrady/shairport-sync.git

NQPTP_REPO_PATH="$BASE_DIR""/nqptp"
NQPTP_CLONE_URL=https://github.com/mikebrady/nqptp.git

usage(){
    echo "Usage: $(basename "${0}") [-d <BASE_DIRECTORY>] [-n <NAME>]"
    echo "Installs or updates shairport-sync on a raspberry pi."
    echo "  -d BASE_DIRECTORY : Base directory in which to clone shairport_sync. Trailing slash optional."
    echo "                      Defaults to $BASE_DIR."
    echo "  -n NAME           : The name the service will advertise to iTunes."
    echo "                      Use %h for the hostname and %H for the Hostname. Defaults to %H."
    exit 1
}

main(){
    trap 'fail $? $LINENO' ERR

    parseOpts "$@"

    updatePackages
    disableWifiPowerManagement
    removeOldVersions

    # nqptp
    cloneOrPullRepo "$NQPTP_REPO_PATH" "$NQPTP_CLONE_URL"
    buildNqptp
    startNqptpService

    # shairport-sync
    cloneOrPullRepo "$SHAIRPORT_SYNC_REPO_PATH" "$SHAIRPORT_SYNC_CLONE_URL"
    buildShairportSync
    maybeConfigureShairportSync
    startShairportSyncService

    info "Success!"
}

parseOpts(){
    while getopts "d:n:h" opt; do
        case ${opt} in
            d)
                BASE_DIR=${OPTARG%/}  # remove trailing slash if present
                SHAIRPORT_SYNC_REPO_PATH="$BASE_DIR""/shairport-sync"
                NQPTP_REPO_PATH="$BASE_DIR""/nqptp"
                ;;
            n) NAME=${OPTARG} ;;
            *) usage ;;
        esac
    done
}

updatePackages(){
    info "Updating and installing packages..."
    sudo apt update
    sudo apt -y install --no-install-recommends build-essential git xxd xmltoman autoconf automake libtool \
        libpopt-dev libconfig-dev libasound2-dev avahi-daemon libavahi-client-dev libssl-dev libsoxr-dev \
        libplist-dev libsodium-dev libavutil-dev libavcodec-dev libavformat-dev uuid-dev libgcrypt-dev \
        libglib2.0-dev

    sudo apt -y full-upgrade
}

# https://github.com/raspberrypi/linux/issues/2522#issuecomment-692559920
# https://forums.raspberrypi.com/viewtopic.php?p=1764517#p1764517
disableWifiPowerManagement(){
    if ! grep -q '^iwconfig wlan0 power off' /etc/rc.local ; then
        info "Disabling wifi power management..."

        # disable it
        sudo iwconfig wlan0 power off

        # ensure it stays disabled after reboots
        if [ "$(grep --count '^exit 0$' /etc/rc.local)" -ne 1 ] ; then
           die "Unexpected contents in /etc/rc.local"
        fi
        sudo sed /etc/rc.local -i -e "s/^exit 0$/iwconfig wlan0 power off/"
        echo "exit 0" | sudo tee -a /etc/rc.local >/dev/null 2>&1
    else
        info "Wifi power management already disabled"
    fi
}

removeOldVersions(){
    info "Removing old versions of shairport-sync (if found)..."
    while [ "$(which shairport-sync)" ]
    do
        sudo rm "$(which shairport-sync)"
    done

    sudo rm -rf \
        /etc/systemd/system/shairport-sync.service \
        /lib/systemd/system/shairport-sync.service \
        /etc/init.d/shairport-sync \
        /etc/dbus-1/system.d/shairport-sync-dbus.conf \
        /etc/dbus-1/system.d/shairport-sync-mpris.conf \
        /usr/lib/systemd/system/shairport-sync.service

    # some of these might exit non-zero if the service is not yet installed, hence the redirecting
    # stderr to /dev/null and ORing with `true`
    sudo systemctl stop shairport-sync.service 2>/dev/null || true
    sudo systemctl disable shairport-sync.service 2>/dev/null || true
    sudo systemctl daemon-reload
    sudo systemctl reset-failed
}

cloneOrPullRepo(){
    local repo_path="$1"
    local clone_url="$2"
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

buildNqptp(){
    info "Building nqptp..."
    pushd "$NQPTP_REPO_PATH"
    autoreconf -fi
    ./configure --with-systemd-startup
    make
    sudo make install
    popd
}

startNqptpService(){
    info "Starting nqptp service"
    sudo systemctl enable nqptp
    sudo systemctl daemon-reload
    sudo systemctl restart nqptp
}

buildShairportSync(){
    info "Building shairport-sync... This may take a while..."
    pushd "$SHAIRPORT_SYNC_REPO_PATH"
    git checkout development
    autoreconf -fi
    ./configure --sysconfdir=/etc --with-alsa --with-soxr --with-avahi --with-ssl=openssl --with-systemd --with-airplay-2 --with-dbus-interface
    make -j
    sudo make install
    popd
}

# Only add configuration file if it is not already present
# See sample raspberry pi config file:
# https://github.com/mikebrady/shairport-sync/blob/development/BUILDFORAP2.md#configure
#
# My deviation in volume settings from the sample config file is intentional :)
maybeConfigureShairportSync(){
    # If the shairport-sync.conf file matches the sample file, assume it has not been modified and is
    # safe to overwrite. Same if the config file does not exist.
    local config_file_path='/etc/shairport-sync.conf'
    if diff -qs $config_file_path /etc/shairport-sync.conf.sample || [ ! -f $config_file_path ] ; then
        info "Configuring shairport-sync..."
        name_string=''
        if [ -n "${NAME}" ]; then
            name_string='name = "'"$NAME"'";'
        fi
        cat <<-EOF | sudo tee $config_file_path >/dev/null
general =
{
  // More info about volume on pis:
  // https://github.com/dasl-/piwall2/blob/d357c3766979d473f8135448ccf36935a4fa608a/piwall2/volumecontroller.py#L22
  volume_range_db = 40; // make volume line up approximately with my own logarithmic volume algorithm on pis
  volume_max_db = 0.0; // prevent clipping on raspberry pis
  $name_string
};

alsa =
{
  output_device = "hw:Headphones";
  mixer_control_name = "Headphone";
};
EOF
    else
        info "Not specifying default configuration because a user modified configuration file already exists."
    fi
}

startShairportSyncService(){
    info "Starting shairport-sync service..."
    sudo systemctl enable shairport-sync
    sudo systemctl daemon-reload
    sudo systemctl restart shairport-sync
}

fail(){
    local exit_code=$1
    local line_no=$2
    die "Error at line number: $line_no with exit code: $exit_code"
}

info() {
    echo -e "\x1b[32m$*\x1b[0m" # green stdout
}

die() {
    echo
    echo -e "\x1b[31m$*\x1b[0m" >&2 # red stderr
    exit 1
}

main "$@"
