#!/usr/bin/env bash

#
# search for subjects in raw/MM
# that do not have directory in MM/FS
#   do reconall -all on these subjects
# 
#  input  <--  /data/Luna1/Raw/MultiModal/lunaid_date/*mprage*/*dcm
#
#  nii    -->  /data/Luna1/Multimodal/ANTI/${subjctid}/mprage
#  FS     -->  /data/Luna1/Multimodal/FS_Subjects/${subjctid}  
#
#  FS log -->  /data/Luna1/Multimodal/FS_Subjects/${subjctid}/scripts/recon-all.log # longer log file
#         -->  /data/Luna1/Multimodal/ANTI/${subjctid}/mprage/recon-all.log         # redirect of stdout/err
#
#


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

# if not using qsub, how many jobs?
MAXJOBS=8

# if using qsub, who to email about jobs
EMAILS="foranw@upmc.edu,willforan@gmail.com"

# Directories
#LUNADIR="/raid/r3/p2/Luna"
       MMDIR=$LUNADIR/Raw/MultiModal
SUBJECTS_DIR=$LUNADIR/Multimodal/FS_Subjects # This is used by freesurfer as well
      NIIDIR=$LUNADIR/Multimodal/ANTI
 #NIIDIR/subject/mprage/

# use to give feedback on job
todaySeconds=$(date "+%s")

## for every subject in multimodal scan ##
ls -d $MMDIR/* |
 while read fullpath; do
  
  # parse out the id and date
  subj_date="$(basename $fullpath)"
  subjctid=${subj_date%_*}  ## subject id
  scandate=${subj_date#*_}  ## date

  ####
  #
  # scan already exists
  #
  ####

  # ls'ing the dir for each subject might not be efficient?
  if ls -d $SUBJECTS_DIR/$subjctid 1>/dev/null 2>&1 ; then

   
   FSLOG=$SUBJECTS_DIR/$subjctid/scripts/recon-all.log

   finishdate=$(perl -lne 'print $1 if m/finished without error at (.*$)/' $FSLOG)


   # skip if it is already in the queue
   if qstat |grep "FS-$subjctid " 1>/dev/null 2>&1; then 
     echo "# FS-$subjctid is already in the queue. Skip"
     continue;
   fi

   #
   # started but didn't finish! 
   # how long has it been, how close are we
   #

   if [ -z "$finishdate" ]; then

     niidir=$NIIDIR/${subjctid}/mprage/
     niifile=$(/bin/ls $niidir/*nii.gz | head -n1)

     # how long ago was the job started
     startdateSeconds=$(date -d "$(sed 1p -n $FSLOG)" "+%s")
     echo -ne "UNFINISHED:\t$subjctid started "
     echo "scale=2;($todaySeconds - $startdateSeconds)/86400" |bc -l  |tr -d "\n"
     echo -ne " days ago; "

     # rough % done estimate
     wc -l $FSLOG| perl -alne 'printf("< %.0f%% complete\n", $F[0]/78)'

     # last line of log
     echo -e "\t$FSLOG"
     egrep -v '^\s*$' $FSLOG|tail -n2 | sed -e 's/^/ ➞	/'
     echo
     echo -e "\tqsub -h -m abe -M $EMAILS -e $(dirname $0)/log  -o $(dirname $0)/log -N \"FS-$subjctid\" -v \ 
    subjctid=\"$subjctid\",niifile=\"${niifile##$LUNADIR}\" \ 
    $(dirname $0)/queReconall.sh "
     echo
     echo "SUBJECTS_DIR=/raid/r3/p2/Luna/Multimodal/FS_Subjects/ recon-all -sid $subjctid -all"

   # or we don't have to do anything
   else
    echo "# $subjctid already complete"
   fi


  ####
  #
  # subject hasn't been proccessed by freesurfer yet
  #
  ####
  #  using $LUNADIR/Multimodal/ANTI/MM_mv_mrdata.sh
  #                                 MM_fsrecon.sh  
  #   eg   /data/Luna1/Multimodal/ANTI/MM_fsrecon.sh
  ###

  else  ## subject not in SUBJECT_DIR

   
   # everyone should have an mprage dir
   ragedir=$(ls -d $fullpath/*mprage* 2>/dev/null)
   if [ -z "$ragedir" ]; then 
      echo -e "SKIPPING:\t$subjctid has no *mprage*: $fullpath"; continue; 
   fi


   echo "===  $subjctid"

   niidir=$NIIDIR/${subjctid}/mprage/
          #$LUNADIR/Multimodal/ANTI/subj/mprage
   #ragedir ../Raw/.../*mprage*/

   # check for nifity file in ANTI/subj or create if it DNE
   if ls $niidir/*nii.gz 1>/dev/null 2>&1 ; then 
      echo -e "\talready has a ANTI dir ($niidir) with *nii.gz";
   else
      echo -e "\tcreateing nifti using DCM in $ragedir\n\t mv to $niidir"
      set -ex

      $LUNADIR/ni_tools/mricron/dcm2nii \
          -d N -e N -f N -p N -x N -r N $(find $ragedir -name MR\*)

      # move newest created nifity to niidir
      mkdir -p $niidir; 
      mv $(/bin/ls -1tc $ragedir/*nii.gz|head -n1) $niidir

      set +ex
   fi

   niifile=$(/bin/ls $niidir/*nii.gz | head -n1)
   echo "\tusing nifiti located at $niifile"


   


   ###############
   ## submit to qsub 
   ###############
   # remove lunadir from niifile so it can be replaced by
   # gromit specific path

   set -ex
    # use -h to hold by default
    qsub -m abe -M $EMAILS \
         -e $(dirname $0)/log  -o $(dirname $0)/log \
         -N "FS-$subjctid" \
         -v subjctid="${subjctid}_${subj_date}",niifile="${niifile##$LUNADIR}" \
         $(dirname $0)/queReconall.sh 

   set +ex

   ###############
   ## use bash job control (MAXJOBS)
   ###############

   #echo "\tmove nii, start freesurfer"
   #set -ex
   #recon-all -i $niifile -sid ${subjctid} -all> $niidir/${subjctid}_fsrecon.log 2>&1 &
   #set +ex

   #echo "\tcheck for openings (num jobs)"
   ## instead of giving to qsub, just wait here while we have too many jobs launched
   #while [ `jobs | wc -l` -ge $MAXJUBS ]; do
   #       echo "... "
   #       sleep 600
   #done

   #echo "$(jobs|wc -l), "
   #echo "running next job in 100s"
   #sleep 100

   ###############
   ## just print what would happen
   ###############
   #echo -e "	o mkdir -p $niidir"           #pushd $niidir
   #echo -e "	o dcm2nii -d N -e N -f N -p N -x N -r N $ragedir/* "
   #echo -e '	o niifile=$(ls -tlc ' $ragedir'/*nii.gz|head -n1)' 
   #echo -e "	o mv \$niifile $niidir "
   #echo -e "	o recon-all -i ${niidir}/\$(basename \$niifile) -sid ${subjctid} -all> $NIIDIR/${subjctid}_fsrecon.log 2>&1 "
   ##echo -e "	o recon-all -i ./*.nii.gz -sid ${subjctid} -all> ${subjctid}_fsrecon.log 2>&1 "
   #continue #don't actually do the stuff below
   #

  fi
 done
