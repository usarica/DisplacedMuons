#!/bin/bash

SCRIPTNAME="$1"
SCRIPTCMD="$2"
QUEUE="$3"
OUTDIR="$4"
CONDORSITE="$5"
CONDOROUTDIR="$6"


echo "Calling the main submission script with the following arguments:"
echo "SCRIPTNAME: ${SCRIPTNAME}"
echo "SCRIPTCMD: ${SCRIPTCMD}"
echo "QUEUE: ${QUEUE}"
echo "OUTDIR: ${OUTDIR}"
echo "CONDORSITE: ${CONDORSITE}"
echo "CONDOROUTDIR: ${CONDOROUTDIR}"


if [[ -z "$OUTDIR" ]];then
  echo "You must set the output directory!"
  exit 1
fi

CMSENVDIR=$CMSSW_BASE
if [[ -z "$CMSENVDIR" ]];then
  echo "Set up CMSSW first!"
  exit 1
fi


LOGSDIR=$OUTDIR"/Logs"
mkdir -p $LOGSDIR

extLog="JHUGen"
if [[ ! -z "$SCRIPTCMD" ]];then
  fcnargname=""
  fcnargnameextra=""
  fcnargnametmp=""
  fcnarglist=($(echo $SCRIPTCMD))
  for fargo in "${fcnarglist[@]}";do
    farg="${fargo//\"}"
    fargl="$(echo $farg | awk '{print tolower($0)}')"
    if [[ "$fargl" == "datafile="* ]];then
      fcnargname="$farg"
      fcnargname="${fcnargname#*=}"
      fcnargname="${fcnargname//.lhe}"
      fcnargname="${fcnargname##*/}"
    elif [[ "$fargl" == "vbfoffsh_run="* ]];then
      fcnargnametmp="$farg"
      fcnargnametmp="${fcnargnametmp#*=}"
      fcnargnameextra=$fcnargnameextra"_"$fcnargnametmp
    fi
  done
  if [[ "$fcnargnameextra" != "" ]];then
    fcnargname=$fcnargname$fcnargnameextra
  fi
  if [[ "$fcnargname" == "" ]];then
    fcnargname=${SCRIPTCMD//" "/"_"}
  fi
  fcnargname=${fcnargname//"="/"_"}
  fcnargname=${fcnargname//".root"}
  fcnargname=${fcnargname//".lhe"}
  fcnargname=${fcnargname//\"}
  fcnargname=${fcnargname//\!}
  fcnargname=${fcnargname//\\}
  fcnargname=${fcnargname//"("}
  fcnargname=${fcnargname//")"}
  fcnargname=${fcnargname//","/"_"}
  extLog=$extLog"_"$fcnargname
fi


if [[ -f $SCRIPTNAME ]]; then
  echo "File "$SCRIPTNAME" exists."

  hname=$(hostname)
  echo $hname
  if [[ "$hname" == *"lxplus"* ]] || [[ "$hname" == *"ucsd"* ]];then
    echo "Host is on LXPLUS or UCSD, so need to use HTCONDOR"
    THEQUEUE="vanilla"
    if [[ "$QUEUE" != "default" ]];then
      THEQUEUE=$QUEUE
    fi
    checkGridProxy.sh
    TARFILE="jhugensub.tar"
    if [ ! -e ${OUTDIR}/${TARFILE} ];then
      createJHUGenSubmitterTarball.sh
      mv ${TARFILE} ${OUTDIR}/
    fi
    #if [[ [[ "$hname" == *"lxplus"* ]] && [[ "${CONDORSITE}" == *"cern"* ]] ]] || [[ [[ "$hname" == *"ucsd"* ]] && [[ "${CONDORSITE}" == *"ucsd"* ]] ]];then
    #  if [[ ! -z "${CONDOROUTDIR+x}" ]];then
    #    mkdir -p "${CONDOROUTDIR}"
    #  fi
    #fi
    configureJHUGenSubmitterCondorJob.py --tarfile="$TARFILE" --batchqueue="$THEQUEUE" --outdir="$OUTDIR" --outlog="Logs/log_$extLog" --errlog="Logs/err_$extLog" --batchscript="submitJHUGenSubmitterGenericJob.condor.sh" --exe="$SCRIPTNAME" --command="$SCRIPTCMD" --condorsite="$CONDORSITE" --condoroutdir="$CONDOROUTDIR"
  elif [[ "$hname" == *"login-node"* ]] || [[ "$hname" == *"bc-login"* ]]; then
    echo "Host is on MARCC, so need to use SLURM batch"
    THEQUEUE="lrgmem"
    if [[ "$QUEUE" != "default" ]];then
      THEQUEUE=$QUEUE
    fi
    sbatch --output=$LOGSDIR"/log_"$extLog".txt" --error=$LOGSDIR"/err_"$extLog".err" --partition=$THEQUEUE submitJHUGenSubmitterGenericJob.slurm.sh "$CMSENVDIR" "$SCRIPTNAME" "$SCRIPTCMD"
  fi

else
  echo "$SCRIPTNAME does not exist."
fi
