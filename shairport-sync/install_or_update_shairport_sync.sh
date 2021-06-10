#!/usr/bin/env bash

# This installation script is based on: https://github.com/mikebrady/shairport-sync/blob/master/INSTALL.md
# for updating, see: https://github.com/mikebrady/shairport-sync/blob/master/UPDATING.md

set -eEou pipefail

BASE_DIR=/home/pi
REPO_PATH="$BASE_DIR""/shairport-sync"

usage(){
    echo "Usage: $(basename "${0}")"
    echo "Installs or updates shairport-sync on a raspberry pi."
    echo "  -d BASE_DIRECTORY : Base directory in which to clone shairport_sync. Trailing slash optional."
    echo "                      Defaults to $BASE_DIR."
    exit 1
}

while getopts "d:" opt; do
    case ${opt} in
        d)
            BASE_DIR=${OPTARG%/}  # remove trailing slash if present
            REPO_PATH="$BASE_DIR""/shairport-sync"
            ;;
        *) usage ;;
    esac
done

main(){
    trap 'fail $? $LINENO' ERR
    updatePackages
    disableWifiPowerManagement
    removeOldVersions
    cloneOrPullRepo
    build
    maybeConfigure
    startService
}

fail(){
    local exit_code=$1
    local line_no=$2
    die "Error at line number: $line_no with exit code: $exit_code"
}

updatePackages(){
    info "Updating and installing packages..."
    sudo apt update
    sudo apt -y install build-essential git xmltoman autoconf automake libtool \
        libpopt-dev libconfig-dev libasound2-dev avahi-daemon libavahi-client-dev libssl-dev libsoxr-dev
    sudo apt -y full-upgrade
}

# https://github.com/raspberrypi/linux/issues/2522#issuecomment-692559920
disableWifiPowerManagement(){
    info "Disabling wifi power management..."

    # disable it
    sudo iwconfig wlan0 power off

    # ensure it stays disabled after reboots
    echo "iwconfig wlan0 power off" | sudo tee -a /etc/rc.local >/dev/null 2>&1
    echo "exit 0" | sudo tee -a /etc/rc.local >/dev/null 2>&1
}

removeOldVersions(){
    info "Removing old versions (if found)..."
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

    # these might exit non-zero if the service is not yet installed
    sudo systemctl stop shairport-sync.service || true
    sudo systemctl disable shairport-sync.service || true
    sudo systemctl daemon-reload || true
    sudo systemctl reset-failed || true
}

cloneOrPullRepo(){
    mkdir -p "$BASE_DIR"
    if [ ! -d "$REPO_PATH" ]
    then
        info "Cloning repo..."
        git clone https://github.com/mikebrady/shairport-sync.git "$REPO_PATH"
    else
        info "Pulling repo..."
        git -C "$REPO_PATH" pull
    fi
}

build(){
    info "Building... This may take a while..."
    pushd "$REPO_PATH"
    autoreconf -fi
    ./configure --sysconfdir=/etc --with-alsa --with-soxr --with-avahi --with-ssl=openssl --with-systemd
    make
    sudo make install
    popd
}

# Only add configuration file if it is not already present
maybeConfigure(){
    # If the shairport-sync.conf file matches the sample file, assume it has not been modified and is
    # safe to overwrite.
    if diff -qs /etc/shairport-sync.conf /etc/shairport-sync.conf.sample ; then
        info "Not specifying default configuration because a user modified configuration file already exists."
    else
        info "Configuring..."
        cat <<-EOF | sudo tee /etc/shairport-sync.conf >/dev/null
// Sample Configuration File for Shairport Sync on a Raspberry Pi using the built-in audio DAC
general =
{
  volume_range_db = 60;
};

alsa =
{
  output_device = "hw:Headphones";
  mixer_control_name = "Headphone";
};
EOF
    fi
}

startService(){
    info "Starting service..."
    sudo systemctl enable shairport-sync
    sudo systemctl daemon-reload
    sudo systemctl restart shairport-sync
}

info() {
    echo -e "\x1b[32m$*\x1b[0m" # green stdout
}

die() {
    echo
    echo -e "\x1b[31m$*\x1b[0m" >&2 # red stderr
    exit 1
}

main
