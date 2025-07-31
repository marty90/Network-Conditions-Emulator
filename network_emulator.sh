#!/bin/bash

# Default values
DEFAULT_DOWNLOAD="40000mbit"
DEFAULT_UPLOAD="40000mbit"
DEFAULT_RTT="0ms"
DEFAULT_LOSS="0%"

BURST=32kb

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root (with administrator privileges)"
    echo "Please run with sudo or as administrator"
    exit 1
fi

# Utility Function
function go() {
    #echo "$*"
    eval "$*"
    return $?
}

# Help function
function show_help() {
    echo "network_emulator.sh COMMAND..."
    echo "Note: This script requires root privileges (run with sudo or as administrator)"
    echo "COMMAND can be:"
    echo "   remove : delete all shaping rules"
    echo "   -h, --help : show this help"
    echo "   <iface>:<downspeed>:<upspeed>:<rtt>:<loss> : a rule to be applied to <iface>."
    echo "                                                You can omit one parameter (e.g., no RTT means RTT=0ms)."
    echo "                                                Multiple rules are allowed to configure multiple interfaces"
    echo "                                                Warning: multiple runs are not allowed."
    echo "                                                To configure multiple interfaces, use multiple arguments, not multiple commands."
    echo "Examples:"
    echo "   sudo network_emulator.sh eth0:10mbit:10mbit:100ms:1%"
    echo "   sudo network_emulator.sh eth0:10mbit:10mbit:100ms:1% eth1:5mbit:5mbit"
}

# Function to validate network parameters
function validate_rule() {
    local rule="$1"
    local interface=$(echo "$rule" | cut -d : -f 1)
    local download=$(echo "$rule" | cut -d : -f 2)
    local upload=$(echo "$rule" | cut -d : -f 3)
    local rtt=$(echo "$rule" | cut -d : -f 4)
    local loss=$(echo "$rule" | cut -d : -f 5)
    
    # Check if interface name is provided
    if [ -z "$interface" ]; then
        echo "Error: No interface specified in rule '$rule'"
        return 1
    fi
    
    # Check if interface exists
    if ! ip link show "$interface" >/dev/null 2>&1; then
        echo "Error: Interface '$interface' not found"
        return 1
    fi
    
    # Validate download speed format (if provided)
    if [ -n "$download" ] && ! [[ "$download" =~ ^[0-9]+[kmgt]?bit$ ]]; then
        echo "Error: Invalid download speed format '$download' in rule '$rule'"
        echo "Expected format: <number>[k|m|g|t]bit (e.g., 1000mbit, 100kbit)"
        return 1
    fi
    
    # Validate upload speed format (if provided)
    if [ -n "$upload" ] && ! [[ "$upload" =~ ^[0-9]+[kmgt]?bit$ ]]; then
        echo "Error: Invalid upload speed format '$upload' in rule '$rule'"
        echo "Expected format: <number>[k|m|g|t]bit (e.g., 1000mbit, 100kbit)"
        return 1
    fi
    
    # Validate RTT format (if provided)
    if [ -n "$rtt" ] && ! [[ "$rtt" =~ ^[0-9]+ms$ ]]; then
        echo "Error: Invalid RTT format '$rtt' in rule '$rule'"
        echo "Expected format: <number>ms (e.g., 100ms, 50ms)"
        return 1
    fi
    
    # Validate loss rate format (if provided)
    if [ -n "$loss" ] && ! [[ "$loss" =~ ^[0-9]+(\.[0-9]+)?%$ ]]; then
        echo "Error: Invalid loss rate format '$loss' in rule '$rule'"
        echo "Expected format: <number>% (e.g., 1%, 0.5%)"
        return 1
    fi
    
    return 0
}

# Parse Args
REMOVE=false
RULES=""

# Check if no arguments provided
if [ $# -eq 0 ]; then
    show_help
    exit 1
fi

# Parse arguments
for ARG in "$@" ; do
    case "$ARG" in
        "remove")
            REMOVE=true
            ;;
        "-h"|"--help")
            show_help
            exit 0
            ;;
        *)
            # Validate rule format (interface:download:upload:rtt:loss)
            if [[ "$ARG" =~ ^[^:]+:.*$ ]]; then
                RULES="${RULES} ${ARG}"
            else
                echo "Error: Invalid rule format '$ARG'"
                echo "Expected format: <interface>:<download>:<upload>:<rtt>:<loss>"
                echo "Use -h or --help for more information"
                exit 1
            fi
            ;;
    esac
done

# Validate arguments combination
if [ "$REMOVE" = true ] && [ -n "$RULES" ]; then
    echo "Error: Cannot use 'remove' with interface rules"
    echo "Use either 'remove' alone or provide interface rules"
    exit 1
fi

if [ "$REMOVE" = false ] && [ -z "$RULES" ]; then
    echo "Error: No rules provided"
    show_help
    exit 1
fi


if [ "$REMOVE" = true ]; then
    # Remove old shaping rules
    echo "Removing all traffic shaping"

    # Remove module IFB
    go rmmod ifb 2>/dev/null

    # Remove all TC policies
    for INTERFACE in $(ip link show | sed -n 's/^[0-9]*: \([^:]*\):.*/\1/p' | grep -v ifb) ; do

        echo "Removing rules for interface: $INTERFACE"
        go tc qdisc del root dev $INTERFACE 2>/dev/null
        go tc qdisc del dev $INTERFACE handle ffff: ingress 2>/dev/null

    done

    echo "All traffic shaping removed successfully"
    exit 0
else
    # Create rules
    NB_RULES=$( echo $RULES | wc -w)
    echo "Setting shaping on $NB_RULES interfaces"
    
    # Validate ALL rules first - exit if any rule is invalid
    echo "Validating all interface rules..."
    VALIDATION_FAILED=false
    
    for RULE in $RULES ; do
        echo "Validating rule: $RULE"
        if ! validate_rule "$RULE"; then
            VALIDATION_FAILED=true
        fi
    done
    
    # Exit if validation failed for any rule
    if [ "$VALIDATION_FAILED" = true ]; then
        echo ""
        echo "Error: One or more rules failed validation"
        echo "Please fix the invalid rules and try again"
        echo "Use -h or --help for correct format information"
        exit 1
    fi
    
    echo "All rules validated successfully!"

    #Create virtual interfaces
    go rmmod ifb 2>/dev/null
    go modprobe ifb numifbs=$NB_RULES

    i=0
    for RULE in $RULES ; do
        echo "Applying rule: $RULE"

        IFS=':' read -ra RULE_PARTS <<< "$RULE"
        
        INTERFACE="${RULE_PARTS[0]}"
        DOWNLOAD="${RULE_PARTS[1]:-$DEFAULT_DOWNLOAD}"
        UPLOAD="${RULE_PARTS[2]:-$DEFAULT_UPLOAD}"
        RTT="${RULE_PARTS[3]:-$DEFAULT_RTT}"
        LOSS="${RULE_PARTS[4]:-$DEFAULT_LOSS}"

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

    echo ""
    echo "All traffic shaping rules applied successfully!"
    echo "Total interfaces configured: $NB_RULES"

fi
