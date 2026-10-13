#!/usr/bin/env bash
# Build an offline reporting SIF from the exact checked-out submodule.
set -Eeuo pipefail
phase="checking prerequisites"
trap 'status=$?; printf "ERROR: container preparation failed while %s (exit %s).\n" "$phase" "$status" >&2; exit "$status"' ERR
[[ $# -le 1 ]] || { echo "Usage: bash prepare-container.sh [destination-directory]" >&2; exit 2; }
echo "Preparing gcamreport SIF: checking prerequisites..."
adapter=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
workspace=$(cd "$adapter/../../.." && pwd)
package="$adapter/../gcamreport"
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || {
    echo "ERROR: run preparation on networked Linux x86_64 (not native macOS/ARM)." >&2; exit 1;
}
[[ -f "$package/DESCRIPTION" ]] || {
    echo "ERROR: initialize the gcamreport submodule first: git submodule update --init --recursive" >&2; exit 1;
}
command -v rsync >/dev/null || { echo "ERROR: rsync is not in PATH on this build machine." >&2; exit 1; }
if [[ -n "${GCAMREPORT_MODULE:-}" ]]; then
    module load "$GCAMREPORT_MODULE"
elif ! command -v apptainer >/dev/null && ! command -v singularity >/dev/null; then
    # The PKU login nodes expose Singularity through Environment Modules.
    if type module >/dev/null 2>&1; then
        module load singularity/3.11.3 || {
            echo "ERROR: could not load singularity/3.11.3; set GCAMREPORT_MODULE to your site's module." >&2
            exit 1
        }
    fi
fi
runtime=${GCAMREPORT_RUNTIME:-}
if [[ -z "$runtime" ]]; then
    if command -v apptainer >/dev/null; then
        runtime=apptainer
    elif command -v singularity >/dev/null; then
        runtime=singularity
    else
        echo "ERROR: Apptainer/Singularity is not in PATH. Load the build machine's container module before running this script." >&2
        exit 1
    fi
fi
command -v "$runtime" >/dev/null || {
    echo "ERROR: GCAMREPORT_RUNTIME '$runtime' is not an available executable." >&2; exit 1;
}
mode=${GCAMREPORT_BUILD_MODE:-auto}
case "$mode" in
    auto)
        if command -v docker >/dev/null && docker info >/dev/null 2>&1; then
            mode=docker
        else
            mode=sandbox
        fi
        ;;
    docker)
        command -v docker >/dev/null || { echo "ERROR: Docker is not in PATH." >&2; exit 1; }
        docker info >/dev/null || { echo "ERROR: cannot access the Docker daemon." >&2; exit 1; }
        ;;
    sandbox) ;;
    *) echo "ERROR: GCAMREPORT_BUILD_MODE must be auto, docker or sandbox." >&2; exit 2 ;;
esac
echo "Prerequisites ready: rsync, $runtime; build mode: $mode."
phase="preparing the build context"
destination=${1:-$workspace/containers/gcamreport}
mkdir -p "$destination"
destination=$(cd "$destination" && pwd)
[[ ! -e "$destination/gcamreport.sif" ]] || {
    echo "ERROR: refusing to overwrite an existing SIF: $destination/gcamreport.sif" >&2; exit 1;
}
context=$(mktemp -d "$destination/.build.XXXXXXXX")
trap 'rm -rf "$context"' EXIT
mkdir "$context/gcamreport"
rsync -a --exclude=.git "$package/" "$context/gcamreport/"
# Upstream functions use get(..., asNamespace("gcamreport")), while R keeps
# public datasets in a separate lazydata environment. Add lazy bindings to
# the build copy's namespace before it is sealed; leave the submodule intact.
cat >> "$context/gcamreport/R/zzz.R" <<'R'

.reporting_original_onLoad <- .onLoad
.onLoad <- function(libname, pkgname) {
    .reporting_original_onLoad(libname, pkgname)
    lazyLoad(file.path(libname, pkgname, "data", "Rdata"),
             envir = asNamespace(pkgname))
}
R
cp "$adapter/Dockerfile" "$context/Dockerfile"
cp "$adapter/install-dependencies.R" "$context/install-dependencies.R"
if [[ "$mode" == docker ]]; then
    tag="gcamreport-hpc:local"
    phase="building the Docker image"
    echo "Building Docker image: $tag"
    docker build --platform linux/amd64 -t "$tag" "$context"
    phase="saving the Docker image"
    echo "Saving Docker image for SIF conversion..."
    docker save -o "$context/image.tar" "$tag"
    base="docker-archive://$context/image.tar"
else
    # An unprivileged sandbox is owned by this user. --fix-perms makes its
    # library writable, so R installation needs neither Docker nor fakeroot.
    pinned=$(awk '$1 == "FROM" {print $2; exit}' "$adapter/Dockerfile")
    # Docker Hub is unreachable from the PKU login nodes. Keep the exact digest
    # while using the tested mirror; other sites can override this URI.
    base_image=${GCAMREPORT_BASE_IMAGE:-docker://docker.1panel.live/$pinned}
    [[ "$base_image" == docker://*"@${pinned##*@}" ]] || {
        echo "ERROR: GCAMREPORT_BASE_IMAGE must retain the Dockerfile's pinned digest: ${pinned##*@}" >&2
        exit 1
    }
    phase="downloading the pinned base image into a writable sandbox"
    if [[ "${GCAMREPORT_SLIM_BASE:-1}" == 1 ]]; then
        for tool in curl jq sha256sum stat tar; do
            command -v "$tool" >/dev/null || {
                echo "ERROR: slim base preparation requires $tool; set GCAMREPORT_SLIM_BASE=0 to download the full image." >&2
                exit 1
            }
        done
        echo "Fetching the pinned R/Java environment from: $base_image"
        bash "$adapter/fetch-base.sh" "$base_image" "$destination/base-cache" \
            "$context/base.oci.tar" "${SINGULARITY_CACHEDIR:-${APPTAINER_CACHEDIR:-}}"
        base_image="oci-archive://$context/base.oci.tar"
    elif [[ "$GCAMREPORT_SLIM_BASE" != 0 ]]; then
        echo "ERROR: GCAMREPORT_SLIM_BASE must be 0 or 1." >&2
        exit 2
    fi
    echo "Building user-owned sandbox from: $base_image"
    "$runtime" build --sandbox --fix-perms "$context/rootfs" "$base_image"
    mkdir -p "$context/rootfs/opt/gcamreport-src"
    mkdir -p "$context/rootfs/opt/reporting"
    phase="installing pinned reporting dependencies"
    "$runtime" exec --writable --cleanenv --no-home \
        --bind "$adapter:/opt/reporting:ro" "$context/rootfs" \
        Rscript --vanilla /opt/reporting/install-dependencies.R
    phase="installing the checked-out gcamreport source"
    echo "Installing local gcamreport source inside the sandbox..."
    "$runtime" exec --writable --cleanenv --no-home \
        --bind "$context/gcamreport:/opt/gcamreport-src:ro" \
        "$context/rootfs" Rscript --vanilla -e \
        'remotes::install_local("/opt/gcamreport-src", dependencies=FALSE, upgrade="never", force=TRUE, build_vignettes=FALSE); stopifnot(requireNamespace("gcamreport"), requireNamespace("rgcam"), requireNamespace("xml2"), nzchar(Sys.which("java")))'
    base="$context/rootfs"
fi
phase="building the SIF"
echo "Building SIF: $destination/gcamreport.sif"
# Publish only after validation succeeds; a failed build must not leave a
# gcamreport.sif that the next run mistakes for a prepared container.
"$runtime" build "$context/gcamreport.sif" "$base"
phase="validating the SIF"
echo "Validating R packages and Java inside the SIF..."
"$runtime" exec --cleanenv --no-home "$context/gcamreport.sif" Rscript --vanilla -e \
    'library(gcamreport); library(rgcam); library(xml2); stopifnot(nzchar(Sys.which("java")), packageVersion("dplyr") == "1.1.4"); for (v in gcamreport::available_GCAM_versions) { stopifnot(length(gcamreport::available_variables(print=FALSE, GCAM_version=v)) > 0L, length(gcamreport::available_regions(print=FALSE, GCAM_version=v)) > 0L) }; print(gcamreport::available_GCAM_versions)'
mv "$context/gcamreport.sif" "$destination/gcamreport.sif"
echo "Prepared: $destination/gcamreport.sif"
echo "export GCAMREPORT_SIF='$destination/gcamreport.sif'"
