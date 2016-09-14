#!/bin/bash

VIR=ifb0
PHY=$1
ACTION=$2
IN=$3
OUT=$4

function go() {
    echo "$*"
    eval "$*"
    return $?
}

# 1. In case of "init" command, initialize the virtual interface ifb0
if [ $# -eq 1 ]; then
    if [ $1 == "init" ]; then
        echo "Initializing"
        go modprobe ifb numifbs=1
        go ip link set dev ifb0 up
        exit 0
    fi
fi

# Parse input and output values, consider missing values indicated with "-"
[ "$IN" == "-" ] && IN=
[ "$OUT" == "-" ] && OUT=

go tc qdisc del dev $PHY root       # clear outgoing
go tc qdisc del dev $PHY ingress    # clear incoming
go tc qdisc del dev $VIR root       # clean incoming

# Quit if missing arguments
[ $# -eq 0 ] && exit 0

# Create Device Pipes
go tc qdisc add dev $PHY handle ffff: ingress
go tc filter add dev $PHY parent ffff: protocol ip u32 match u32 0 0 action mirred egress redirect dev ifb0

# 2. Set delay 
if [ $ACTION == "delay" ]; then

    if [ -n "$IN" ]; then
        # incoming
        go tc qdisc add dev $VIR root handle 1: netem delay $IN
    fi

    if [ -n "$OUT" ]; then
        # outgoing
        go tc qdisc add dev $PHY root handle 1: netem delay $OUT
    fi
fi

# 3. Set maximum rate 
if [ $ACTION == "rate" ]; then

    if [ -n "$IN" ]; then
        # incoming
        go tc qdisc add dev $VIR root handle 1: htb default 10
        go tc class add dev $VIR parent 1: classid 1:1 htb rate $IN
        go tc class add dev $VIR parent 1:1 classid 1:10 htb rate $IN
    fi

    if [ -n "$OUT" ]; then
        # outgoing
        go tc qdisc add dev $PHY root handle 1: htb default 10
        go tc class add dev $PHY parent 1: classid 1:1 htb rate $OUT
        go tc class add dev $PHY parent 1:1 classid 1:10 htb rate $OUT
    fi

fi

# 4. Set loss rate 
if [ $ACTION == "loss" ]; then

    if [ -n "$IN" ]; then
        # incoming
        go tc qdisc add dev $VIR root handle 1: netem loss $IN
    fi

    if [ -n "$OUT" ]; then
        # outgoing
        go tc qdisc add dev $PHY root handle 1: netem loss $OUT
    fi
fi


