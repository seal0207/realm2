#!/bin/bash
pkill -f '/etc/realm2/realm2'

for rule_file in /etc/realm2/rules/*; do
   /etc/realm2/realm2 -c "$rule_file" &
done
wait
