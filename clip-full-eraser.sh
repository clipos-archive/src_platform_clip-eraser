#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2016-2018 ANSSI. All Rights Reserved.
# script for erasing clip from hdd

# check that the disk is an hdd
# check partitions

# set -e stops if a command not return 0
#set -u # stops if meet uninitialized variable
# set -o pipefail

is_disk_hdd=1
disk_device_path=""
answer=""

usage_exit() {
  echo "usage :"
  echo "erase <device_path>"
  exit 1
}

print_succeed_or_exit(){
  success=$1 # 0=success, 1=fail
  message=$2 # the action that succeeded or failed
  if [[ "${success}" -eq 0 ]]; then
    echo "**** " "${message}" " succeeded"
  else
    echo "**** " "${message}" " failed"
    exit 1
  fi
}

# -------------------------------------
# print the write time for a complete disk
print_total_disk_write_time(){
  local device_path=${1}

  # get the number of 512 bytes block
  nb_block=$(blockdev --getsz "${device_path}")

  # write speed
  echo "speed test :"
  start=$(date +"%s")
  dd if=/dev/zero of="${device_path}" bs=512 count=300k
  end=$(date +"%s")
  length=$(echo "$end-$start" | bc -l) 

  total_time=$(echo "$nb_block*$length*1/(300000*3600)" | bc -l)
  
  echo ""
  echo "total disk write time for one pass :"
  echo "${total_time}" " hours"
  echo ""
}

# ----------------------------------
# erase sequence for disk
erase_disk(){
  local hpa=""
  local device_path=${1}
  hpa=$(hdparm -N "${device_path}" | grep "disable")
  
  if [[ "${hpa}" == "" ]]; then
    echo "please disable hpa before to launch the script."
    return
  fi

  echo ">>>>>"
  echo "try to trim (blkdiscard) the disk"
  blkdiscard -s -o 0 -l 512 "${device_path}"
  if [[ $? -eq 0 ]]; then
    echo "trim (blkdiscarding) test succeeded"
    block_discarding "${device_path}"
  else
    echo "can not trim (blkdiscard) the disk so dd and then shred"
    echo "each of dd and shred will take : "
    echo ""
    print_total_disk_write_time "${device_path}"
    shreding "${device_path}"
    zeroing "${device_path}"
  fi
  
  sata_secure_erase "${device_path}"
}



# --------------------
# tests if the disk is frozen that enters sleep if it is in order to unfreeze it
sata_unfreeze(){
  local device_path=${1}
  # test if disk is frozen
  # 1 = frozen
  # 0 = not frozen
  hdparm -I "${device_path}" | grep frozen | grep -q not
  frozen=$?
  
  if [[ ${frozen} -eq 1 ]]; then
    # enter sleep
    # echo "mem" > /sys/power/state
    rtcwake -m mem -s 5 
  fi;
}

sata_secure_erase(){
  local device_path=${1}
  security_enabled=$(hdparm -I "${device_path}" | grep "SECURITY ERASE UNIT")

  echo ">>>>>"  
  echo "starting secure erase"
  echo "start time : " $(date)

  if [[ "${security_enabled}" == "" ]]; then
    echo "hdparm security erase seems to be not supported, please check and proceed manually :"
    echo "$ hdparm -I ${device_path}"
    echo "$ hdparm --security-set-pass \"azerty123\" ${device_path}"
    echo "$ hdparm -security-erase \"azerty123\" ${device_path}"    
    return
  fi  

  echo "${security_enabled}"
  echo "*********************"
  echo " NB : the security password set for sata operation is \"dfg\""
  echo "*********************"

  sata_unfreeze "${device_path}"
  sleep 5  

  hdparm --security-set-pass dfg "${device_path}"
  print_succeed_or_exit $? "set sata password"
  
  sata_unfreeze "${device_path}"
  sleep 5

  hdparm --security-erase dfg "${device_path}"
  print_succeed_or_exit $? "sata secure erase"
  
  echo "end time : " $(date)
  echo "secure erase finished"
  echo ""
}


block_discarding(){
  local device_path=${1}

  echo ">>>>>"
  echo "start discarding"
  echo "start time : " $(date)
  blkdiscard -s "${device_path}"
  print_succeed_or_exit $? "discarding(trim)"
  echo "end time : " $(date)
  echo "ended discarding"
  echo ""
}

shreding(){
  local device_path=${1}
  
  echo ">>>>>"
  echo "will now shred ${device_path}"
  echo "start time : " $(date)
  shred -v -n1 "${device_path}"
  print_succeed_or_exit $? "shred"
  echo "end time : " $(date)
  echo "ended shred"
  echo ""
}

zeroing(){
  local device_path=${1}
  
  echo ">>>>>"
  echo "will now zero ${device_path}"
  echo "start time : " $(date)
  nb_bloc=$(blockdev --getsz "${device_path}")
    
  dd if=/dev/zero of="${device_path}" bs=512 count="${nb_bloc}"
  print_succeed_or_exit $? "write zero with dd on all the device"
  echo "end time : " $(date)
  echo "ended zeroing"
  echo ""
}

# -------------------------------
# check args
if [[ ${#} -ne 1 ]]; then
  usage_exit
fi
# -------------------------------

disk_device_path=${1}
disk_device_name=$(basename "${disk_device_path}")

# -------------------------------
# test if disk exists
if [[ ! -b ${disk_device_path} ]]; then
  echo "${disk_device_path} doesn't exist or is a not a block special file"
  usage_exit
fi

# -------------------------------
# are you sure ?
echo -n "are you sure you want to erase ${disk_device_path} (y/N) ?"
read answer

answer="${answer^^}"

if [[ ! "${answer}" == "Y" ]]; then
  echo "stop."
  exit 1
fi

echo ""
erase_disk "${disk_device_path}"


