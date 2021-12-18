#!/bin/bash

device="0"
mountPoint="0"

function doIt() {

  if [[ $1 == "0" ]]; then
    echo "Device is not set. Add -d {/dev/deviceName}"
    exit 1
  elif [[ $2 == "0" ]]; then
    echo "Mount point is not set. Add -m {/mnt/folderName}"
    exit 1
  fi

  devUUID=$(blkid | grep "/dev/$1" | grep -Po '(?<=UUID=")[^"]*' | head -n 1)
  fsType=$(blkid | grep "/dev/$1" | grep -Po '(?<=TYPE=")[^"]*' | head -n 1)

  if (echo "$devUUID $2 $fsType defaults 0 0" >> /etc/fstab); then
    echo "Succesfully added to fstab"
  fi

}


while getopts "d:m:" opt; do
  case ${opt} in
  d)
    device=$OPTARG
    ;;
  m)
    mountPoint=$OPTARG
    doIt $device $mountPoint
    ;;
  :)
    echo "Invalid option: $OPTARG requires an argument" 1>&2
    ;;
  \?)
    echo "Invalid option: $OPTARG" 1>&2
    ;;
  esac
done
shift $((OPTIND - 1))
