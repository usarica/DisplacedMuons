#!/bin/bash

INFILE=""
FRAGDIR=""
DATE=""
OUTPUTDIR=""
CONDOROUTDIR=""
GRIDPACKDIR=""
QUEUE="vanilla"
let printhelp=0
for fargo in "$@";do
  fcnargname=""
  farg="${fargo//\"}"
  fargl="$(echo $farg | awk '{print tolower($0)}')"
  if [[ "$fargl" == "infile="* ]];then
    fcnargname="$farg"
    fcnargname="${fcnargname#*=}"
    INFILE="$fcnargname"
  elif [[ "$fargl" == "fragdir="* ]];then
    fcnargname="$farg"
    fcnargname="${fcnargname#*=}"
    FRAGDIR="$fcnargname"
  elif [[ "$fargl" == "gridpack="* ]] || [[ "$fargl" == "gridpackdir="* ]];then
    fcnargname="$farg"
    fcnargname="${fcnargname#*=}"
    GRIDPACKDIR="$fcnargname"
  elif [[ "$fargl" == "date="* ]];then
    fcnargname="$farg"
    fcnargname="${fcnargname#*=}"
    DATE="$fcnargname"
  elif [[ "$fargl" == "outdir="* ]];then
    fcnargname="$farg"
    fcnargname="${fcnargname#*=}"
    OUTPUTDIR="$fcnargname"
  elif [[ "$fargl" == "condoroutdir="* ]];then
    fcnargname="$farg"
    fcnargname="${fcnargname#*=}"
    CONDOROUTDIR="$fcnargname"
  elif [[ "$fargl" == "help" ]];then
    let printhelp=1
  fi
done
if [[ $printhelp -eq 1 ]] || [[ -z "$INFILE" ]] || [[ -z "$FRAGDIR" ]] || [[ -z "$GRIDPACKDIR" ]]; then
  echo "$0 usage:"
  echo " - help: Print this help"
  echo " - infile: Input commands list file. Mandatory."
  echo " - fragdir: Location of Pythia and configuration fragments. Mandatory."
  echo " - gridpack/gridpackdir: Location of the gridpack; the gridpack must have the name 'gridpack.tgz'. Mandatory."
  echo " - outdir: Main output location. Default='./'"
  echo " - date: Date of the generation; does not have to be an actual date. Default=[today's date in YYMMDD format]"
  echo " - condoroutdir: Condor output directory to override. Optional."
  exit 0
fi

INITIALDIR=$(pwd)
if [[ "$FRAGDIR" != "/"* ]]; then
  FRAGDIR=${INITIALDIR}/${FRAGDIR}
fi
if [[ "$GRIDPACKDIR" != "/"* ]]; then
  GRIDPACKDIR=${INITIALDIR}/${GRIDPACKDIR}
fi

hname=$(hostname)

CONDORSITE="DUMMY"
if [[ "$hname" == *"lxplus"* ]];then
  echo "Setting default CONDORSITE to cern.ch"
  CONDORSITE="cern.ch"
elif [[ "$hname" == *"ucsd"* ]];then
  echo "Setting default CONDORSITE to t2.ucsd.edu"
  CONDORSITE="t2.ucsd.edu"
fi

if [[ "$OUTPUTDIR" == "" ]];then
  OUTPUTDIR="./output"
fi
if [[ "$DATE" == "" ]];then
  DATE=$(date +%y%m%d)
fi

OUTDIR="${OUTPUTDIR}/${DATE}"

mkdir -p $OUTDIR

TARFILE="tarfile.tar"
if [ ! -e ${OUTDIR}/${TARFILE} ];then
  cd ${OUTDIR}
  createDisplacedMuonsMCSubmitterTarball.sh $TARFILE $FRAGDIR $GRIDPACKDIR
  cd -
fi

checkGridProxy.sh

while IFS='' read -r line || [[ -n "$line" ]]; do
  THECONDORSITE="${CONDORSITE}"
  THECONDOROUTDIR="${CONDOROUTDIR}"
  THEQUEUE="${QUEUE}"
  THEYEAR=""
  THEMCNAME=""
  let THESEED=0
  let NEVENTS=0
  fcnarglist=($(echo $line))
  fcnargname=""
  extLog=""
  for fargo in "${fcnarglist[@]}";do
    farg="${fargo//\"}"
    fargl="$(echo $farg | awk '{print tolower($0)}')"
    if [[ "$fargl" == "year="* ]];then
      fcnargname="$farg"
      fcnargname="${fcnargname#*=}"
      THEYEAR="${fcnargname}"
    elif [[ "$fargl" == "nevents="* ]];then
      fcnargname="$farg"
      fcnargname="${fcnargname#*=}"
      let NEVENTS=${fcnargname}
    elif [[ "$fargl" == "seed="* ]];then
      fcnargname="$farg"
      fcnargname="${fcnargname#*=}"
      let THESEED=${fcnargname}
    elif [[ "$fargl" == "condorsite="* ]];then
      fcnargname="$farg"
      fcnargname="${fcnargname#*=}"
      THECONDORSITE="$fcnargname"
    elif [[ "$fargl" == "mcname="* ]];then
      fcnargname="$farg"
      fcnargname="${fcnargname#*=}"
      THEMCNAME="$fcnargname"
    elif [[ "$fargl" == "condoroutdir="* ]];then
      fcnargname="$farg"
      fcnargname="${fcnargname#*=}"
      THECONDOROUTDIR="$fcnargname"
    elif [[ "$fargl" == "condorqueue="* ]];then
      fcnargname="$farg"
      fcnargname="${fcnargname#*=}"
      THEQUEUE="$fcnargname"
    fi
  done

  if [[ -z "${THEMCNAME}" ]]; then
    echo "Need to set the MC name."
    continue
  fi

  THEBATCHSCRIPT=""
  if [[ -z "${THEYEAR}" ]]; then
    echo "Need to set the year."
    continue
  elif [[ "${THEYEAR}" == "2016" ]];then
    THEBATCHSCRIPT="submitDisplacedMuonsMCSubmitter_2016.condor.sh"
  elif [[ "${THEYEAR}" == "2017" ]];then
    THEBATCHSCRIPT="submitDisplacedMuonsMCSubmitter_2017.condor.sh"
  elif [[ "${THEYEAR}" == "2018" ]];then
    THEBATCHSCRIPT="submitDisplacedMuonsMCSubmitter_2018.condor.sh"
  else
    echo "The batch script cannot be determined from the year $THEYEAR"
    continue
  fi

  if [[ "${THECONDORSITE+x}" != "DUMMY" ]] && [[ -z "${THECONDOROUTDIR+x}" ]]; then
    echo "Need to set the Condor output directory."
    continue
  fi


  extLog="nevents_${NEVENTS}_seed_${THESEED}_year_${THEYEAR}"
  theOutdir="${OUTDIR}/${THEMCNAME}_seed_${THESEED}_year_${THEYEAR}"
  mkdir -p ${theOutdir}/Logs
  ln -sf ${PWD}/${OUTDIR}/${TARFILE} ${PWD}/${theOutdir}/

  configureDisplacedMuonsMCSubmitterCondorJob.py --dry --outdir="${theOutdir}" --nevents="${NEVENTS}" --seed="${THESEED}" \
                                                 --condorsite="$THECONDORSITE" --condoroutdir="$THECONDOROUTDIR" \
                                                 --outlog="Logs/log_$extLog" --errlog="Logs/err_$extLog" \
                                                 --tarfile="${TARFILE}" --batchqueue="${THEQUEUE}" --batchscript="${THEBATCHSCRIPT}"

done < "$INFILE"
