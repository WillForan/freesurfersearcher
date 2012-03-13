#!/bin/bash

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

ni_tools="$LUNADIR/ni_tools"

#System paths of import
PATH="/usr/kerberos/bin:/usr/local/bin:/bin:/usr/bin:$HOME/bin:/usr/local/MATLAB/R2011a/bin"

#prepend all of these paths to system path to prefer local to system for any conflicts

# FSL Configuration
FSLDIR=${ni_tools}/fsl
PATH="${FSLDIR}/bin:${PATH}"
. ${FSLDIR}/etc/fslconf/fsl.sh

#AFNI Configuration
PATH="${ni_tools}/afni:${PATH}"

#Freesurfer Configuration
export FREESURFER_HOME=${ni_tools}/freesurfer
source $FREESURFER_HOME/SetUpFreeSurfer.sh

#MNE enviornment
export MNE_ROOT=${ni_tools}/MNE
export MATLAB_ROOT=/usr/local/MATLAB/R2011a
. $MNE_ROOT/bin/mne_setup_sh

#R Configuration
PATH="${ni_tools}/R/bin:${PATH}"
#export R_HOME=${ni_tools}/R/lib64/R

#Caret Configuration
PATH="${ni_tools}/caret/bin_linux64:${PATH}"

#local ni scripts directory
PATH="${ni_tools}/processing_scripts:${PATH}"

#mricron/dcm2nii
PATH="${ni_tools}/mricron:${PATH}"

#commit to environment
export FSLDIR PATH

#check that templates folder is linked to home directory
if [ ! -L "$HOME/standard" ]; then
    ln -s ${ni_tools}/standard_templates "$HOME/standard"
fi

if [ ! -f "$HOME/.afnirc" ]; then
    cp ${ni_tools}/afnirc_default "$HOME/.afnirc"
fi

