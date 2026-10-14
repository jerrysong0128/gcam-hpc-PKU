# GCAM High Performance Computing Cluster for PKU

<img src="asset/framework/gcam-hpc-tutorial-Run-title.png" alt="GCAM-HPC parallel scenario runs" width="1000">

**BUILD → RUN → QUERY**: build GCAM, run scenario batches on Slurm, and query
and merge each scenario's CSV output.
The toolkit supports `gcam-core` and `gcam-china` source layouts.

[Wiki](https://github.com/jerrysong0128/gcam-hpc-PKU/wiki) ·
[BUILD](https://github.com/jerrysong0128/gcam-hpc-PKU/wiki/1-Build-EN) ·
[RUN](https://github.com/jerrysong0128/gcam-hpc-PKU/wiki/2-Run-EN) ·
[QUERY](https://github.com/jerrysong0128/gcam-hpc-PKU/wiki/3-Query-EN)

## BUILD

Clone with both reporting submodules:

```bash
git clone --recurse-submodules https://github.com/jerrysong0128/gcam-hpc-PKU.git
cd gcam-hpc-PKU
```

In an existing checkout, run `git submodule update --init --recursive` after
updating the main repository. This populates `query-tools/gcamreport/` and
`query-tools/gcamchina-report/` with the revisions selected by this repository.

Download a [gcam-core](https://github.com/JGCRI/gcam-core/releases) or
[gcam-china](https://github.com/umd-cgs/gcam-china/releases) source package,
upload it to the workspace, and extract it there. Its source directory must
contain `cvs/objects/build/linux`. Extract the bundled dependencies:

```bash
cd gcam-hpc-tools/build-tools
unzip gcam-hpc-pku-libs.zip
unzip archive/libs.zip
```

On the HPC, set the workspace and model before loading the environment:

```bash
export GCAM_HPC_WORKSPACE=/absolute/path/to/gcam-hpc-PKU
export GCAM_HPC_CLUSTER=wm2
export GCAMDIR="$GCAM_HPC_WORKSPACE/gcam-core"  # or gcam-china-dev
source "$GCAM_HPC_WORKSPACE/gcam-hpc-tools/build-tools/environment.sh"
```

These settings can also be kept in `build-tools/environment.sh`. Select
`GCAMDIR` explicitly when several model directories exist. The environment
loads `build-tools/profiles/<cluster>.profile` and sets `TOOLDIR`, `SCRATCHDIR`,
dependency paths and the Slurm template. Compile on an allocated compute node:

```bash
cd "$GCAM_LIB"
make clean
make gcam -j 16
```

Adjust the build parallelism to the allocation. Other sites also need matching
compiler/runtime paths and Slurm partitions; see the [build guide](https://github.com/jerrysong0128/gcam-hpc-PKU/wiki/1-Build-EN).

## RUN

Before submission, prepare either [QUERY option](#query) below. The pipeline
runs the selected query/report step after each model scenario and merges the CSVs.

Submit from the login node, using a template and batch matching your model:

```bash
bash "$TOOLDIR/run-pipeline.sh" \
    /absolute/path/to/template.xml \
    /absolute/path/to/batch.xml
```

This uses Option 1 (GCAM QUERY) by default. For Option 2, add
`--postprocess gcamreport` before the XML arguments; see the
[gcamreport guide](gcam-hpc-tools/query-tools/reporting/README.md).

The pipeline loads `environment.sh` itself. Answer `y` → `y` → scenario count
→ `y`; `N` runs the first `N` generated scenarios. Omitting the XML arguments
selects the bundled **gcam-core 8.2** example, so pass China configurations
explicitly for GCAM-China.

Inputs synchronize to the shared `gcam-scratch/input`. Results are under
`gcam-scratch/output/run_<timestamp>/`. Run one pipeline at a time in each
workspace. Successful merging normally removes scenario databases and
temporary configurations; set `GCAM_KEEP_SCRATCH=1` before submission to keep
them. Check `model_status_<index>.txt` for convergence separately from report
success.

## QUERY

Both options work with gcam-core and GCAM-China. Configure your chosen option
before submitting RUN.

| Selection | Preparation | Merged result |
| --- | --- | --- |
| Option 1: GCAM QUERY (default) | Generate QUERY XML and set `modelinterface-batch.xml`; [guide](https://github.com/jerrysong0128/gcam-hpc-PKU/wiki/3-Query-EN#option-1-gcam-query-default) | `Final_<merge-jobid>.csv` |
| Option 2: gcamreport | Prepare the reporting SIF and edit `reporting/report-config.R`; [guide](gcam-hpc-tools/query-tools/reporting/README.md) | `IAMC_Final_<merge-jobid>.csv` |

### Option 1: GCAM QUERY (default)

Edit `query-tools/batch_query_generator/query-config.yaml`, then generate
the QUERY XML:

```bash
cd "$TOOLDIR/query-tools/batch_query_generator"
python3 build_queries.py query-config.yaml
```

Set `<queryFile>` in `query-tools/user_batch_queries/modelinterface-batch.xml`
to the generated filename at its scratch path. ModelInterface queries each
scenario database and the shell merges its CSVs. The
[QUERY Wiki page](https://github.com/jerrysong0128/gcam-hpc-PKU/wiki/3-Query-EN#option-1-gcam-query-default)
explains the paths and configuration. Omit `--postprocess` or use
`--postprocess query` when submitting RUN.

### Option 2: gcamreport

The IAMC route uses the same container and configuration for both models.
It detects GCAM-China from the model directory name or database version and
calls the parallel `gcamchina-report` submodule's R code. Other GCAM runs use
the gcamreport package's version mapping. Both write
`Model,Scenario,Region,Variable,Unit,<years>` and use the same shell CSV merge.
The current China export contains national `China` results.

Prepare the SIF once on a permitted, networked Linux x86_64 build machine
with Apptainer/Singularity, then make it available on the HPC:

```bash
cd /absolute/path/to/gcam-hpc-PKU
bash gcam-hpc-tools/query-tools/reporting/prepare-container.sh
```

The default file is `containers/gcamreport/gcamreport.sif`; reuse it when
already prepared. The [dedicated IAMC Wiki page](https://github.com/jerrysong0128/gcam-hpc-PKU/wiki/gcamreport)
covers dependencies, environment variables, report selections and the tested
GCAM-China SSP1 + SSP2 example.

Follow the separate [gcamreport guide](gcam-hpc-tools/query-tools/reporting/README.md)
for environment configuration and full submission commands with
`--postprocess gcamreport`. This option exports IAMC CSV directly from the
database; it does not require Option 1's QUERY XML.

## Acknowledgements

This repository builds on [Jay Fuhrman's gcam-hpc-starterpack](https://github.com/jayfuhrman/gcam-hpc-starterpack)
at the University of Virginia.
