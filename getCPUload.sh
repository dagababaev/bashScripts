#!/bin/bash

load=$(cut -d " " -f 1 /proc/loadavg)

if [[ $load != "0.00" ]]; then
  loadRound=$(echo "scale=0; 100/($(nproc)/$load)" | bc -l)
  if [[ $loadRound -ge 75 ]]; then
    echo "$loadRound% OVERLOAD!"
  else
    echo "$loadRound% Normal"
  fi
else
  echo "0% idle"
fi

exit 0
