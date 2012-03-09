#!/usr/bin/env bash

###                 ###
### options for pbs ###
###                 ###

#PBS -l ncpus=1
#PBS -l walltime=40:00:00
#dont use leading zeros
#PBS -q batch

# PARAMETERS
# expect 
#  o subjctid   -- e.g. 10900
#  o niifile    --      xxxxxxx/*ni.gz
#

## Where are the files (host dependent)
case $HOSTNAME in
*gromit*)
   LUNADIR="/raid/r3/p2/Luna"
   ;;
*wallace*)
   LUNADIR="/data/Luna1"
   ;;
*)
  echo dont know what to do on $HOSTNAME
  exit
  ;;
esac

# setup tool path and vars
source /home/foranw/src/freesurfersearcher/ni_path_local.bash


# setup local vars
SUBJECTS_DIR=$LUNADIR/Multimodal/FS_Subjects
      niidir=$LUNADIR/Multimodal/ANTI/${subjctid}/mprage/



# RUN!  --- log is in ANTI/subject/ b/c FS hasn't created FS DIR yet
logfile=${niidir%mprage/}/${subjctid}_fsrecon.log 

echo LUNADIR:   	$LUNADIR
echo SUBJECTS_DIR:	$SUBJECTS_DIR
echo niidir:     	$niidr
echo niifile:     	$niifile
echo log:       	$logfile
echo
set -ex
recon-all -i $LUNADIR/$niifile -sid ${subjctid} -all 2>&1 | tee $logfile
