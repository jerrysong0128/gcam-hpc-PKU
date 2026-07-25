#!/bin/bash

# Compiler module is loaded once via the cluster profile (sourced by
# environment.sh); do not duplicate it here.
module load gcc/12.2.0
export LD_LIBRARY_PATH=/lustre/software/gcc/12.2.0/lib64:$LD_LIBRARY_PATH
export CLASSPATH="$(find ${TOOLDIR}/build-tools/libs/jars -name "*.jar" | tr '\n' ':'):${GCAMDIR}/output/modelinterface/ModelInterface.jar"

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
cp -fR ${GCAMDIR}/exe ${SCRATCHDIR}/exe_$2
cd ${SCRATCHDIR}/exe_$2

echo "Running Minicam with ${CONFIGURATION_FILE}..."
# let's keep a copy of config file in the running directory
cp ${CONFIGURATION_FILE} ./config_this.xml

chmod 2775 gcam.exe
chmod 2775 -R ${SCRATCHDIR}/exe_$2

echo "Starting gcam"
./gcam.exe -C${CONFIGURATION_FILE} > "${OUTPUTDIR}/output_${2}.txt"
err=$?

# make ./inter_query
mkdir -p ./inter_query
# Query the output file
java -cp "$CLASSPATH" ModelInterface.InterfaceMain -b "../output/xmldb_queries/modelinterface-batch.xml"

if [[ $err -gt 0 ]]; then
	echo "Error code reported: $err"
	echo $err > ${SCRATCHDIR}/errors/$2
fi

echo "Task $2 is done!"
