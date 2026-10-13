#!/usr/bin/env bash
# Shared helpers; source this file from the login node or a Slurm task.
report_prerequisites() {
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
    REPORT_MI=${GCAMREPORT_MI_JAR:-}
    [[ "$REPORT_JARS" = /* && -d "$REPORT_JARS" ]] || {
        echo "ERROR: missing GCAM JARs; set GCAMREPORT_JARS_DIR" >&2; return 1;
    }
    if [[ -n "$REPORT_MI" && ( "$REPORT_MI" != /* || ! -r "$REPORT_MI" ) ]]; then
        echo "ERROR: GCAMREPORT_MI_JAR must be an absolute readable path" >&2; return 1;
    fi
    local config=${GCAMREPORT_CONFIG:-${TOOLDIR}/query-tools/reporting/report-config.R}
    [[ "$config" = /* && -r "$config" ]] || {
        echo "ERROR: GCAMREPORT_CONFIG must be an absolute readable path: $config" >&2; return 1;
    }
}

report_runtime() {
    report_prerequisites || return 1
    # rgcam does NOT read the shell CLASSPATH for its default connection.
    REPORT_RESOURCES=$("$REPORT_RUNTIME" exec --cleanenv --no-home "$GCAMREPORT_SIF" \
        Rscript --vanilla -e 'stopifnot(requireNamespace("gcamreport"), requireNamespace("rgcam")); cat(system.file("ModelInterface", package="rgcam"))') || return 1
    [[ "$REPORT_RESOURCES" = /* ]] || { echo "ERROR: missing rgcam ModelInterface resources" >&2; return 1; }
    REPORT_CONTAINER=( "$REPORT_RUNTIME" exec --cleanenv --no-home
        --bind "$REPORT_JARS:$REPORT_RESOURCES/jars:ro" )
    # rgcam ships the compiled RunMIQuery module. Some GCAM distribution JARs
    # contain only its Java source, so use the bundled JAR unless overridden.
    if [[ -n "$REPORT_MI" ]]; then
        REPORT_CONTAINER+=( --bind "$REPORT_MI:$REPORT_RESOURCES/ModelInterface.jar:ro" )
    fi
}

report_preflight() {
    report_runtime || return 1
    "${REPORT_CONTAINER[@]}" "$GCAMREPORT_SIF" Rscript --vanilla -e \
        'stopifnot(nzchar(Sys.which("java"))); stopifnot(system2("java", "-version") == 0L); resources <- system.file("ModelInterface", package="rgcam"); cp <- paste(file.path(resources,"jars","*"),file.path(resources,"ModelInterface.jar"),sep=":"); query <- "import module namespace mi = \"ModelInterface.ModelGUI2.xmldb.RunMIQuery\"; exists(function-lookup(xs:QName(\"mi:runMIQuery\"), 3))"; result <- system2("java", c("-cp",shQuote(cp),"org.basex.BaseX","-q",shQuote(query)), stdout=TRUE); stopifnot(is.null(attr(result,"status")), identical(trimws(paste(result,collapse="")), "true")); cat("BaseX RunMIQuery: ready\n"); library(gcamreport); cat("gcamreport:", as.character(packageVersion("gcamreport")), "\nMappings:", paste(gcamreport::available_GCAM_versions, collapse=", "), "\n")'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    set -euo pipefail
    report_preflight
fi
