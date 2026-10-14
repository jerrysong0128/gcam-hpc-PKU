# Export GCAM databases to IAMC CSV

[QUERY overview](../../../README.md#query) ·
[Wiki guide (中文)](https://github.com/jerrysong0128/gcam-hpc-PKU/wiki/gcamreport) ·
[GCAM-China source notes](gcamchina-report.md)

This guide covers **QUERY → Option 2: gcamreport** in the
**BUILD → RUN → QUERY** workflow. Option 1 (GCAM QUERY) remains the default.

Use `run-pipeline.sh --postprocess gcamreport` for both gcam-core and
GCAM-China:

**GCAM → BaseX database → IAMC CSV per scenario → shell CSV merge**.

The same SIF and `report-config.R` serve both models. The adapter detects
China from `GCAMDIR`'s directory name or the database version, then runs the
R code in the parallel `gcamchina-report` submodule. For core, it selects a
mapping from database metadata and calls `gcamreport::generate_report()`.
All integration lives outside the two submodules.

GCAM-China 8.2 with SSP1 + SSP2 has completed this workflow on PKU wm2.
Its current IAMC export aggregates provincial calculations to `Region=China`.
It preserves the database's periods, including 2021; it does not export
province rows. Undefined non-finite capacity values are written as blank CSV
cells. Core mapping coverage depends on the prepared SIF; unsupported mappings
fail explicitly. The Slurm preflight prints the installed mappings.

## 1. Configure the HPC workspace

Download and compile a GCAM source package as described in the
[build guide](https://github.com/jerrysong0128/gcam-hpc-PKU/wiki/1-Build-EN).
The run machine needs Bash, rsync, Perl, Slurm, the compiled `exe/gcam.exe`,
and the extracted GCAM dependencies. Initialize **both** reporting submodules:

```bash
cd /absolute/path/to/gcam-hpc-PKU
git pull --ff-only
git submodule update --init --recursive
test -s gcam-hpc-tools/query-tools/gcamreport/DESCRIPTION
test -s gcam-hpc-tools/query-tools/gcamchina-report/Reporting.R
```

An empty `gcamchina-report/` directory means its submodule has not been
initialized. If HPC GitHub access fails, initialize on a connected machine and
transfer the populated source directories to the corresponding HPC paths.

Extract the dependency bundle once:

```bash
cd gcam-hpc-tools/build-tools
unzip gcam-hpc-pku-libs.zip
unzip archive/libs.zip
```

This creates `libs/{boost-lib,eigen,jars,java_linux,tbb-linux}`. The host GCAM
binary uses these dependencies; reporting also reads `libs/jars/`.
The SIF supplies R, reporting packages and the reporting Java runtime, so no
host R installation is needed.

Set the paths before loading the environment on the HPC:

```bash
export GCAM_HPC_WORKSPACE=/absolute/path/to/gcam-hpc-PKU
export GCAM_HPC_CLUSTER=wm2
export GCAMDIR="$GCAM_HPC_WORKSPACE/gcam-china-dev"  # choose your model
source "$GCAM_HPC_WORKSPACE/gcam-hpc-tools/build-tools/environment.sh"
```

For core, choose `gcam-core` or its actual release directory. Explicit model
selection is required when several source directories exist. You can keep
the workspace and cluster defaults in `build-tools/environment.sh`.
The wm2 profile loads `gcc/12.2.0` and exports the library paths and Slurm
template. Build GCAM on an allocated compute node. At another site, adapt
its profile, the run script's compiler/library paths, and the RUN and merge
Slurm directives to the available modules and partition.

| Variable | Default / purpose |
| --- | --- |
| `GCAM_HPC_WORKSPACE` | Absolute repository root on the HPC |
| `GCAM_HPC_CLUSTER` | `wm2`; also `wm1` or a custom profile |
| `GCAMDIR` | Model source directory; explicit export overrides detection |
| `GCAMREPORT_SIF` | `$GCAM_HPC_WORKSPACE/containers/gcamreport/gcamreport.sif` |
| `GCAMREPORT_MODULE` | `singularity/3.11.3`; an explicit empty value uses PATH |
| `GCAMREPORT_CONFIG` | `$TOOLDIR/query-tools/reporting/report-config.R` |
| `POSTPROCESS` | `query`; the command-line flag selects `gcamreport` for this run |
| `SCRATCHDIR` | Always `$GCAM_HPC_WORKSPACE/gcam-scratch` |

Export overrides before submission. Normally leave `GCAMREPORT_MI_JAR` unset:
reporting uses rgcam's compiled ModelInterface JAR inside the SIF and binds
host dependencies into rgcam's resource directory. A compatible compiled JAR
can be selected with `GCAMREPORT_MI_JAR`; a different dependency directory
with `GCAMREPORT_JARS_DIR`. Changing the shell `CLASSPATH` alone does not
configure rgcam's connection.

## 2. Prepare or reuse the reporting container

Reuse `containers/gcamreport/gcamreport.sif` when it is already prepared.
GCAM-China uses this same file; its reporting R source is read from the
submodule at runtime. Container preparation and model/report execution belong
on nodes permitted for those workloads; submit jobs from the login node.

To build the SIF, use a permitted, networked **Linux x86_64** machine with
rsync and Apptainer/Singularity. Native macOS/ARM cannot run this preparation
script. The default sandbox downloader also needs curl, jq, sha256sum, stat
and tar. Load the site's runtime module if necessary:

```bash
cd /absolute/path/to/gcam-hpc-PKU
git submodule update --init --recursive
export GCAMREPORT_MODULE=singularity/3.11.3  # PKU wm2; use your site's module
bash gcam-hpc-tools/query-tools/reporting/prepare-container.sh
```

Preparation chooses a usable Docker daemon when available, otherwise a
user-owned sandbox without Docker, sudo or fakeroot. It downloads the pinned
R/Java base image, installs compatible R dependencies and the checked-out
core gcamreport package, validates the SIF, then publishes
`containers/gcamreport/gcamreport.sif`. The mapping-data namespace fix applies
to a build copy. Both submodule checkouts remain unchanged.

`install-dependencies.R` runs inside the container, including installation of
dplyr 1.1.4. Preparation requires registry and CRAN access; subsequent compute
jobs use the SIF offline. If built elsewhere, transfer it to the HPC and set
`GCAMREPORT_SIF` to its absolute path. Source, config, dependencies and SIF
must all be visible on the compute nodes.

The script refuses to overwrite an existing SIF. Build a replacement in another
directory, then select it after validation:

```bash
bash gcam-hpc-tools/query-tools/reporting/prepare-container.sh \
    /absolute/path/to/new-container-directory
export GCAMREPORT_SIF=/absolute/path/to/new-container-directory/gcamreport.sif
```

Optional build settings: `GCAMREPORT_BUILD_MODE=auto|sandbox|docker`,
`GCAMREPORT_RUNTIME` for the runtime executable, and
`GCAMREPORT_SLIM_BASE=0` for the full base image. The default sandbox registry
is `docker.1panel.live`, with cached layers under `containers/gcamreport/base-cache/`.
`GCAMREPORT_BASE_IMAGE` can override its `docker://` URI while retaining the
Dockerfile's pinned digest. Direct Docker Hub access requires the full-base
mode (`GCAMREPORT_SLIM_BASE=0`).

## 3. Select the report contents

Edit `query-tools/reporting/report-config.R`, or copy it and export
`GCAMREPORT_CONFIG=/absolute/path/to/my-report-config.R` before submission.
Keep `report_options` as a named list:

```r
report_options <- list(
  final_year = 2100,
  desired_regions = "All",
  excluded_regions = character(),
  desired_variables = "All",
  inverse_desired_variables = FALSE,
  ignore = c("scrap-constraint", "CO2_NearTerm", "globalCO2_LTG"),
  save_output = FALSE,
  launch_ui = FALSE,
  interactive = FALSE
)
```

Examples: `desired_variables = c("Population", "Emissions|CO2")`, or
`c("Emissions|CO2*")` for a variable family. To exclude specified variables,
set `inverse_desired_variables = TRUE` with a concrete list or pattern.
For core, use `desired_regions = c("China", "USA")` or
`excluded_regions = c("USA")`; selected regions also determine the World
aggregate. `ignore` handles core's unmapped internal/policy markets.

For China, region selection is limited to `China`. The adapter applies
region exclusions, variable selection/exclusion and `final_year` to the
upstream national report. Province names or `USA` cannot add regions to that
report. Other core-specific options do not change China's calculations.

Keep the three unattended-output settings at `FALSE`. The core adapter exports
CSV from gcamreport's RData; the China adapter exports its result directly.
Database, scenario, mapping and output paths are supplied by the task.
Config changes require no SIF rebuild. Finalize the config before submission
and keep it unchanged until the jobs finish. Native QUERY XML generation is
not required for IAMC reporting.

## 4. Submit a batch

On the login node, check the configured paths and runtime:

```bash
test -x "$GCAMDIR/exe/gcam.exe"
test -d "$TOOLDIR/build-tools/libs/jars"
test -r "$GCAMREPORT_SIF"
test -r "$GCAMREPORT_CONFIG"
source "$TOOLDIR/query-tools/reporting/container.sh"
report_prerequisites
```

Full R/Java and BaseX `RunMIQuery` preflight runs in the Slurm allocation.
Use a template and batch matching the selected model. Enable XMLDB output,
with a database in each scenario's isolated working directory, for example:

```xml
<Value write-output="1" append-scenario-name="0" name="xmldb-location">./db/database_basexdb</Value>
```

The adapter reads the actual database path and scenario from the generated
configuration. Submit:

```bash
bash "$TOOLDIR/run-pipeline.sh" --postprocess gcamreport \
    /absolute/path/to/template.xml \
    /absolute/path/to/batch.xml
```

Answer `y` → `y` → number of scenarios → `y`. The count runs scenarios `0`
through `N-1`; it is not a concurrency limit for a longer queue. Enter `2`
for the SSP1 + SSP2 batch. Omitting XML arguments selects the bundled core
8.2 template/batch, so China runs must pass their own pair explicitly.

### Existing GCAM-China SSP1 + SSP2 example

The tested workspace has a four-line memo at
`configuration-sets/config/events/1013/record_1013_china.setup`:

```bash
export GCAMDIR=/lustre/home/2501112459/Desktop/GCAM_Workspace/gcam-hpc-PKU/gcam-china-dev
/lustre/home/2501112459/Desktop/GCAM_Workspace/gcam-hpc-PKU/gcam-hpc-tools/run-pipeline.sh --postprocess gcamreport \
    /lustre/home/2501112459/Desktop/GCAM_Workspace/gcam-hpc-PKU/gcam-hpc-tools/configuration-sets/config/events/1013/v82_china_default_template.xml \
    /lustre/home/2501112459/Desktop/GCAM_Workspace/gcam-hpc-PKU/gcam-hpc-tools/configuration-sets/config/events/1013/batch_china_ssp1_ssp2_1013.xml
```

This uses the China model's default configuration as the template and
`GCAM_China_SSP1` / `GCAM_China_SSP2` as the two scenarios. The memo and event
XMLs are local working files under Git-ignored `events/`; a fresh clone does
not contain them. Reuse them in the prepared workspace, or supply your own
model-matching files. No additional wrapper or environment lines are needed
in the memo after the environment defaults have been configured.

## 5. Results, model status and recovery

Every submission syncs inputs to the existing shared `gcam-scratch/input`.
Only the output directory gets a new timestamp. Run one pipeline at a time
in each workspace; generated Slurm files and `exe_*` directories are shared.
Ctrl-C stops the queue display after submission; submitted jobs continue.

```text
gcam-scratch/output/run_<timestamp>/
├── jobs.env
├── output_<index>.txt
├── model_status_<index>.txt
├── out_iamc_<index>/
│   ├── report.log
│   └── iamc.csv
└── IAMC_Final_<merge-jobid>.csv
```

The IAMC header is `Model,Scenario,Region,Variable,Unit,<years>`. The dependent
merge job checks matching headers, retains one header and concatenates rows
in shell. No R merge step is required for either model. Slurm logs are
`gcam-runjob-log/gcamRunjob.<RUN_JOB_ID>.out` and
`gcam-runjob-log/gcamCatCSV.<MERGE_JOB_ID>.out`.

Successful merging normally removes `gcam-scratch/exe_*` and generated files
under `configuration-sets/temp`, retaining input and output directories.
Export `GCAM_KEEP_SCRATCH=1` before submission to retain databases/configurations
for inspection or re-export; unset it for normal cleanup.

Reporting success does not establish convergence. A GCAM exit code of `1`
with both a completion marker and an explicit unsolved-period summary can
still export its completed database. The original status stays in
`model_status_<index>.txt`. Crashes and incomplete runs stop before reporting.

For failures, inspect `out_iamc_<index>/report.log` and the Slurm RUN log.
An empty China submodule needs initialization. `RunMIQuery` errors require
checking host JAR dependencies and any custom `GCAMREPORT_MI_JAR` override.
Unsupported core versions need a matching mapping in the SIF. Mismatched CSV
headers require consistent configuration and year columns within the batch.
A merge job waiting on `Dependency` is normal during RUN;
`DependencyNeverSatisfied` after RUN failure requires fixing that failure.

Native QUERY remains available with `--postprocess query` and its own XML
configuration.
