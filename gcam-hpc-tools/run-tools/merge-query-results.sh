#!/usr/bin/env bash
#
# Purpose: Collect each scenario's QUERY CSV files and concatenate them into
# the final run-level CSV after the Slurm RUN job completes.
# Author: Jingyang Song, Peking University; Jul 2026;
#
#SBATCH --output=gcam-runjob-log/gcamCatCSV.%j.out
#SBATCH --partition=C064M0256G   # Use the valid partition on your cluster (MUST BE UPPERCASE) sacctmgr show ass user=`whoami` format=part | uniq
#SBATCH --job-name=gcamCatCSV
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=2-00:00:00

# IAMC CSVs share one header; merge them directly in shell.
if [[ "${POSTPROCESS:-query}" == gcamreport ]]; then
    set -euo pipefail
    shopt -s nullglob
    files=( "$OUTPUTDIR"/out_iamc_*/iamc.csv )
    [[ ${#files[@]} -gt 0 ]] || { echo 'ERROR: no IAMC CSVs to merge' >&2; exit 1; }
    temporary=$(mktemp "$OUTPUTDIR/merge.XXXXXXXX")
    trap 'rm -f "$temporary"' EXIT
    header=
    for csv in "${files[@]}"; do
        IFS= read -r current < "$csv"
        if [[ -z "$header" ]]; then
            header=$current
            printf '%s\n' "$header" > "$temporary"
        fi
        [[ "$current" == "$header" ]] || { echo "ERROR: IAMC headers differ: $csv" >&2; exit 1; }
        tail -n +2 "$csv" >> "$temporary"
    done
    final="$OUTPUTDIR/IAMC_Final_${SLURM_JOB_ID:-manual}.csv"
    mv "$temporary" "$final"
    echo "IAMC CSV ready: $final"
else
# Preserve per-scenario files before removing the isolated executable folders.
for exedir in "${SCRATCHDIR}/exe_"*; do
    run_idx=$(basename "$exedir" | sed 's|exe_||')
    mkdir -p "${OUTPUTDIR}/out_query_${run_idx}"
    for file in "$exedir"/inter_query/*.csv; do
        [ -e "$file" ] || continue
        cp "$file" "${OUTPUTDIR}/out_query_${run_idx}/"
    done
done
# This intentionally preserves the historical raw concatenation behavior.
echo "Concatenating all CSVs to create Final.csv in ${OUTPUTDIR}..."
cat "${OUTPUTDIR}"/out_query_*/*.csv > "${OUTPUTDIR}/Final_${SLURM_JOB_ID}.csv"
fi

echo "Cleaning up: deleting all ${SCRATCHDIR}/exe_* directories..."
rm -rf "${SCRATCHDIR}/exe_"*

echo "Cleaning up: deleting all files in ${TOOLDIR}/configuration-sets/temp ..."
if [[ -d "${TOOLDIR}/configuration-sets/temp" ]]; then
    find "${TOOLDIR}/configuration-sets/temp" -type f ! -name 'v82_default_scenario_components.xml' -delete
fi
