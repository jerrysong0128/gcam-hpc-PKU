#!/usr/bin/env bash
#
# Purpose: Run one numbered GCAM scenario in an isolated executable directory,
# then execute its preconfigured ModelInterface QUERY batch.
# Author: Jingyang Song, Peking University; Jul 2026;
#
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
	[[ "${POSTPROCESS:-query}" != gcamreport ]] || exit 1
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

# Alternative QUERY backend; the official ModelInterface batch remains default.
if [[ "${POSTPROCESS:-query}" == gcamreport ]]; then
    success=0
    unsolved=
    for log in "${OUTPUTDIR}/output_${2}.txt" logs/main_log.txt logs/main_log main_log.txt; do
        if [[ -f "$log" ]]; then
            if grep -q 'Model exiting successfully' "$log"; then success=1; fi
            if [[ -z "$unsolved" ]]; then
                unsolved=$(grep 'The following model periods did not solve:' "$log" | tail -n 1)
            fi
        fi
    done
    # GCAM returns 1 for unsolved periods even after writing its complete database.
    # Preserve the model status separately from the success of report generation.
    status="${OUTPUTDIR}/model_status_${2}.txt"
    printf 'GCAM exit code: %s\nCompletion marker: %s\n' "$err" "$success" > "$status"
    if [[ -n "$unsolved" ]]; then printf '%s\n' "$unsolved" >> "$status"; fi
    [[ "$success" == 1 ]] || { echo "ERROR: GCAM completion marker missing for task $2" >&2; exit 1; }
    if [[ $err -ne 0 ]]; then
        if [[ $err -eq 1 && -n "$unsolved" ]]; then
            echo "WARNING: task $2 completed with unsolved periods; exporting the database. See $status" >&2
        else
            echo "ERROR: GCAM failed for task $2 with exit code $err; see $status" >&2
            exit "$err"
        fi
    fi
    bash "${TOOLDIR}/query-tools/reporting/run-report.sh" "$2"
    exit $?
fi

# make ./inter_query
mkdir -p ./inter_query
# QUERY is configured before RUN and executes after gcam.exe returns.
java -cp "$CLASSPATH" ModelInterface.InterfaceMain -b "../output/xmldb_queries/modelinterface-batch.xml"

if [[ $err -gt 0 ]]; then
	echo "Error code reported: $err"
	echo $err > ${SCRATCHDIR}/errors/$2
fi

echo "Task $2 is done!"
