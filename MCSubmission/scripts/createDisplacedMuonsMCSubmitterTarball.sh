#!/bin/sh

TARFILE=$1
FRAGDIR=$2
GRIDDIR=$3

HERE=$(pwd)
echo "The tarball will appear in $HERE"

TMPDIR=$(mktemp -d)

if [[ -d $FRAGDIR ]];then
  rsync -zavL $FRAGDIR/* ${TMPDIR}/
else
  echo "$FRAGDIR is not a directory!"
  exit 1
fi
if [[ -d $GRIDDIR ]] && [[ -s "${GRIDDIR}/gridpack.tgz" ]];then
  rsync -zavL $GRIDDIR/* ${TMPDIR}/
elif [[ -d $GRIDDIR ]];then
  echo "${GRIDDIR}/gridpack.tgz does not exist!"
  exit 1
else
  echo "$GRIDDIR is not a directory!"
  exit 1
fi

pushd $TMPDIR

rm -rf ${TARFILE}
tar Jcvf ${TARFILE} $(ls ./ | grep -v ${TARFILE})
mv $TARFILE ${HERE}/

popd

rm -rf $TMPDIR
