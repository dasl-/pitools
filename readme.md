# pitools: setup new raspberry pis
1. insert SD card into laptop / desktop
1. from laptop: `./setup_sd_card --disk-num <disk_num> --disk-image <disk_img> --wifi-network-name <network> --wifi-password <password>`
1. insert SD card into raspberry pi; boot raspberry pi
1. from laptop: `ssh pi@raspberrypi.local -- 'mkdir -p ~/.ssh' # maybe not needed?`
1. from laptop: `ssh-copy-id -i <~/.ssh/blah.pub> pi@piwall1.local`
1. from laptop: `scp ~/.ssh/id_ed25519_standard_raspberry_pi ~/.ssh/id_ed25519_standard_raspberry_pi.pub pi@raspberrypi.local:~/.ssh`
1. from laptop: `ssh pi@raspberrypi.local` (default password: `raspberry`)
1. from pi: `curl https://raw.githubusercontent.com/dasl-/pitools/main/provision_pi > provision_pi && chmod a+x provision_pi`
1. from pi: `./provision_pi -n <new_password> -h <hostname>`