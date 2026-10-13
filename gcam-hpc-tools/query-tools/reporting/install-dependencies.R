#!/usr/bin/env Rscript
# A compatible set for the pinned R 4.1 base and gcamreport's dplyr 1.1 APIs.
# Do not resolve these against today's CRAN: partial upgrades break old dplyr.
pins <- c(cli="3.6.5", rlang="1.1.6", glue="1.8.0", generics="0.1.3",
          lifecycle="1.0.4", vctrs="0.6.5", pillar="1.10.2",
          tibble="3.2.1", tidyselect="1.2.0", dplyr="1.1.4")
options(timeout=600)
for (package in names(pins)) {
    version <- pins[[package]]
    installed <- tryCatch(as.character(packageVersion(package)),
                          error=function(e) "")
    if (installed != version) {
        urls <- c(sprintf("https://cloud.r-project.org/src/contrib/Archive/%s/%s_%s.tar.gz",
                          package, package, version),
                  sprintf("https://cloud.r-project.org/src/contrib/%s_%s.tar.gz",
                          package, version))
        message("Installing pinned dependency: ", package, " ", version)
        archive <- tempfile(fileext=".tar.gz")
        downloaded <- FALSE
        for (url in urls) {
            downloaded <- tryCatch(download.file(url, archive, mode="wb", quiet=TRUE) == 0L,
                                   error=function(e) FALSE)
            if (downloaded) break
        }
        if (!downloaded) stop("Cannot download pinned dependency: ", package, " ", version)
        install.packages(archive, repos=NULL, type="source")
        unlink(archive)
    }
    # install.packages can warn and restore an old version without failing R.
    stopifnot(as.character(packageVersion(package)) == version)
}
library(dplyr)
stopifnot(nrow(reframe(data.frame(x=1:2), x=sum(x))) == 1L,
          nrow(left_join(data.frame(x=1), data.frame(x=1), by="x",
                         multiple="all", relationship="many-to-many")) == 1L)
cat("Pinned reporting dependencies validated.\n")
