#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2016-2018 ANSSI. All Rights Reserved.


# cle
key="0"

# device
device_path=""

# numero du premier_bloc
# first_block_number=0

# numero du dernier_bloc
# last_block_number=0

# taille_bloc_physique
physical_block_size=0

# nombre de blocs physiques
nb_physical_blocks=0

# nombre d'iv par bloc physique
nb_iv_by_pb=0

# multiple du numero de blocs a verifier
modulo_verify_blocs=6000

# fichier journal
log_file="log.txt"

# premier argument = chemin vers le device
init() {
    echo "" > $log_file
    
    # test l'existence du device
    if ! [[ -b "$device_path" ]];
    then
        echo "$device_path n'est pas un peripherique block"
        exit 1
    fi
    
    physical_block_size=$(blockdev --getpbsz $device_path)
    echo "physical block size = $physical_block_size"
    
    nb_iv_by_pb=$(echo "$physical_block_size / 16" | bc)
    echo "nb iv by physical block = $nb_iv_by_pb"
    
    nb_physical_blocks=$(echo "$(blockdev --getsz $device_path) * 512 / $physical_block_size" | bc)
    echo "nb physical blocks : $nb_physical_blocks"
}


# nb_bloc_test : on divise le nb de bloc par ca et on prend au hasard dans chaque intervalle

# fonction : numero de bloc -> index d'iv = numero bloc * (taille du bloc / 128)
ecriture() {
    for (( index=0; index<$nb_physical_blocks; index=index+10000 )); 
    do
	local iv_number=$(echo "$index * $nb_iv_by_pb" | bc)
        local vec=$(printf "%032x" $iv_number)
        
	dd status=none if=/dev/zero bs=$physical_block_size count=10000 | openssl enc -e -aes-128-ctr -K $key -iv $vec | dd status=none bs=$physical_block_size seek=$index of="$device_path"

	echo "ecrit block $index on $nb_physical_blocks"

	local status=$?
	if [ $status -ne 0 ];
	then
		echo "erreur a l'ecriture du block : $index : voir fichier log"
		echo "erreur a l'ecriture du block : $index : error = $status" >> $log_file
	fi

    done
}

verification() {
	for (( index=0; index<$nb_physical_blocks; index=index+$modulo_verify_blocs ));
	do
		local iv_number=$(echo "$index * $nb_iv_by_pb" | bc)
		local vec=$(printf "%032x" $iv_number)
        	local chiffre="$(dd status=none if=/dev/zero bs=$physical_block_size count=1 | openssl enc -e -aes-128-ctr -K $key -iv $vec | base64)"
		local block_content="$(dd status=none if="$device_path" bs=$physical_block_size count=1 skip=$index | base64)"

		echo "teste block $index sur $nb_physical_blocks"

		if [ "$chiffre" != "$block_content" ]; then
			echo "erreur a la verification : block : $index : voir fichier log"
			echo "les blocks $index ne correspondent pas." >> $log_file
			echo $chiffre >> $log_file
			echo "chiffre taille : ${#chiffre}" >> $log_file
			echo $block_content >> $log_file
			echo "content taille : ${#block_content}" >> $log_file
			echo "*****"  >> $log_file
		fi	
	done
}

usage_exit() {
	echo "usage :"
	echo "disk_overwrite <key_hex> <device_path>"
	exit 1
}

# recuperation de la cle et du device a effacer et confirmation

if [[ ${#} -ne 2 ]]; then
	usage_exit
fi

# initialisation de la cle
key="$1"

# initialisation du device a reecrire
device_path="$2"

# execution de la procedure
init
ecriture
verification
