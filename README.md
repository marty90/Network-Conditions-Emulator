# Network Conditions Emulator

This script artificially limits bandwidth, delay and loss rate on selected interfaces.
It allows traffic shaping on both downlink and uplink. It can enforce shaping on multiple interfaces at a time.

For information and suggestions please write to: martino.trevisan@polito.it

## Dependencies

This is a bash script to be used in a *Linux* environment.
It depends on the the package `tc`. Under the hood it uses the kernel module `ifb`.

## Usage

To start traffic shaping, you can run:
```
sudo ./network_emulator.sh <iface>:<downspeed>:<upspeed>:<rtt>:<loss>
```
where:
*  `<iface>` is the target physical interface you want to alterate
*  `<downspeed>` is the downlink capacity. Unit must be present, e.g., 20mbit.
*  `<upspeed>` is the uplink capacity. Unit must be present, e.g., 10mbit.
*  `<rtt>` is the RTT. Unit must be present, e.g., 50ms. It is enforced on the uplink.
*  `<loss>` is the loss probability. Must be followed by %, e.g., 10%. Enforced on both up and down link.

You can write multiple `<iface>:<downspeed>:<upspeed>:<rtt>:<loss>` to configure shaping on multiple interfaces. Under the hood it creates multiple virtual `ifb` interfaces to shape both down and uplink traffic.

You can omit one or more of `<downspeed>`, `<upspeed>`, `<rtt>`, `<loss>` to avoid enforcing shaping for those parameters. E.g., you can write a command for enforcing only RTT with: `<iface>:::<rtt>:`, like `wlan0:::50ms:`.

To remove all traffic shaping rules, use:
```
sudo ./network_emulator.sh remove
```

# Examples

Enforce 20mbit download, 5mbit upload, 20ms RTT and no packet loss on `eth0`.
```
sudo ./network_emulator.sh eth0:20mbit:5mbit:20ms:0%
```

Enforce 100ms RTT on `eth0`.
```
sudo ./network_emulator.sh eth0:::20ms:
```
Note that you can omit parameters that you don't want to shape.


Enforce 1% packet loss on `docker0`, `docker1` and `docker2` (if you are using docker container engine)

```
sudo ./network_emulator.sh docker0::::1% docker1::::1% docker2::::1%
```


