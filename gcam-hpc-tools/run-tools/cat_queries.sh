#!/bin/bash
#SBATCH --output=gcam-runjob-log/gcamCatCSV.%j.out
#SBATCH --partition=C064M0256G   # Use the valid partition on your cluster (MUST BE UPPERCASE) sacctmgr show ass user=`whoami` format=part | uniq
#SBATCH --job-name=gcamCatCSV
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=2-00:00:00

for exedir in ./exe_*; do
    run_idx=$(echo "$exedir" | sed 's|./exe_||')
    mkdir -p "${OUTPUTDIR}/out_query_${run_idx}"
    for file in "$exedir"/inter_query/queryout*.csv; do
        [ -e "$file" ] || continue
        queryoutname=$(basename "$file" | sed -e "s/queryout/queryoutall/g")
        cat "$file" > "${OUTPUTDIR}/out_query_${run_idx}/${queryoutname}"
    done
done

# Concatenate all queryoutall*.csv to Final.csv
cat "${OUTPUTDIR}"/out_query_*/queryoutall* > "${OUTPUTDIR}/Final.csv"