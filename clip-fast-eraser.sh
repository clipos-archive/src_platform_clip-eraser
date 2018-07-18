#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2016-2018 ANSSI. All Rights Reserved.

files_to_delete_in_boot=""
files_to_delete_in_home=""
answer=""
path_to_lib=""

usage_exit(){
  echo "usage :"
  echo "erase <device_path>"
  exit 1
}

print_succeed_or_exit(){
  success=$1 # 0=success, 1=fail
  message=$2 # the action that succeeded or failed
  if [[ "${success}" -eq 0 ]]; then
    affiche_heure_message "**** " "${message}" " succeeded"
  else
    affiche_heure_message "**** " "${message}" " failed"
    exit 1
  fi
}

# ------------------------------------------------------------
# affiche un message précédé de l'heure courante
# argument : une chaine de caractères
affiche_heure_message(){
  message=${1}
  echo $(date +"%H:%M:%S") "${message}"
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
    echo "*** User action required :"
    echo "the computer will enter and exit sleep state"
    echo "if after a few seconds it has not exited the sleep state"
    echo "then press the fn or power button"
    echo "*** Press Enter to proceed"
    read presse_entree

    # enter sleep
    # echo "mem" > /sys/power/state
    rtcwake -m mem -s 5 > /dev/null
    # refresh the screen
    chvt 2 && chvt 7
  fi;
}

sata_secure_erase(){
  local device_path=${1}
  security_enabled=$(hdparm -I "${device_path}" | grep "SECURITY ERASE UNIT")

  affiche_heure_message "starting secure erase"
  
  if [[ "${security_enabled}" == "" ]]; then
    echo "hdparm security erase seems to be not supported, please check and proceed manually :"
    echo "$ hdparm -I ${device_path}"
    echo "$ hdparm --security-set-pass \"azerty123\" ${device_path}"
    echo "$ hdparm -security-erase \"azerty123\" ${device_path}"    
    return
  fi  

  affiche_heure_message "${security_enabled}"
  affiche_heure_message "*********************"
  affiche_heure_message " NB : the security password set for sata operation is \"dfg\""
  affiche_heure_message "*********************"

  sata_unfreeze "${device_path}"
  sleep 5  

  hdparm --security-set-pass dfg "${device_path}"
  print_succeed_or_exit $? "set sata password"
  
  sata_unfreeze "${device_path}"
  sleep 5

  hdparm --security-erase dfg "${device_path}"
  print_succeed_or_exit $? "sata secure erase"
  
  affiche_heure_message "secure erase finished"
  echo ""
}

# -------------------------------------------
# sequence of erasing operations
erase_disk(){
  local device_path=${1} 
  cd ${path_to_lib}
  ./hdparm_discard_file.py "${device_path}"  
  cd -
  echo "===================================="
  sata_secure_erase "${device_path}"
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
  affiche_heure_message "${disk_device_path} doesn't exist or is a not a block special file"
  usage_exit
fi

# -------------------------------
# test if disk is clip-livecd
blkid | grep "clip-livecd" | grep -q "${disk_device_path}"
if [ $? -eq 0 ]; then
  affiche_heure_message "aborted : ${disk_device_path} is the clip-livecd"
  exit 1
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

erase_disk "${disk_device_path}"
