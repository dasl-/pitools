# pitools: setup new raspberry pis
1. insert SD card into laptop / desktop
1. from laptop: `./setup_sd_card --disk-num <disk_num> --disk-image <disk_img> --wifi-network-name <network> --wifi-password <password>`
1. insert SD card into raspberry pi; boot raspberry pi
1. from laptop: `ssh pi@raspberrypi.local -- 'mkdir -p ~/.ssh' # maybe not needed?`
1. from laptop: `ssh-copy-id -i ~/.ssh/path_to_key.pub pi@raspberrypi.local`
1. from laptop: `scp ~/.ssh/id_ed25519_standard_raspberry_pi ~/.ssh/id_ed25519_standard_raspberry_pi.pub pi@raspberrypi.local:~/.ssh`
1. from laptop: `ssh pi@raspberrypi.local -- 'mv ~/.ssh/id_ed25519_standard_raspberry_pi ~/.ssh/id_ed25519 &&
1. from laptop: `ssh pi@raspberrypi.local` (default password: `raspberry`)
1. from pi: `curl https://raw.githubusercontent.com/dasl-/pitools/main/provision_pi > provision_pi && chmod a+x provision_pi`
1. from pi: `./provision_pi -n <new_password> -h <hostname>`

## development setup
1. The `provision_pi` script will install `rmate` / `subl`. We use a non-standard port though, which requires some extra setup. See comments in `provision_pi`. Your editor may also need a plugin to make use of this though: https://github.com/aurora/rmate#set-up-editor

## other useful commands for setting up
1. find its IP: `sudo arp-scan --interface=en0 --localnet` or `sudo nmap -sS -p 22 192.168.1.0/24`
