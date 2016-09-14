# Network Conditions Emulator

This script artificially limits bandwidth, delay and loss rate on a selected interface.
For information and suggestions please write to:
martino.trevisan@polito.it

Dependencies
============
This is a bash script to be used in a Linux environment.
It depends on the the package 'tc' 

Usage
=====

As first, you must initialize the environment:
'''
./net_cond_em.sh init
'''

Then, you can run commands in this way:
'''
./net_cond_em.sh <interface> <command> <input_value> <output_value>
'''
where:
*  '<interface>' is the target physical interface you want to alterate
*  '<command>' is the limit you want to enforce. It can be 'delay', 'loss' and 'rate'.
*  '<input_value>' is the parameter for the command in the incoming direction (e.g. all incoming packets delayed by 50ms).
*  '<output_value>' is the parameter for the command in the outgoing direction (e.g. all outgoiing packets have loss probability of 10%).

'<input_value>' and '<output_value>' must specify the right dimension in a 'tc' compatible way (e.g., 10ms 2% or 10mbit).

For example you can write 
./net_cond_em.sh eth0 rate 2mbit 1mbit
to artificially limit download rate to 2mbps and uplink to 1mbps




