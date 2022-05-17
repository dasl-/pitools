# pitools: setup new raspberry pis
1. insert SD card into laptop / desktop
1. from laptop: `./001_setup_sd_card --disk-num <disk_num> --disk-image <disk_img> --wifi-network-name <network> --wifi-password <password>`
1. insert SD card into raspberry pi; boot raspberry pi
1. from laptop: `./002_provision_pi -u <USER_NAME> -p <PASSWORD> -i <SSH_KEY_TO_AUTHORIZE> -j <SSH_KEY_TO_ADD> -h <NEW_HOSTNAME> -e <GIT_USER_EMAIL> -f <GIT_USER_NAME>`

## help output
```
% sudo ./001_setup_sd_card -h
usage: 001_setup_sd_card [-h] --disk-num DISK_NUM --disk-image DISK_IMAGE [--device-path DEVICE_PATH] --user-name USER_NAME --user-password USER_PASSWORD --wifi-network-name WIFI_NETWORK_NAME
                         --wifi-password WIFI_PASSWORD [--wifi-country-code WIFI_COUNTRY_CODE]

Setup new sd card for raspberry pi. Must be run as sudo. Images disk, sets up wifi, sets up ssh. Run from laptop.

optional arguments:
  -h, --help            show this help message and exit
  --disk-num DISK_NUM   Disk number via `diskutil list`. This disk will be overwritten, so don't get this wrong. (default: None)
  --disk-image DISK_IMAGE
                        Path to disk image. Download Raspberry Pi OS Lite image from https://www.raspberrypi.org/software/operating-systems/ (default: None)
  --device-path DEVICE_PATH
                        Mounted volume path after SD card has been imaged. (default: /Volumes/boot)
  --user-name USER_NAME
                        User account to create (default: None)
  --user-password USER_PASSWORD
                        Password for the user account (default: None)
  --wifi-network-name WIFI_NETWORK_NAME
                        Name of the network to join (default: None)
  --wifi-password WIFI_PASSWORD
                        Password of the network to join (default: None)
  --wifi-country-code WIFI_COUNTRY_CODE
                        Your ISO-3166-1 two-letter country code. See: https://www.iso.org/obp/ui/#search (default: US)
```

```
% ./002_provision_pi -h
Usage: 002_provision_pi -u <USER_NAME> -p <PASSWORD> [-i <SSH_KEY_TO_AUTHORIZE>] [-j <SSH_KEY_TO_ADD>] [-h <NEW_HOSTNAME>] [-g <OLD_HOSTNAME>] [-e <GIT_USER_EMAIL>] [-f <GIT_USER_NAME>] [-s]
Run this from laptop.
  -u USER_NAME            : User name for the raspberry pi's user account.
  -p PASSWORD             : Password for the raspberry pi's user account.
  -i SSH_KEY_TO_AUTHORIZE : path to ssh key to add to authorized_keys for passwordless login on raspberry pi
                            Defaults to: /Users/davidleibovic/.ssh/id_ed25519.pub
  -j SSH_KEY_TO_ADD       : path to ssh key to copy to ~/.ssh on the raspberry pi. If you specify the public
                            key path, the corresponding private key will also be copied and vice versa.
                            Defaults to: /Users/davidleibovic/standard_raspberry_pi_key/id_ed25519.pub
  -h NEW_HOSTNAME         : Change the raspberry pi's hostname. Defaults to raspberrypi.
  -g OLD_HOSTNAME         : Defaults to raspberrypi
  -e GIT_USER_EMAIL       : email address for git
  -f GIT_USER_NAME        : user name for git
  -s                      : Enable SPI
```

## development setup
1. The `provision_pi` script will install `rmate` / `subl`. Your editor may also need a plugin to make use of this though: https://github.com/aurora/rmate#set-up-editor

## other useful commands for setting up
1. find its IP: `sudo arp-scan --interface=en0 --localnet` or `sudo nmap -sS -p 22 192.168.1.0/24`
