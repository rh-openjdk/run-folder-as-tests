#!/bin/bash

# this will execute apointed folder $1 as set of tests
# one script is one tes. alphabetical order kept. SKIPping supported.
# JUnit/jreg/xunit compatible xml output. SUpport also reruns of failed tests and timeouts
# only .sh files are processed. You ca hide yor library eg as .bash  or readme
# exactly one argumet - dir with tests - reqired
# second argument - jdk to execute the tests with is optional. 
# if second argument is not found, binary(es) from $WORKSPACE/rpms folder is/are installed
#   and /usr/lib/jvm/java is used as jdk home.
# $SCRATCH_DISK is recomended to set for various garbage operations (preset to /mnt/ramdisk)
# $PREP_SCRIPT is script, wich can be run instead of $2, and will prepare tested product. Defaults to some /mnt/somethign again

## resolve folder of this script, following all symlinks,
## http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SCRIPT_SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  SCRIPT_DIR="$( cd -P "$( dirname "$SCRIPT_SOURCE" )" && pwd )"
  SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
  # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE="$SCRIPT_DIR/$SCRIPT_SOURCE"
done
readonly SCRIPT_DIR="$( cd -P "$( dirname "$SCRIPT_SOURCE" )" && pwd )"


DIR=${1}
if [ "x$DIR" == "x"  -o ! -d "$DIR" ] ; then
 head -n 11 ${SCRIPT_SOURCE} | tail -n 9
 exit 1
fi
if [ "$#" -gt 2 -o "$#" -le 0  ] ; then
 head -n 11 ${SCRIPT_SOURCE} | tail -n 9
 exit 1
fi

ENFORCED_JDK="$2"
ENFORCED_JDK_STATUS="$2"

set -x
set -e
set -o pipefail

# Allow for an environment variable to be passed in.
if [[ x${SUITE} == x ]] ; then
   SUITE=`basename $DIR`
fi

# ${WORKSPACE} is set by jenkins. So when running local, without VM, it uses real jenkins workspace. Otherwise use /mnt/worksace
if [[ x${WORKSPACE} == x ]]; then
  WORKSPACE=/mnt/workspace
fi

# ${SCRATCH_DISK} should be set by user. If not, lets use some default.
if [[ x${SCRATCH_DISK} == x ]]; then
  SCRATCH_DISK=/mnt/ramdisk
fi

# ${PREP_SCRIPT} may be set by user. If not, lets use some default.
if [[ x${PREP_SCRIPT} == x ]]; then
  PREP_SCRIPT="/mnt/shared/TckScripts/jenkins/benchmarks/cleanAndInstallRpms.sh"
fi

if [ "x$ENFORCED_JDK_STATUS" == "x" ] ; then
  rm -rvf $SCRATCH_DISK/rpms; rm -rvf $SCRATCH_DISK/rpms-old
  cp -r ${WORKSPACE}/rpms $SCRATCH_DISK
  if [ -d "${WORKSPACE}/rpms-old" ] ; then
    cp -r ${WORKSPACE}/rpms-old $SCRATCH_DISK
  fi
fi

if [ "x$ENFORCED_JDK_STATUS" == "x" ] ; then
  set +e # .src. is optional
    #removing src.rpm (or src.tarxz) from rpms so install is more flawless
    rm -rf $SCRATCH_DISK/jtreg-src-backup && mkdir $SCRATCH_DISK/jtreg-src-backup &&  mv $SCRATCH_DISK/rpms/*.src.* $SCRATCH_DISK/jtreg-src-backup/
  set -e
  pushd $SCRATCH_DISK
    bash ${PREP_SCRIPT}
  popd
  set +e # .src. is optional
    #moving src.rpm (or src.tarxz) back
    mv $SCRATCH_DISK/jtreg-src-backup/*.src.* $SCRATCH_DISK/rpms/ && rm -rf $SCRATCH_DISK/jtreg-src-backup
  set -e
 ENFORCED_JDK=/usr/lib/jvm/java
else
 echo "Expecting $ENFORCED_JDK"
fi

export ORIGINAL_EXPANDED_JDK=$(readlink -f "$ENFORCED_JDK")
FAILED_TESTS=0
ALL_TESTS=0
PASSED_TESTS=0
SKIPPED_TESTS=0
tmpXmlBodyFile=$(mktemp)
TMPRESULTS=$SCRATCH_DISK/$SUITE/results

rm -rf $SCRATCH_DISK/$SUITE
set -x
mkdir $SCRATCH_DISK/$SUITE
mkdir $TMPRESULTS
rpm -qa | sort > $TMPRESULTS/rpms.txt || echo "no rpms to list"

if [ "x$WHITELIST" == "x" ] ; then
  WHITELIST=".*"
  echo "Including jsut all"
else
  echo "Including jsut $WHITELIST"
fi
if [ "x$BLACKLIST" == "x" ] ; then
  BLACKLIST="absoluteNonsense"
  echo "Excluding nothing"
else
  echo "Excluding $BLACKLIST"
fi
TESTS=`ls $DIR | grep "\\.sh$" | grep -e "$WHITELIST"  | grep -ve "$BLACKLIST" | sort`
echo "tests: $TESTS"
echo -n "" > ${WORKSPACE}/results.txt

source $SCRIPT_DIR/jtreg-shell-xml.sh

function isIgnored() {
  cat $TMPRESULTS/$TEST-result/global-stdouterr.log | grep -e "^\!skipped!"
}

function failOrIgnore() {
  printXmlTest "$SUITE.test" "$TEST" "0.01" "$TMPRESULTS/$TEST-result/global-stdouterr.log" "../artifact/results/$TEST-result/global-stdouterr.log and ../artifact/results/$TEST-result/report.txt" >> $tmpXmlBodyFile
}

if [ "x$RFAT_RERUNS" == "x" ] ; then
  RFAT_RERUNS=5
fi

for TEST in $TESTS ; do
  cd $SCRATCH_DISK/
  TTDIR=$TMPRESULTS/$TEST-result
  set +e
  for x in `seq $RFAT_RERUNS` ; do
    if [ "x$x" = "x1" ] ; then
      echo  "single run"
      echo  "--------ATTEMPT $x/$RFAT_RERUNS of $TEST ----------"
    else
      echo  "rerunning"
      echo  "--------ATTEMPT $x/$RFAT_RERUNS of $TEST ----------"
    fi
    rm -rf $TTDIR
    mkdir $TTDIR
    bash $DIR/$TEST  --jdk=$ENFORCED_JDK --report-dir=$TTDIR   2>&1 | tee $TTDIR/global-stdouterr.log
    RES=$?
    if [ $RES -eq 0 ] ; then
      break
    fi
  done
  echo "Attempt: $x/$RFAT_RERUNS" >> $TMPRESULTS/$TEST-result/global-stdouterr.log
  set -e
  if [ ${RES} -eq 0 ]; then
    if isIgnored ; then
      SKIPPED_TESTS=$(($SKIPPED_TESTS+1))
      echo -n "Ignored" >> ${WORKSPACE}/results.txt
      failOrIgnore
    else
      echo -n "Passed" >> ${WORKSPACE}/results.txt
      PASSED_TESTS=$(($PASSED_TESTS + 1))
      printXmlTest $SUITE.test $TEST 0.01 >> $tmpXmlBodyFile
   fi
  else
    if isIgnored ; then
      SKIPPED_TESTS=$(($SKIPPED_TESTS+1))
      echo -n "Ignored" >> ${WORKSPACE}/results.txt
      failOrIgnore
    else
      FAILED_TESTS=$(($FAILED_TESTS+1))
      echo -n "FAILED" >> ${WORKSPACE}/results.txt
      failOrIgnore
    fi
  fi
  echo " $TEST" >> ${WORKSPACE}/results.txt
  ALL_TESTS=$(($ALL_TESTS+1))
done

printXmlHeader $PASSED_TESTS $FAILED_TESTS $ALL_TESTS $SKIPPED_TESTS $SUITE >  $TMPRESULTS/$SUITE.jtr.xml
cat $tmpXmlBodyFile >>  $TMPRESULTS/$SUITE.jtr.xml
printXmlFooter >>  $TMPRESULTS/$SUITE.jtr.xml
rm $tmpXmlBodyFile
pushd $TMPRESULTS
  tar -czf  $SUITE.tar.gz $SUITE.jtr.xml
popd

rm -rf ${WORKSPACE}/results
cp -r $TMPRESULTS/ ${WORKSPACE}

mv ${WORKSPACE}/results.txt ${WORKSPACE}/results/
#this was originally typo, but as value in properties, it may not metter ven with SUITE variable
echo "rhqa.failed=$FAILED_TESTS" > ${WORKSPACE}/results/results.properties
echo "rhqa.suites=$ALL_TESTS" >> ${WORKSPACE}/results/results.properties #total
echo "rhqa.skipped=$SKIPPED_TESTS" >> ${WORKSPACE}/results/results.properties
echo "rhqa.passed=$PASSED_TESTS" >> ${WORKSPACE}/results/results.properties

if [ "x$ENFORCED_JDK_STATUS" == "x" ] ; then
  rm -rf ${WORKSPACE}/rpms-old
  if [ -e ${WORKSPACE}/rpms ] ; then
    mv ${WORKSPACE}/rpms ${WORKSPACE}/rpms-old
  fi
fi

cat ${WORKSPACE}/results/results.txt
set +x
cd ${WORKSPACE}
pwd
ls -lR

echo "total : $ALL_TESTS"
echo "skiped: $SKIPPED_TESTS"
echo "passed: $PASSED_TESTS"
echo "Failed: $FAILED_TESTS"
# returning 0 to allow unstable state
exit 0
