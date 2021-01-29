# pitools: setup new raspberry pis
1. insert SD card into laptop / desktop
1. from laptop: `./001_setup_sd_card --disk-num <disk_num> --disk-image <disk_img> --wifi-network-name <network> --wifi-password <password>`
1. insert SD card into raspberry pi; boot raspberry pi
1. from laptop: `./002_provision_pi -i <SSH_KEY_TO_AUTHORIZE> -j <SSH_KEY_TO_ADD> -h <NEW_HOSTNAME> -p <NEW_PASSWORD]`

## development setup
1. The `provision_pi` script will install `rmate` / `subl`. We use a non-standard port though, which requires some extra setup. See comments in `provision_pi`. Your editor may also need a plugin to make use of this though: https://github.com/aurora/rmate#set-up-editor

## other useful commands for setting up
1. find its IP: `sudo arp-scan --interface=en0 --localnet` or `sudo nmap -sS -p 22 192.168.1.0/24`
