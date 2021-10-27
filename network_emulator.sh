#!/bin/bash

# Default values
DEFAULT_DOWNLOAD="40000mbit"
DEFAULT_UPLOAD="40000mbit"
DEFAULT_RTT="0ms"
DEFAULT_LOSS="0%"

BURST=32kb

# Utility Function
function go() {
    #echo "$*"
    eval "$*"
    return $?
}

# Parse Args
REMOVE=false
RULES=""

for ARG in "$@" ; do
    if [ "$ARG" = "remove" ] ; then
        REMOVE=true
    elif [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] ; then
        echo "network_emulator.sh COMMAND..."
        echo "COMMAND can be:"
        echo "   remove : delete all shaping rules"
        echo "   -h, --help : show this help"
        echo "   <iface>:<downspeed>:<upspeed>:<rtt>:<loss> : a rule to be applied to <iface>."
        echo "                                                You can omit one parameter (e.g., no RTT means RTT=0ms)."
        echo "                                                Multiple rules are allowed to configure multiple interfaces"
        echo "                                                Warning: multiple runs are not allowed."
        echo "                                                To configure multiple interfaces, use multiple arguments, not multiple commands."
        exit
    else
        RULES="${RULES} ${ARG}"
    fi
done


if [ "$REMOVE" = true ]; then
    # Remove old shaping rules
    echo "Removing all traffic shaping"

    # Remove module IFB
    go rmmod ifb 2>/dev/null

    # Remove all TC policies
    for INTERFACE in $( ifconfig -a | sed 's/[: \t].*//;/^$/d' | grep -v ifb ) ; do

        go tc qdisc del root dev $INTERFACE 2>/dev/null
        go tc qdisc del dev $INTERFACE handle ffff: ingress 2>/dev/null

    done

else
    # Create rules
    NB_RULES=$( echo $RULES | wc -w)
    echo "Setting shaping on $NB_RULES interfaces"

    #Create virtual interfaces
    go rmmod ifb 2>/dev/null
    go modprobe ifb numifbs=$NB_RULES

    i=0
    for RULE in $RULES ; do

        # Get values
        INTERFACE=$(echo $RULE | cut -d : -f 1)
        DOWNLOAD=$(echo $RULE | cut -d : -f 2)
        UPLOAD=$(echo $RULE | cut -d : -f 3)
        RTT=$(echo $RULE | cut -d : -f 4)
        LOSS=$(echo $RULE | cut -d : -f 5)

        if [ -z "$DOWNLOAD" ]; then DOWNLOAD=$DEFAULT_DOWNLOAD ; fi
        if [ -z "$UPLOAD" ]; then UPLOAD=$DEFAULT_UPLOAD ; fi
        if [ -z "$RTT" ]; then RTT=$DEFAULT_RTT ; fi
        if [ -z "$LOSS" ]; then LOSS=$DEFAULT_LOSS ; fi

        echo "Interface $INTERFACE:"
        echo "    Download: $DOWNLOAD"
        echo "    Upload:   $UPLOAD"
        echo "    RTT:      $RTT"
        echo "    Loss:     $LOSS"

        # Determine virtual interface and set it up
        VIRTUAL=ifb${i}
        ip link set dev $VIRTUAL up

        # Clear old
        go tc qdisc del root dev $INTERFACE 2>/dev/null       # clear outgoing
        go tc qdisc del dev $INTERFACE handle ffff: ingress 2>/dev/null    # clear incoming
        go tc qdisc del root dev $VIRTUAL 2>/dev/null


        # Create Device Pipes
        go tc qdisc add dev $INTERFACE handle ffff: ingress
        go tc filter add dev $INTERFACE parent ffff: protocol ip u32 match u32 0 0 \
                                        action mirred egress redirect dev $VIRTUAL


        # INCOMING
        # Speed
        go tc qdisc add dev $VIRTUAL root handle 2: tbf rate $DOWNLOAD burst $BURST limit $BURST
        # Loss rate
        if [ "$LOSS" != "$DEFAULT_LOSS" ] ; then
            go tc qdisc add dev $VIRTUAL parent 2:  handle 20: netem loss $LOSS
        fi

        # OUTGOING
        # Speed
        go tc qdisc add dev $INTERFACE root handle 1: tbf rate $UPLOAD burst $BURST limit $BURST
        # Delay and Loss rate
        if [ "$LOSS" != "$DEFAULT_LOSS" ] ; then
            go tc qdisc add dev $INTERFACE parent 1: handle 10: netem delay $RTT loss $LOSS
        else
            go tc qdisc add dev $INTERFACE parent 1: handle 10: netem delay $RTT
        fi

        # Increment Counter
        i=$(( $i + 1 ))

    done


fi
