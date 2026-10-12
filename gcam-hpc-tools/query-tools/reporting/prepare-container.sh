#!/usr/bin/env bash
# Build an offline reporting SIF from the exact checked-out submodule.
set -euo pipefail
adapter=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
workspace=$(cd "$adapter/../../.." && pwd)
package="$adapter/../gcamreport"
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || {
    echo "ERROR: run preparation on networked Linux x86_64 (not native macOS/ARM)." >&2; exit 1;
}
[[ -f "$package/DESCRIPTION" ]] || { echo "Initialize the gcamreport submodule first" >&2; exit 1; }
command -v docker >/dev/null
runtime=${GCAMREPORT_RUNTIME:-}
if [[ -z "$runtime" ]]; then
    if command -v apptainer >/dev/null; then runtime=apptainer; else runtime=singularity; fi
fi
command -v "$runtime" >/dev/null
destination=${1:-$workspace/containers/gcamreport}
mkdir -p "$destination"
destination=$(cd "$destination" && pwd)
[[ ! -e "$destination/gcamreport.sif" ]] || { echo "Refusing to overwrite an existing SIF" >&2; exit 1; }
context=$(mktemp -d)
trap 'rm -rf "$context"' EXIT
mkdir "$context/gcamreport"
rsync -a --exclude=.git "$package/" "$context/gcamreport/"
cp "$adapter/Dockerfile" "$context/Dockerfile"
tag="gcamreport-hpc:local"
docker build --platform linux/amd64 -t "$tag" "$context"
docker save -o "$context/image.tar" "$tag"
"$runtime" build "$destination/gcamreport.sif" "docker-archive://$context/image.tar"
"$runtime" exec --cleanenv --no-home "$destination/gcamreport.sif" Rscript --vanilla -e \
    'library(gcamreport); library(rgcam); library(xml2); stopifnot(nzchar(Sys.which("java"))); print(gcamreport::available_GCAM_versions)'
echo "Prepared: $destination/gcamreport.sif"
echo "Upload the SIF to HPC, then set GCAMREPORT_SIF to its absolute path."
