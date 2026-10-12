#!/usr/bin/env bash
# Export one completed scenario to IAMC CSV using the prepared R container.
set -euo pipefail
[[ $# == 1 ]] || { echo "Usage: bash run-report.sh <task-index>" >&2; exit 2; }
index=$1
[[ "$index" =~ ^[0-9]+$ ]] || exit 2
adapter=$(cd "$TOOLDIR/query-tools/reporting" && pwd -P)
scratch=$(cd "$SCRATCHDIR" && pwd -P)
run_dir=$(cd "$OUTPUTDIR" && pwd -P)
source "$adapter/container.sh"
report_runtime
dest="$run_dir/out_iamc_$index"
mkdir -p "$dest"
stage=$(mktemp -d "$dest/work.XXXXXXXX")
trap 'rm -rf "$stage"' EXIT
# Keep upstream temporary files and auxiliary outputs out of the results.
mkdir "$stage/tmp"
touch "$stage/.here"
"${REPORT_CONTAINER[@]}" --bind "$scratch:$scratch" --bind "$run_dir:$run_dir" \
    --bind "$adapter:$adapter:ro" --pwd "$stage" \
    --env "TMPDIR=$stage/tmp,TZ=UTC" "$GCAMREPORT_SIF" \
    Rscript --vanilla "$adapter/report.R" "$scratch/exe_$index/config_this.xml" \
    "$scratch/exe_$index" "${GCAMREPORT_VERSION:-}" "$GCAMDIR" > "$dest/report.log" 2>&1 || {
        echo "ERROR: gcamreport failed; inspect $dest/report.log" >&2; exit 1;
    }
[[ -s "$stage/iamc.csv" ]] || { echo 'ERROR: gcamreport did not export iamc.csv' >&2; exit 1; }
mv "$stage/iamc.csv" "$dest/iamc.csv"
echo "IAMC CSV ready: $dest/iamc.csv"
