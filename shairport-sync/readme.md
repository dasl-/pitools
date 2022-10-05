# readme

## dsh to install or update shairport sync on multiple pis:
```
dsh --remoteshell ssh --remoteshellopt '-o UserKnownHostsFile=/dev/null' --remoteshellopt '-o StrictHostKeyChecking=no' --remoteshellopt '-o LogLevel=ERROR' --concurrent-shell --show-machine-names --machine pi@study.local,pi@pifi.local,pi@piwall.local,pi@kitchen.local 'NAME="pi %h"; [[ $(hostname) == pi* ]] && NAME="%h" ; echo $NAME ; cd /home/pi/development/pitools && git pull && /home/pi/development/pitools/shairport-sync/install_or_update_shairport_sync.sh -d /home/pi/development -n $NAME -b development'
```