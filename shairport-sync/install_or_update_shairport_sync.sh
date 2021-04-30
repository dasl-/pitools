#!/usr/bin/env bash

# This installation script is based on: https://github.com/mikebrady/shairport-sync/blob/master/INSTALL.md
# for updating, see: https://github.com/mikebrady/shairport-sync/blob/master/UPDATING.md

set -eou pipefail

is_second_run=false
BASE_DIR=/home/pi/development
REPO_PATH="$BASE_DIR""/shairport-sync"

usage(){
    echo "Usage: $(basename "${0}") [-x]"
    echo "Install shairport-sync https://github.com/mikebrady/shairport-sync."
    echo "Running this script is a two part process. After the first run, a reboot will occur."
    echo "After rebooting, re-run this script with the -x flag."
    echo "  -x     : Run the installation steps after rebooting"
    exit 1
}

while getopts "x" opt; do
    case ${opt} in
        x) is_second_run=true ;;
        *) usage ;;
      esac
done

main(){
    if [[ ${is_second_run} == "false" ]]; then
        updatePackages
        # disableWifiPowerManagement let's see if this causes problems before disabling.
        removeOldVersions
        reboot
    else
        cloneOrPullRepo
        build
        maybeConfigure
        startService
    fi
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
        /etc/dbus-1/system.d/shairport-sync-mpris.conf
}

reboot(){
    info "Rebooting..."
    info "When done rebooting, re-run this script with the -x flag to complete installation."
    sudo shutdown -r now
}

cloneOrPullRepo(){
    mkdir -p $BASE_DIR
    if [ ! -d $REPO_PATH ]
    then
        info "Cloning repo..."
        git clone https://github.com/mikebrady/shairport-sync.git $REPO_PATH
    else
        info "Pulling repo..."
        git -C $REPO_PATH pull
    fi
}

build(){
    info "Building... This may take a while..."
    cd $REPO_PATH
    autoreconf -fi
    ./configure --sysconfdir=/etc --with-alsa --with-soxr --with-avahi --with-ssl=openssl --with-systemd
    make
    sudo make install
}

# Only add configuration file if it is not already present
maybeConfigure(){
if [ ! -f /etc/shairport-sync.conf ]; then
    cat <<-EOF | sudo tee /etc/shairport-sync.conf >/dev/null
// Sample Configuration File for Shairport Sync on a Raspberry Pi using the built-in audio DAC
general =
{
  volume_range_db = 60;
};

alsa =
{
  output_device = "hw:0";
  mixer_control_name = "PCM";
};
EOF
fi
}

startService(){
    sudo systemctl enable shairport-sync
    sudo systemctl daemon-reload
    sudo systemctl restart shairport-sync
}

info() {
    echo -e "\x1b[32m$@\x1b[0m" # green stdout
}

die() {
    echo
    echo -e "\x1b[31m$@\x1b[0m" >&2 # red stderr
    exit 1
}

main
