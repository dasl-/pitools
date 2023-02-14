#!/usr/bin/env bash

# This installation script is based on: https://github.com/mikebrady/shairport-sync/blob/development/BUILDFORAP2.md
# See also:
# https://github.com/mikebrady/shairport-sync/blob/development/RELEASENOTES-DEVELOPMENT.md
# https://github.com/mikebrady/shairport-sync/blob/development/AIRPLAY2.md

set -euo pipefail -o errtrace

BASE_DIR=$HOME
NAME=''
CONFIG=/boot/config.txt

SHAIRPORT_SYNC_REPO_PATH="$BASE_DIR""/shairport-sync"
SHAIRPORT_SYNC_CLONE_URL=https://github.com/mikebrady/shairport-sync.git
SPS_BRANCH='development'

NQPTP_REPO_PATH="$BASE_DIR""/nqptp"
NQPTP_CLONE_URL=https://github.com/mikebrady/nqptp.git
NQPTP_BRANCH='development'

SKIP_CLONE_AND_PULL=false

usage(){
    echo "Usage: $(basename "${0}") [-d <BASE_DIRECTORY>] [-n <NAME>] [-b <SPS_BRANCH>] [-c <NQPTP_BRANCH>] [-s]"
    echo "Installs or updates shairport-sync on a raspberry pi."
    echo "  -d BASE_DIRECTORY : Base directory in which to clone shairport_sync. Trailing slash optional."
    echo "                      Defaults to $BASE_DIR."
    echo "  -n NAME           : The name the service will advertise to iTunes."
    echo "                      Use %h for the hostname and %H for the Hostname. Defaults to %H."
    echo "  -b SPS_BRANCH     : Git branch to use for shairport-sync. Defaults to $SPS_BRANCH."
    echo "  -c NQPTP_BRANCH   : Git branch to use for nqptp. Defaults to $NQPTP_BRANCH."
    echo "  -s                : skip pulling and cloning the shairport-sync and nqptp repos"
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
    while getopts ":d:n:b:c:hs" opt; do
        case ${opt} in
            d)
                BASE_DIR=${OPTARG%/}  # remove trailing slash if present
                SHAIRPORT_SYNC_REPO_PATH="$BASE_DIR""/shairport-sync"
                NQPTP_REPO_PATH="$BASE_DIR""/nqptp"
                ;;
            n) NAME=${OPTARG} ;;
            b) SPS_BRANCH=${OPTARG} ;;
            c) NQPTP_BRANCH=${OPTARG} ;;
            s) SKIP_CLONE_AND_PULL=true ;;
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
    sudo apt -y install --no-install-recommends build-essential git xmltoman autoconf automake libtool \
        libpopt-dev libconfig-dev libasound2-dev avahi-daemon libavahi-client-dev libssl-dev libsoxr-dev \
        libplist-dev libsodium-dev libavutil-dev libavcodec-dev libavformat-dev uuid-dev libgcrypt-dev xxd \
        libglib2.0-dev # libglib2.0-dev needed when building SPS with dbus support
    sudo apt -y full-upgrade
}

# https://github.com/raspberrypi/linux/issues/2522#issuecomment-692559920
# https://forums.raspberrypi.com/viewtopic.php?p=1764517#p1764517
disableWifiPowerManagement(){
    if grep -q '^dtoverlay=disable-wifi' $CONFIG ; then
        # Without this check, we'd get an error:
        #   Error for wireless request "Set Power Management" (8B2C) :
        #   SET failed on device wlan0 ; No such device.
        info 'wifi is disabled; skipping disabling of wifi power management...'
        return
    fi
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

buildNqptp(){
    info "Building nqptp..."
    pushd "$NQPTP_REPO_PATH"
    git checkout "$NQPTP_BRANCH"

    # pull again because if we were on another branch before, we need to pull after checking out the correct branch
    cloneOrPullRepo "$NQPTP_REPO_PATH" "$NQPTP_CLONE_URL"
    autoreconf -fi
    ./configure --with-systemd-startup
    make clean # more praying to the make gods? see the same `make clean` in buildShairportSync
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
    git checkout "$SPS_BRANCH"

    # pull again because if we were on another branch before, we need to pull after checking out the correct branch
    cloneOrPullRepo "$SHAIRPORT_SYNC_REPO_PATH" "$SHAIRPORT_SYNC_CLONE_URL"
    autoreconf -fi

    # Use CFLAGS to get more informative coredumps: https://github.com/mikebrady/shairport-sync/issues/1479
    CFLAGS="-O0 -g" CXXFLAGS="-O0 -g" ./configure --sysconfdir=/etc --with-alsa --with-soxr --with-avahi --with-ssl=openssl --with-systemd --with-airplay-2 --with-dbus-interface

    make clean # maybe this is necessary? https://github.com/mikebrady/shairport-sync/issues/1571#issuecomment-1312445078
    make -j
    sudo make install
    popd

    # Enable core dumps: https://github.com/mikebrady/shairport-sync/issues/1479
    printf "\n[Service]\nLimitCORE=infinity\n" | sudo tee --append /lib/systemd/system/shairport-sync.service >/dev/null
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

  // Fix issue where multiroom audio is sometimes a few milliseconds out of sync with Realtime Audio streams
  // See: https://github.com/mikebrady/shairport-sync/issues/1563#issuecomment-1328166125
  disable_standby_mode = "always";
};

diagnostics =
{
  log_verbosity = 2; // "0" means no debug verbosity, "3" is most verbose.
  statistics = "yes";
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
