#!/bin/bash

# This is the main script used for running GCAM on the Evergreen cluster
# It is adapted from the NERSC version!


# --------------------------------------------------------------------------------------------
# 1. Set up the environment
# --------------------------------------------------------------------------------------------


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/environment.sh" || exit 1

if [ -z "$GCAM_HPC_WORKSPACE" ]; then
    echo "NOTICE: Please set GCAM_HPC_WORKSPACE in environment.sh to the absolute path of your gcam-hpc-PKU repo"
    exit 1
fi

cd "${GCAM_HPC_WORKSPACE}"

RUN_SCRIPT="${TOOLDIR}/run-tools/run-scenario.sh"
PBS_TEMPLATEFILE="${SLURM_TEMPLATE}"
PBS_BATCHFILE="${TOOLDIR}/run-tools/slurm-templates/generated-run.slurm"

timestamp=$(date +"%Y%m%d_%H%M%S")
export OUTPUTDIR="${SCRATCHDIR}/output/run_${timestamp}"
mkdir -p "$OUTPUTDIR"
chmod 775 "${OUTPUTDIR}"
echo "Output directory: $OUTPUTDIR"

# --------------------------------------------------------------------------------------------
# 2. Set the configuration and batch files
# --------------------------------------------------------------------------------------------

EXPECTED_ARGS=2

DEFAULT_CONFIG="${TOOLDIR}/configuration-sets/config/v82_default/v82_default_scenario_components.xml"
DEFAULT_BATCH="${TOOLDIR}/configuration-sets/config/v82_default/v82_default_batch_2.xml"

if [ $# -eq $EXPECTED_ARGS ]; then
    CONFIG_FILE="$1"
    BATCH_FILE="$2"
elif [ $# -eq 0 ]; then
    echo "No arguments given, using defaults:"
    CONFIG_FILE="$DEFAULT_CONFIG"
    BATCH_FILE="$DEFAULT_BATCH"
else
    echo "Usage: <script name> <template config file> <batch file>"
    exit
fi

echo "Config file: $(basename "$CONFIG_FILE")"
echo "Batch file: $(basename "$BATCH_FILE")"

# --------------------------------------------------------------------------------------------
# 3. Copy GCAM input directories to scratch
# --------------------------------------------------------------------------------------------


INPUT_OPTIONS="--include=*.xml --include=*.ini --include=climate/*.csv --include=Hist_to_2008_Annual.csv --include=*.jar --exclude=.svn --exclude=*.*"
OUT_OPTIONS="--include=*.xml --exclude=*"
echo "Syncing GCAM input files into scratch directory..."
echo "Syncing input directory to $SCRATCHDIR..."
rsync -ai --recursive $INPUT_OPTIONS ${GCAMDIR}/input ${SCRATCHDIR}/

echo "Syncing output queries to $SCRATCHDIR..."
mkdir -p "${SCRATCHDIR}/output/xmldb_queries" "${SCRATCHDIR}/output/queries"
rsync -ai $OUT_OPTIONS ${TOOLDIR}/query-tools/batch-queries/ ${SCRATCHDIR}/output/xmldb_queries/
rsync -ai $OUT_OPTIONS ${GCAMDIR}/output/queries/ ${SCRATCHDIR}/output/queries/

GCAM_CHINA_QUERY_DIR="${GCAM_HPC_WORKSPACE}/gcam-china/output/queries"
if [ -d "${GCAM_CHINA_QUERY_DIR}" ] && [ "${GCAM_CHINA_QUERY_DIR}" != "${GCAMDIR}/output/queries" ]; then
    echo "Syncing gcam-china output queries to $SCRATCHDIR..."
    rsync -ai $OUT_OPTIONS ${GCAM_CHINA_QUERY_DIR}/ ${SCRATCHDIR}/output/queries/
fi

# --------------------------------------------------------------------------------------------
# 2. Generate the required permutations of the base configuration file
# --------------------------------------------------------------------------------------------

echo "Generate permutations (y/n)?"
read generate
if [[ $generate = 'y' ]]; then
    echo "Generating..."
    "${TOOLDIR}/run-tools/generate-scenarios.sh" "$CONFIG_FILE" "$BATCH_FILE"
	if [[ $? -ne 0 ]]; then
	    echo "Permutator failed, exiting."
	    exit 1
	fi
else
    exit
fi

# --------------------------------------------------------------------------------------------
# 3. Figure out how many jobs will be run and generate the gcam.pbs batch file
# --------------------------------------------------------------------------------------------

template_path=$(dirname "$CONFIG_FILE")
template_root=$(basename "$CONFIG_FILE" | cut -f 1 -d.)
echo "$template_path"
echo "$template_root"

first_task=0

echo "Number of SIMULTANEOUS RUNS to run (normally same as total runs)?"
read num_tasks
ntasks_total=$((8 * num_tasks))

let "last_task=$num_tasks - 1"

let "tasks=$last_task - $first_task + 1"

sed -e "s/NUM_TASKS/${num_tasks}/g" -e "s/NTASKS_TOTAL/${ntasks_total}/g" "$PBS_TEMPLATEFILE" \
> "$PBS_BATCHFILE"

for (( i=0; i<$num_tasks; i++ )); do
    echo "srun -n 1 ./gcam-hpc-tools/run-tools/run-task-wrapper.exe ${template_path}/${template_root} $i &" >> $PBS_BATCHFILE
done
echo "wait" >> $PBS_BATCHFILE

# --------------------------------------------------------------------------------------------
# 4  Go ahead and run!
# --------------------------------------------------------------------------------------------

echo "Run $tasks tasks on cluster (y/n)?"
read run

if [[ $run = 'y' ]]; then
    job=$(sbatch --parsable $PBS_BATCHFILE)
    echo "We are off and running with job $job"
    job2=$(sbatch --parsable --dependency=afterok:$job ${TOOLDIR}/run-tools/merge-query-results.sh)
    chmod +x ./gcam-hpc-tools/run-tools/monitor-jobs.sh
    ./gcam-hpc-tools/run-tools/monitor-jobs.sh
fi

exit


# --------------------------------------------------------------------------------------------
# 5. Cleanup
# --------------------------------------------------------------------------------------------

# Delete the configuration files for tasks we're not running
echo "All done.  Delete generated configuration files?"
read del
if [[ $del -eq 'y' ]]; then
	t=0
	while [ $t -lt $first_task ];
	do
		echo "Removing {template_root}_${t}.xml"
		rm ${template_path}/${template_root}_${t}.xml
		let "t += 1"
	done
fi
