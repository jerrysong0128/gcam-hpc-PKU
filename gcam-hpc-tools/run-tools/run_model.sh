#!/bin/bash

# 1. Clean up module environment
module load gcc/12.2.0  # Must match build compiler exactly
export CLASSPATH=$(find $GCAM_WORKSPACE/gcam-hpc-tools/build-tools/libs/jars -name "*.jar" | tr '\n' ':')




# Add unique database ports per task
export BASEX_PORT=$((8992 + $2))
echo "Using BaseX port: $BASEX_PORT for task $2"

# Script expects two parameters: the configuration filename and the task number
# Filename should be the base name, not including job number or extension

CONFIGURATION_FILE=${1}_${2}.xml

# cp ${GCAMDIR}/configuration-sets/run_set_documentation.txt ${SCRATCHDIR}
echo "copied run set documentation to scratch"

if [ ! -e $CONFIGURATION_FILE ]; then
	echo "$CONFIGURATION_FILE does not exist; task $2 bailing!"
	exit 
fi

echo "Configuration file: $CONFIGURATION_FILE"


# It turns out that to pass data from C++ to Fortran, MiniCAM writes out a 'gas.emk' file
# which is then read in by MAGICC.  This is not good, as multiple instances will stomp
# all over each other.  The long-term solution is to pass internally; for now, we'll 
# create separate exe directories, even though this is a performance hit.


rm -rf ${SCRATCHDIR}/exe_$2	 	# just in case
#mkdir ${SCRATCHDIR}/exe_$2
cp -fR ${GCAMDIR}/exe ${SCRATCHDIR}/exe_$2
cd ${SCRATCHDIR}/exe_$2



echo "Running Minicam with ${CONFIGURATION_FILE}..."
# let's keep a copy of config file in the running directory
cp ${GCAM_WORKSPACE}/$CONFIGURATION_FILE ./config_this.xml

chmod 2775 gcam.exe

echo "Starting gcam"
./gcam.exe -C${GCAM_WORKSPACE}/$CONFIGURATION_FILE > output_${2}.txt 
err=$?

chmod 2775 -R ${SCRATCHDIR}/exe_$2

if [[ $err -gt 0 ]]; then
	echo "Error code reported: $err"
	echo $err > ${SCRATCHDIR}/errors/$2
else
    cp gas.emk ${SCRATCHDIR}/output/gas_${2}.emk
fi

echo "Task $2 is done!"


