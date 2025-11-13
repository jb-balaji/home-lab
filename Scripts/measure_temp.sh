#!/bin/bash

#Author : JB
# Measure CPU/NVME temp in 5 seconds interval till end of the world

while true; do
  temp=$(sudo nvme smart-log /dev/nvme0 | grep "^temperature" | awk '{print $3}')
  echo "$(date '+%Y-%m-%d %H:%M:%S') - NVMe Temp: ${temp}°C | CPU Temp $(vcgencmd measure_temp)"
  sleep 5
done
