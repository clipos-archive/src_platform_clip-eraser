#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2016-2018 ANSSI. All Rights Reserved.

usage_exit() {
  echo "usage :"
  echo "list_home_files_to_delete.sh <home_path>"
  echo "list_home_files_to_delete.sh /clip1/home"
  exit 1
}

# -------------------------------
# check args
if [[ ${#} -ne 1 ]]; then
  usage_exit
fi
# -------------------------------


find "$1"/rm_h/keys/ -type f
find "$1"/rm_b/keys/ -type f
find "$1"/keys -type f
find "$1"/etc.users/tcb/ -type f -iname shadow*