# wifi to ethernet bridge
Credit for this script: https://willhaley.com/blog/raspberry-pi-wifi-ethernet-bridge/

Here is my [setup](https://docs.google.com/presentation/d/1NHyvYS5v8WRHY5q7YmZTV3cj14xaC5Out0w3xllHC2k/edit#slide=id.p):

<img src="setup.png" alt="wifi to ethernet bridge setup diagram" width="800">

I ran speed tests to see how this setup performs, comparing a **wifi pi** to a **bridged pi**:

* **wifi pi**: a pi connected directly to the router via wifi
    * `router -(wifi)-> pi`
* **bridged pi**: a pi connected to the bridge
    * `router -(wifi)-> bridge -(ethernet)-> switch -(ethernet)-> pi`

Results:
* median ping was 2.4% higher on the bridged pi.
* median download speed was 3.6% slower on the bridged pi
* median upload speed was 0.1% slower on the bridged pi

The slowdown from the bridge is negligible.

Speed tests were run via `speedtest-cli`:
```
% sudo pip3 install speedtest-cli
% speedtest
```

Full results: https://docs.google.com/spreadsheets/d/1-WUZSzvB3wJ5-m9yriUo3j6dz_ukoy15ta80-tGRKEw/edit#gid=0
