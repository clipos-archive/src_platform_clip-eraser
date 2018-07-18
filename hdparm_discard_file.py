#!/usr/bin/python
# -*- coding: utf-8 -*-
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2016-2018 ANSSI. All Rights Reserved.

import subprocess
import os
import sys
import datetime
import traceback

def print_usage():
    print "./hdparm_discard_file.py <file_path>"

"""
    class to store a range of lba sectors
"""
class SectorsRange:
    start_sector=0
    nb_sectors=0
    def __str__(self):
        return "start = "+str(self.start_sector)+" / nb sectors = "+str(self.nb_sectors)

"""
    message : (string) the message to display
"""
def print_time_message(message):
    now=str(datetime.datetime.now().time())
    print(now + " : " + message)



def is_mounted(partition_path):
    output=""
    try:
        output=subprocess.check_output(["mount"], stderr=subprocess.STDOUT)
    except:
        print_time_message("failed to check if  "+partition_path+" is mounted ")
        raise
    occur=output.count(partition_path)
    if (occur==0):
        return False
    return True

"""
    mount a device on a mount_point
    device : (string) device path
    mount_point : (string) mount point
"""
def mount(device, mount_point):
    print_time_message("mount "+device+" on "+mount_point)
    
    if (is_mounted(device)):
        print_time_message("already mounted")
        return

    output=""
    try:
        output=subprocess.check_output(["mount", device, mount_point], stderr=subprocess.STDOUT)
    except:
        print_time_message("failed to mount "+device+" on "+mount_point)
        raise
 
"""
    umount a device on a mount_point
    device : (string) device path
"""
def umount(device):
    print_time_message("umount "+device)
    
    if (not is_mounted(device)):
        print_time_message("already unmounted")
        return

    output=""
    try:
        output=subprocess.check_output(["umount", device], stderr=subprocess.STDOUT)
    except:
        print_time_message("failed to umount "+device+" : "+output)
        raise


"""
    return a list of string of the paths to the files to delete
"""
def get_boot_files_to_delete():
    print_time_message("get boot files to delete ")
    print_time_message("/clip1/boot/master_key")
    return ["/clip1/boot/master_key"]
    
"""
    return a list of string of the paths to the files to delete
"""
def get_home_files_to_delete():
    print_time_message("get home files to delete ")
    result=[]
    output=""
    try:
        output=subprocess.check_output(["./list_home_files_to_delete.sh", "/clip1/home"], stderr=subprocess.STDOUT)
    except:
        print_time_message("failed to get home files to delete on /clip1/home")
        raise

    result=output.split("\n")
    print_time_message(str(result))
    return result


"""
    call hdparm to get the list of the blocks of the file given as paramater
    filepath : path to the file
    return : a list of lists [ [offset,first block, last block, number of blocks] [...] ]
"""
def get_blocklist(filepath):
    result=[]
    
    hdparm_blocklist = subprocess.check_output(["hdparm", "--fibmap", filepath], stderr=subprocess.STDOUT)
    
    lines = hdparm_blocklist.split("\n")
    
    for line in lines:
        splitted_line=line.split()
        if (len(splitted_line)==4):
            if ((splitted_line[0].isdigit()) and (splitted_line[1].isdigit()) and (splitted_line[2].isdigit()) and (splitted_line[3].isdigit())):
                result.append([splitted_line[0], splitted_line[1],splitted_line[2],splitted_line[3]])
    
    return result


"""
    get the block/sectors ranges for a file
    
    arguments :
    file_path : (string) path to the file
    return :
    a list of SectorsRange
"""
def measure_file(file_path):
    file_blocks=[]
    result=[]
    try:
        file_blocks=get_blocklist(file_path)
    except:
        print_time_message("failed to get blocks of "+file_path)
        raise
        
    for block_range in file_blocks:
        range=SectorsRange()
        range.start_sector=int(block_range[1])
        range.nb_sectors=int(block_range[3])
        result.append(range)
    
    return result
    
    

"""
    get the sectors for a list of files, and add these ranges to a map
    
    arugments :
    - file_list : [(string)] a list of file paths
    - files_measures : {(string),[SectorsRange]} a map {filepath, list of SectorsRange}    
"""
def measure(file_list, files_measures):
    for file_path in file_list:
        if (file_path==""):
            continue
        blocks=measure_file(file_path)
        files_measures[file_path]=blocks
  

"""
    hdparm erase blocks
    arguments:
    - sectorsRanges : [SectorsRange]
    - device_path : (string)
    return :
    - True : if succeeded
    - False : if failed
"""
def trim_sectors(sectorsRanges, device_path):
    output=""
    if (len(sectorsRanges)==0):
        return
    
    arglist=["hdparm","--please-destroy-my-drive", "--trim-sector-ranges"]    
    # transform the list of sectors range into an argument list for hdparm
    for range in sectorsRanges:
        temp=str(range.start_sector)+":"+str(range.nb_sectors)
        arglist.append(temp)        
    arglist.append(device_path)
   
    try:
        output=subprocess.check_output(arglist, stderr=subprocess.STDOUT)
    except:
        print_time_message("failed to trim sectors : "+output)
        return False
    
    return True
    
    
"""
    write zeroes on the given sector
    arguments:
    - sectorsRanges : [SectorsRange]
    - device_path : (string)
"""
def write_zeroes(sectorsRanges, device_path):
    output=""
    if (len(sectorsRanges)==0):
        return
    
    for range in sectorsRanges:
        sector_number=range.start_sector
        while(sector_number<(range.start_sector+range.nb_sectors)):
            try:
                output=subprocess.check_output(["hdparm","--yes-i-know-what-i-am-doing", "--write-sector",str(sector_number),device_path], stderr=subprocess.STDOUT)
            except:
                print_time_message("failed to write sector : " + str(sector_number))
                raise
            sector_number+=1


"""
"""
def shred_file(file_path, device_path):
    output=""
    
    # remount boot and home
    mount(device_path+"1", "/clip1/boot")
    mount(device_path+"2", "/clip1/home")
    
    try:
        print_time_message("shred")
        output=subprocess.check_output(["shred", "-u", file_path], stderr=subprocess.STDOUT)        
    except:
        print_time_message("failed to shred")
        
    umount(device_path+"1")
    umount(device_path+"2")
    

"""
    erase measured files
    arguments :
    - files_measures : (dict)  { file path, list of SectorsRange }
    - device_path : (string) device path (ex. "/dev/sda")
"""
def files_erasure(files_measurements, device_path):
    print ("------------------------------------------")    
    print_time_message("start erasing files")
    for (file_path, sectorsrange) in files_measurements.iteritems():
        try:
            print_time_message("erase file : "+file_path)
            
            print_time_message("trim sectors")
            if (not trim_sectors(sectorsrange, device_path)):
                print_time_message("failed to trim then shred "+file_path)
                shred_file(file_path,device_path)
                
            print_time_message("write zeroes on sectors")
            write_zeroes(sectorsrange, device_path)
        except:
            print_time_message("failed to erase file : " + file_path)
            print_time_message(str(sys.exc_info()[0:2]))
            traceback.print_tb(sys.exc_info()[2])
            exit(1)
    print_time_message("end erasing files")
    
    
"""
    check that a sector is full of zeroes
    arguments: 
    - sector_index : (int) sector number
    - device_path : (string) device path
    return :
    true/false
"""
def is_sector_null(sector_index, device_path):
    output=""
    
    try:
        output=subprocess.check_output(["hdparm","--read-sector",str(sector_index),device_path], stderr=subprocess.STDOUT)
    except:
        print_time_message("failed to read sector : " + str(sector_index))
        raise
    nb_patterns=output.count("0000")
    
    if (nb_patterns>=256):
        return True
    
    return False


"""
    check that a range of sectors are null
    arguments:
    - sectors_range : [SectorsRange] list of sectors range
    - device_path : (string) device path
"""
def check_sectors_range_null(sectors_range, device_path):
    if (len(sectors_range)==0):
        return True
    
    for range in sectors_range:
        sector_number=range.start_sector
        while(sector_number<(range.start_sector+range.nb_sectors)):
            if (not is_sector_null(sector_number, device_path)):
                print_time_message("Sector : "+str(sector_number)+" is not null")
                return False
            sector_number+=1        
    
    return True
    
    
"""
    check that the sets of blocks for measured files is null
    arguments:
    - files_measures : {file_path, [SectorsRange]} files measurements
    - device_path : (string) device path
"""
def check_files_are_erased(files_measures, device_path):
    print ("------------------------------------------")
    print_time_message("check that files blocks are null")
    nb_unerased_files=0
    
    for (file_path, sectorsranges) in files_measures.iteritems():
        
        print_time_message("check file : "+file_path)
        
        try:
            sectors_null=check_sectors_range_null(sectorsranges, device_path)
        except:
            print("failed to check sectors for file "+file_path)
            nb_unerased_files+=1
            continue
        
        if (sectors_null):
            print_time_message("OK")
        else:
            print_time_message("KO")
            nb_unerased_files+=1
            
    print_time_message("Number of files not erased : "+str(nb_unerased_files))
        
        
"""
    fill a structure with for each file to delete :
    - the path to the file
    - the ranges of lba sectors
    arguments :
    * device_path : (string) device path (ex. "/dev/sda")
    return :
    * files_measures : (dict)  { file path, list of SectorsRange }
"""
def files_measurements(device_path):
    print ("------------------------------------------")
    files_measures={}
    try:
        mount(device_path+"1", "/clip1/boot")
        file_list = get_boot_files_to_delete()
        measure(file_list, files_measures)
        umount(device_path+"1")

        
        mount(device_path+"2", "/clip1/home")
        file_list = get_home_files_to_delete()
        measure(file_list, files_measures)
        umount(device_path+"2")
        
    except:
        print_time_message("failed to measure files")
        print_time_message(str(sys.exc_info()[0:1]))
        traceback.print_tb(sys.exc_info()[2])
        umount(device_path+"1")
        umount(device_path+"2")        
        sys.exit(1)

    return files_measures


"""
    print the map {file_path, list of SectorsRange}
    argument :
    - files_measurement : 
    {(string),[SectorsRange]}
"""
def print_files_measurements(files_measurement):
    for (filepath,sectorslist) in files_measurement.iteritems():
        print "for file : "+filepath
        for sectorrange in sectorslist:
            print str(sectorrange)


"""
    check if preconditions are satisfied
"""
def precheck():
    if (not os.path.exists("/clip1/boot")):
        print_time_message("create /clip1/boot")
        os.mkdir("/clip1/boot")
    
    if (not os.path.exists("/clip1/home")):
        print_time_message("create /clip1/home")
        os.mkdir("/clip1/home")
    

"""
   * pre-conditions : 
        /clip1/boot must exist
        /clip1/home must exist      
"""
if (__name__ == "__main__"):
    if (len(sys.argv) != 2):
        print_usage()
        exit(1)
    
    devicepath=sys.argv[1]
    precheck()
    res=files_measurements(devicepath)
    # print_files_measurements(res)
    files_erasure(res,devicepath)
    check_files_are_erased(res,devicepath)
    
