#!/usr/bin/env bash
# Shared helpers; source this file from the login node or a Slurm task.
report_runtime() {
    if [[ -n "${GCAMREPORT_MODULE:-}" ]]; then
        module load "$GCAMREPORT_MODULE" || return 1
    fi
    if [[ -n "${GCAMREPORT_RUNTIME:-}" ]]; then
        command -v "$GCAMREPORT_RUNTIME" >/dev/null || return 1
        REPORT_RUNTIME=$GCAMREPORT_RUNTIME
    elif command -v apptainer >/dev/null; then
        REPORT_RUNTIME=apptainer
    elif command -v singularity >/dev/null; then
        REPORT_RUNTIME=singularity
    else
        echo "ERROR: load Apptainer/Singularity or set GCAMREPORT_MODULE" >&2
        return 1
    fi
    : "${GCAMREPORT_SIF:?Set GCAMREPORT_SIF to the prepared SIF file}"
    [[ "$GCAMREPORT_SIF" = /* && -r "$GCAMREPORT_SIF" ]] || {
        echo "ERROR: GCAMREPORT_SIF must be an absolute readable path" >&2; return 1;
    }
    REPORT_JARS=${GCAMREPORT_JARS_DIR:-${TOOLDIR}/build-tools/libs/jars}
    REPORT_MI=${GCAMREPORT_MI_JAR:-${GCAMDIR}/output/modelinterface/ModelInterface.jar}
    [[ "$REPORT_JARS" = /* && "$REPORT_MI" = /* && -d "$REPORT_JARS" && -r "$REPORT_MI" ]] || {
        echo "ERROR: missing GCAM JARs; set GCAMREPORT_JARS_DIR and GCAMREPORT_MI_JAR" >&2; return 1;
    }
    # rgcam does NOT read the shell CLASSPATH for its default connection.
    REPORT_RESOURCES=$("$REPORT_RUNTIME" exec --cleanenv --no-home "$GCAMREPORT_SIF" \
        Rscript --vanilla -e 'stopifnot(requireNamespace("gcamreport"), requireNamespace("rgcam")); cat(system.file("ModelInterface", package="rgcam"))') || return 1
    [[ "$REPORT_RESOURCES" = /* ]] || { echo "ERROR: missing rgcam ModelInterface resources" >&2; return 1; }
    REPORT_CONTAINER=( "$REPORT_RUNTIME" exec --cleanenv --no-home
        --bind "$REPORT_JARS:$REPORT_RESOURCES/jars:ro"
        --bind "$REPORT_MI:$REPORT_RESOURCES/ModelInterface.jar:ro" )
}

report_preflight() {
    report_runtime || return 1
    "${REPORT_CONTAINER[@]}" "$GCAMREPORT_SIF" Rscript --vanilla -e \
        'stopifnot(nzchar(Sys.which("java"))); stopifnot(system2("java", "-version") == 0L); resources <- system.file("ModelInterface", package="rgcam"); cp <- paste(file.path(resources,"jars","*"),file.path(resources,"ModelInterface.jar"),sep=":"); stopifnot(system2("java", c("-cp",shQuote(cp),"org.basex.BaseX","-q",shQuote("1"))) == 0L); library(gcamreport); cat("gcamreport:", as.character(packageVersion("gcamreport")), "\nMappings:", paste(gcamreport::available_GCAM_versions, collapse=", "), "\n")'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    set -euo pipefail
    report_preflight
fi
