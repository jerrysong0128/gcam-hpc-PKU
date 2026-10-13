#!/usr/bin/env bash
#
# Purpose: Orchestrate GCAM input sync, scenario expansion, Slurm submission,
# per-scenario QUERY execution, and the dependent CSV merge job.
# Author: Jingyang Song, Peking University; Jul 2026;
#
# Adapted from the NERSC workflow for PKU HPC clusters.


# --------------------------------------------------------------------------------------------
# 1. Set up the environment
# --------------------------------------------------------------------------------------------


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/build-tools/environment.sh" || exit 1

if [ -z "$GCAM_HPC_WORKSPACE" ]; then
    echo "NOTICE: Please set GCAM_HPC_WORKSPACE in build-tools/environment.sh to the absolute path of your gcam-hpc-PKU repo"
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

# Use environment.sh's backend; an explicit command-line option takes priority.
export POSTPROCESS="${POSTPROCESS:-query}"
if [[ "${1:-}" == "--postprocess" ]]; then
    export POSTPROCESS="${2:-}"
    shift 2 || exit 2
fi
case "$POSTPROCESS" in
    query|gcamreport) ;;
    *) echo "Usage: $0 [--postprocess query|gcamreport] [template.xml batch.xml]" >&2; exit 2 ;;
esac
echo "QUERY backend: $POSTPROCESS"

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
# 3. Copy GCAM inputs and the preconfigured QUERY XML files to scratch
# --------------------------------------------------------------------------------------------


INPUT_OPTIONS="--include=*.xml --include=*.ini --include=climate/*.csv --include=Hist_to_2008_Annual.csv --include=*.jar --exclude=.svn --exclude=*.*"
OUT_OPTIONS="--include=*.xml --exclude=*"
echo "Syncing GCAM input files into scratch directory..."
echo "Syncing input directory to $SCRATCHDIR..."
mkdir -p "$SCRATCHDIR" || exit 1
rsync -ai --recursive $INPUT_OPTIONS ${GCAMDIR}/input ${SCRATCHDIR}/ || exit 1

echo "Syncing output queries to $SCRATCHDIR..."
mkdir -p "${SCRATCHDIR}/output/xmldb_queries" "${SCRATCHDIR}/output/queries"
rsync -ai $OUT_OPTIONS ${TOOLDIR}/query-tools/user_batch_queries/ ${SCRATCHDIR}/output/xmldb_queries/ || exit 1
rsync -ai $OUT_OPTIONS ${GCAMDIR}/output/queries/ ${SCRATCHDIR}/output/queries/ || exit 1

GCAM_CHINA_QUERY_DIR="${GCAM_HPC_WORKSPACE}/gcam-china/output/queries"
if [ -d "${GCAM_CHINA_QUERY_DIR}" ] && [ "${GCAM_CHINA_QUERY_DIR}" != "${GCAMDIR}/output/queries" ]; then
    echo "Syncing gcam-china output queries to $SCRATCHDIR..."
    rsync -ai $OUT_OPTIONS ${GCAM_CHINA_QUERY_DIR}/ ${SCRATCHDIR}/output/queries/ || exit 1
fi

# --------------------------------------------------------------------------------------------
# 4. Generate the requested scenario configurations
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
# 5. Generate the Slurm task file for the requested number of scenarios
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

if [[ "$POSTPROCESS" == gcamreport ]]; then
    # Check paths on the submission node; run R/Java preflight in the allocation.
    source "${TOOLDIR}/query-tools/reporting/container.sh"
    report_prerequisites || exit 1
    printf 'bash %q || exit $?\n' "${TOOLDIR}/query-tools/reporting/container.sh" >> "$PBS_BATCHFILE"
    echo 'pids=()' >> "$PBS_BATCHFILE"
fi

for (( i=0; i<$num_tasks; i++ )); do
    if [[ "$POSTPROCESS" == gcamreport ]]; then
        # Propagate report failures without depending on the old MPI binary.
        printf 'srun -N 1 -n 1 bash %q %q %s &\n' "$RUN_SCRIPT" "${template_path}/${template_root}" "$i" >> "$PBS_BATCHFILE"
        echo 'pids+=( "$!" )' >> "$PBS_BATCHFILE"
    else
        echo "srun -n 1 ./gcam-hpc-tools/run-tools/run-task-wrapper.exe ${template_path}/${template_root} $i &" >> $PBS_BATCHFILE
    fi
done
if [[ "$POSTPROCESS" == gcamreport ]]; then
    echo 'result=0; for pid in "${pids[@]}"; do if wait "$pid"; then :; else result=1; fi; done; exit "$result"' >> "$PBS_BATCHFILE"
else
    echo "wait" >> $PBS_BATCHFILE
fi

# --------------------------------------------------------------------------------------------
# 6. Submit RUN and schedule the result merge after the Slurm job
# --------------------------------------------------------------------------------------------

echo "Run $tasks tasks on cluster (y/n)?"
read run

if [[ $run = 'y' ]]; then
    mkdir -p "${GCAM_HPC_WORKSPACE}/gcam-runjob-log" || exit 1
    job=$(sbatch --parsable "$PBS_BATCHFILE") || exit 1
    job=${job%%;*}
    [[ "$job" =~ ^[0-9]+$ ]] || { echo "ERROR: invalid Slurm RUN job ID: $job" >&2; exit 1; }
    echo "We are off and running with job $job"
    state="$OUTPUTDIR/jobs.env"
    printf 'OUTPUTDIR=%q\nSCRATCHDIR=%q\nRUN_JOB_ID=%q\n' "$OUTPUTDIR" "$SCRATCHDIR" "$job" > "$state" || exit 1
    job2=$(sbatch --parsable --dependency=afterok:$job "${TOOLDIR}/run-tools/merge-query-results.sh") || {
        echo "ERROR: merge submission failed; RUN job $job is recorded in $state" >&2; exit 1;
    }
    job2=${job2%%;*}
    [[ "$job2" =~ ^[0-9]+$ ]] || { echo "ERROR: invalid Slurm merge job ID: $job2" >&2; exit 1; }
    printf 'MERGE_JOB_ID=%q\n' "$job2" >> "$state"
    echo "Merge job: $job2; job record: $state"
    bash "${TOOLDIR}/run-tools/monitor-jobs.sh"
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
