# Build once on a networked Linux amd64 machine, never inside a compute job.
FROM claudiarodes/gcamreport_docker@sha256:4f6d7fffda537ec065fe5cf46510966c538532b40c5fa788cacccc97caeafc4c
USER root
COPY gcamreport /opt/gcamreport-src
COPY install-dependencies.R /opt/install-dependencies.R
RUN Rscript --vanilla /opt/install-dependencies.R \
    && Rscript --vanilla -e 'remotes::install_local("/opt/gcamreport-src", dependencies=FALSE, upgrade="never", force=TRUE, build_vignettes=FALSE); stopifnot(requireNamespace("gcamreport"), requireNamespace("rgcam"), requireNamespace("xml2"), nzchar(Sys.which("java")))' \
    && rm -rf /opt/gcamreport-src /opt/install-dependencies.R
WORKDIR /tmp
