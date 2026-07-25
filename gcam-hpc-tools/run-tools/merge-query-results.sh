#!/bin/bash
#SBATCH --output=gcam-runjob-log/gcamCatCSV.%j.out
#SBATCH --partition=C064M0256G   # Use the valid partition on your cluster (MUST BE UPPERCASE) sacctmgr show ass user=`whoami` format=part | uniq
#SBATCH --job-name=gcamCatCSV
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=2-00:00:00

for exedir in "${SCRATCHDIR}/exe_"*; do
    run_idx=$(basename "$exedir" | sed 's|exe_||')
    mkdir -p "${OUTPUTDIR}/out_query_${run_idx}"
    for file in "$exedir"/inter_query/*.csv; do
        [ -e "$file" ] || continue
        cp "$file" "${OUTPUTDIR}/out_query_${run_idx}/"
    done
done
echo "Concatenating all CSVs to create Final.csv in ${OUTPUTDIR}..."
cat "${OUTPUTDIR}"/out_query_*/*.csv > "${OUTPUTDIR}/Final_${SLURM_JOB_ID}.csv"

echo "Cleaning up: deleting all ${SCRATCHDIR}/exe_* directories..."
rm -rf "${SCRATCHDIR}/exe_"*

echo "Cleaning up: deleting all files in ${TOOLDIR}/configuration-sets/temp ..."
find "${TOOLDIR}/configuration-sets/temp" -type f ! -name 'v82_default_scenario_components.xml' -delete