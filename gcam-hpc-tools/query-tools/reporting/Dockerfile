# Build once on a networked Linux amd64 machine, never inside a compute job.
FROM claudiarodes/gcamreport_docker@sha256:4f6d7fffda537ec065fe5cf46510966c538532b40c5fa788cacccc97caeafc4c
USER root
COPY gcamreport /opt/gcamreport-src
RUN Rscript --vanilla -e 'remotes::install_local("/opt/gcamreport-src", dependencies=NA, upgrade="never", build_vignettes=FALSE); stopifnot(requireNamespace("gcamreport"), requireNamespace("rgcam"), requireNamespace("xml2"), nzchar(Sys.which("java")))' \
    && rm -rf /opt/gcamreport-src
WORKDIR /tmp
