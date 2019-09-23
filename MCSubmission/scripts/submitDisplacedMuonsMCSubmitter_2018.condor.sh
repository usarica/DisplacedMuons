#!/bin/sh

getvarpaths(){
  for var in "$@";do
    tmppath=${var//:/ }
    for p in $(echo $tmppath);do
      if [[ -e $p ]];then
        echo $p
      fi
    done
  done  
}
searchfileinvar(){
  for d in $(getvarpaths $1);do
    for f in $(ls $d | grep $2);do
      echo "$d/$f"
    done
  done
}
getcmssw(){
  if [ -r "$OSGVO_CMSSW_Path"/cmsset_default.sh ]; then
    echo "sourcing environment: source $OSGVO_CMSSW_Path/cmsset_default.sh"
    source "$OSGVO_CMSSW_Path"/cmsset_default.sh
  elif [ -r "$OSG_APP"/cmssoft/cms/cmsset_default.sh ]; then
    echo "sourcing environment: source $OSG_APP/cmssoft/cms/cmsset_default.sh"
    source "$OSG_APP"/cmssoft/cms/cmsset_default.sh
  elif [ -r /cvmfs/cms.cern.ch/cmsset_default.sh ]; then
    echo "sourcing environment: source /cvmfs/cms.cern.ch/cmsset_default.sh"
    source /cvmfs/cms.cern.ch/cmsset_default.sh
  else
    echo "ERROR! Couldn't find $OSGVO_CMSSW_Path/cmsset_default.sh or /cvmfs/cms.cern.ch/cmsset_default.sh or $OSG_APP/cmssoft/cms/cmsset_default.sh"
    exit 1
  fi
}
copyFromCondorToSite(){
  INPUTDIR=$1
  FILENAME=$2
  OUTPUTSITE=$3 # e.g. 't2.ucsd.edu'
  OUTPUTDIR=$4 # Must be absolute path
  RENAMEFILE=$FILENAME
  if [[ "$5" != "" ]];then
    RENAMEFILE=$5
  fi


  echo "Copy from Condor is called with"
  echo "INPUTDIR: ${INPUTDIR}"
  echo "FILENAME: ${FILENAME}"
  echo "OUTPUTSITE: ${OUTPUTSITE}"
  echo "OUTPUTDIR: ${OUTPUTDIR}"
  echo "RENAMEFILE: ${RENAMEFILE}"


  if [[ "$INPUTDIR" == "" ]];then #Input directory is empty, so assign pwd
    INPUTDIR=$(pwd)
  elif [[ "$INPUTDIR" != "/"* ]];then # Input directory is a relative path
    INPUTDIR=$(pwd)/${INPUTDIR}
  fi

  if [[ "$OUTPUTDIR" != "/"* ]];then # Output directory must be an absolute path!
    echo "Output directory must be an absolute path! Cannot transfer the file..."
    exit 1
  fi


  if [[ ! -z ${FILENAME} ]];then
    echo -e "\n--- begin copying output ---\n"

    echo "Sending output file ${FILENAME}"

    if [[ ! -e ${INPUTDIR}/${FILENAME} ]]; then
      echo "ERROR! Output ${FILENAME} doesn't exist"
      exit 1
    fi

    echo "Time before copy: $(date +%s)"

    COPY_SRC="file://${INPUTDIR}/${FILENAME}"
    COPY_DEST="gsiftp://gftp.${OUTPUTSITE}${OUTPUTDIR}/${RENAMEFILE}"
    echo "Running: env -i X509_USER_PROXY=${X509_USER_PROXY} gfal-copy -p -f -t 7200 --verbose --checksum ADLER32 ${COPY_SRC} ${COPY_DEST}"
    env -i X509_USER_PROXY=${X509_USER_PROXY} gfal-copy -p -f -t 7200 --verbose --checksum ADLER32 ${COPY_SRC} ${COPY_DEST}
    COPY_STATUS=$?
    if [[ $COPY_STATUS != 0 ]]; then
      echo "Removing output file because gfal-copy crashed with code $COPY_STATUS"
      env -i X509_USER_PROXY=${X509_USER_PROXY} gfal-rm -t 7200 --verbose ${COPY_DEST}
      REMOVE_STATUS=$?
      if [[ $REMOVE_STATUS != 0 ]]; then
        echo "gfal-copy crashed and then the gfal-rm also crashed with code $REMOVE_STATUS"
        echo "You probably have a corrupt file sitting on ${OUTPUTDIR} now."
        exit $REMOVE_STATUS
      fi
      exit $COPY_STATUS
    else
      echo "Time after copy: $(date +%s)"
      echo "Copied successfully!"
    fi

    echo -e "\n--- end copying output ---\n"
  else
    echo "File name is not specified!"
    exit 1
  fi
}

TARFILE="$1"
NEVENTS="$2"
SEED="$3"
CONDORSITE="$4"
CONDOROUTDIR="$5"

echo -e "\n--- begin header output ---\n" #                     <----- section division
echo "TARFILE: $TARFILE"
echo "NEVENTS: $NEVENTS"
echo "SEED: $SEED"
echo "CONDORSITE: $CONDORSITE"
echo "CONDOROUTDIR: $CONDOROUTDIR"

echo "GLIDEIN_CMSSite: $GLIDEIN_CMSSite"
echo "hostname: $(hostname)"
echo "uname -a: $(uname -a)"
echo "time: $(date +%s)"
echo "args: $@"
echo "tag: $(getjobad tag)"
echo "taskname: $(getjobad taskname)"
echo -e "\n--- end header output ---\n" #                       <----- section division

echo -e "\n--- begin memory specifications ---\n" #                     <----- section division
ulimit -a
echo -e "\n--- end memory specifications ---\n" #                     <----- section division


INITIALDIR=$(pwd)

mkdir -p rundir
mv ${TARFILE} rundir/
cd rundir
if [[ "${TARFILE}" == *".tgz" ]];then
  tar zxf ${TARFILE}
else
  tar xf ${TARFILE}
fi
rm ${TARFILE}

RUNDIR=$(pwd)

## STEP 1: CREATE GEN-SIM FILES
outname=gensim
outputfile="${outname}_${SEED}.root"
gensimOutputfile="${outputfile}"

if [[ ! -s ${outputfile} ]];then
  echo -e "\n--- Begin GEN-SIM ---\n"

  export SCRAM_ARCH=slc6_amd64_gcc700
  getcmssw
  if [ -r CMSSW_10_2_3/src ] ; then 
    echo release CMSSW_10_2_3 already exists
  else
    scram p CMSSW CMSSW_10_2_3
  fi

  cd CMSSW_10_2_3/src
  eval $(scramv1 runtime -sh)

  fragmentDir=Configuration/GenProduction/python
  fragmentName=${outname}frag.py
  fragmentUseName=${fragmentName}
  mkdir -p ${fragmentDir}
  cp ../../${fragmentName} ${fragmentDir}/${fragmentUseName}
  sed -i "s|.oO\[GRIDPACKDIR\]Oo.|${RUNDIR}|g" ${fragmentDir}/${fragmentUseName}

  scram b
  cd ../../

  cmsDriver.py \
${fragmentDir}/${fragmentUseName} \
--fileout file:${outputfile} \
--mc --eventcontent RAWSIM,LHE --datatier GEN-SIM,LHE \
--conditions 102X_upgrade2018_realistic_v11 --beamspot Realistic25ns13TeVEarly2018Collision \
--step LHE,GEN,SIM --nThreads 1 --geometry DB:Extended --era Run2_2018 \
--python_filename ${outname}_cfg.py \
--customise Configuration/DataProcessing/Utils.addMonitoring --customise_commands process.RandomNumberGeneratorService.externalLHEProducer.initialSeed="int(${SEED})" \
-n ${NEVENTS} || exit $?

  echo -e "\n--- End GEN-SIM ---\n"
fi

## STEP 2: PREMIX-RAW
prevstepname=$outname
outname=premixraw
inputfile="${prevstepname}_${SEED}.root"
outputfile="${outname}_${SEED}.root"
premixrawOutputfile="${outputfile}"
premixrawSlimmedOutputfile="${premixrawOutputfile/.root/_slimmed.root}"

if [[ ! -s ${outputfile} ]];then
  echo -e "\n--- Begin PREMIX-RAW ---\n"

  export SCRAM_ARCH=slc6_amd64_gcc700
  getcmssw
  if [ -r CMSSW_10_2_5/src ] ; then 
    echo release CMSSW_10_2_5 already exists
  else
    scram p CMSSW CMSSW_10_2_5
  fi
  cd CMSSW_10_2_5/src
  eval $(scramv1 runtime -sh)

  scram b
  cd ../../

  sed -i "s|.oO\[INPUTFILE\]Oo.|${inputfile}|g" premixraw_cfg.py
  sed -i "s|.oO\[OUTPUTFILE\]Oo.|${outputfile}|g" premixraw_cfg.py
  cmsRun premixraw_cfg.py || exit $?

  echo -e "\n--- End PREMIX-RAW ---\n"
fi

## STEP 3: AODSIM
prevstepname=$outname
outname=aodsim
inputfile="${prevstepname}_${SEED}.root"
outputfile="${outname}_${SEED}.root"
aodsimOutputfile="${outputfile}"

if [[ ! -s ${outputfile} ]];then
  echo -e "\n--- Begin AOD ---\n"

  export SCRAM_ARCH=slc6_amd64_gcc700
  getcmssw
  if [ -r CMSSW_10_2_5/src ] ; then 
    echo release CMSSW_10_2_5 already exists
  else
    scram p CMSSW CMSSW_10_2_5
  fi
  cd CMSSW_10_2_5/src
  eval $(scramv1 runtime -sh)

  scram b
  cd ../../

  sed -i "s|.oO\[INPUTFILE\]Oo.|${inputfile}|g" aodsim_cfg.py
  sed -i "s|.oO\[OUTPUTFILE\]Oo.|${outputfile}|g" aodsim_cfg.py
  cmsRun aodsim_cfg.py || exit $?

  echo -e "\n--- End AODSIM ---\n"
fi

## STEP 3: MINIAODSIM
prevstepname=$outname
outname=miniaodsim
inputfile="${prevstepname}_${SEED}.root"
outputfile="${outname}_${SEED}.root"
miniaodsimOutputfile="${outputfile}"

if [[ ! -s ${outputfile} ]];then
  echo -e "\n--- Begin MINIAODSIM ---\n"

  export SCRAM_ARCH=slc6_amd64_gcc700
  getcmssw
  if [ -r CMSSW_10_2_5/src ] ; then 
    echo release CMSSW_10_2_5 already exists
  else
    scram p CMSSW CMSSW_10_2_5
  fi
  cd CMSSW_10_2_5/src
  eval $(scramv1 runtime -sh)

  scram b
  cd ../../

  sed -i "s|.oO\[INPUTFILE\]Oo.|${inputfile}|g" miniaodsim_cfg.py
  sed -i "s|.oO\[OUTPUTFILE\]Oo.|${outputfile}|g" miniaodsim_cfg.py
  cmsRun miniaodsim_cfg.py || exit $?

  echo -e "\n--- End MINIAODSIM ---\n"
fi

##################
# TRANSFER FILES #
##################
echo "Submission directory after running all steps: ls -lrth"
ls -lrth
if [[ -s ${miniaodsimOutputfile} ]] && [[ -s ${premixrawSlimmedOutputfile} ]];then
  copyFromCondorToSite ${RUNDIR} ${premixrawSlimmedOutputfile} ${CONDORSITE} ${CONDOROUTDIR}/PREMIX-RAWSIM
  copyFromCondorToSite ${RUNDIR} ${miniaodsimOutputfile} ${CONDORSITE} ${CONDOROUTDIR}/MINIAODSIM
fi
##############


echo "Submission directory after running: ls -lrth"
ls -lrth

echo "time at end: $(date +%s)"
