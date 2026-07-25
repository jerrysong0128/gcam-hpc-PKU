# GCAM High Performance Computing Cluster for PKU

BUILD · RUN · QUERY

This guide describes how to set up and build GCAM for high-performance computing (HPC) at PKU. It covers cloning the necessary repositories, preparing dependencies, configuring environment variables, and building the GCAM model.

The same toolkit works with **any version of `gcam-core` or `gcam-china`** — pick the release you want from upstream and the tools auto-detect the variant.

---
Visit this [Wiki](https://github.com/jerrysong0128/gcam-hpc-PKU/wiki)

## Quickstart

1. Clone this repo somewhere on the cluster, e.g. `~/GCAM_Workspace/gcam-hpc-PKU`.
2. Fetch a GCAM source release with the bundled script (downloads the tagged
   tarball from GitHub and extracts it next to `gcam-hpc-tools/`):
   ```bash
   # gcam-core
   ./gcam-hpc-tools/fetch-gcam-source.sh --variant core  --version gcam-v8.2

   # gcam-china
   ./gcam-hpc-tools/fetch-gcam-source.sh --variant china --version gcam-china-v8
   ```
   Pick any release tag from the upstream repos:
   - gcam-core: <https://github.com/JGCRI/gcam-core/releases>
   - gcam-china: <https://github.com/umd-cgs/gcam-china/releases>

   The extracted directory matches `gcam-*/cvs/objects/build/linux` and is
   auto-detected (e.g. `gcam-core-v8.2/`, `gcam-china-v8/`). If you prefer to
   download manually, just unpack the archive into the workspace yourself.
3. Edit two lines in `gcam-hpc-tools/environment.sh`:
   ```bash
   export GCAM_HPC_WORKSPACE=/absolute/path/to/gcam-hpc-PKU
   export GCAM_HPC_CLUSTER=wm2     # or wm1, or a custom profile you add
   ```
4. Source it once per shell:
   ```bash
   source $GCAM_HPC_WORKSPACE/gcam-hpc-tools/environment.sh
   ```
   This exports everything the build and run flows need (`GCAMDIR`, `TOOLDIR`, `SCRATCHDIR`, `BOOST_*`, `JAVA_*`, `TBB_*`, `EIGEN_INCLUDE`, `JARS_LIB`, `SLURM_TEMPLATE`). No other exports are needed.

To support a new site, copy `build-tools/profiles/custom.profile` to `<yoursite>.profile`, fill in the paths, and set `GCAM_HPC_CLUSTER=<yoursite>`.

## Step BUILD

```sh
source $GCAM_HPC_WORKSPACE/gcam-hpc-tools/build-tools/build-environment.sh
cd "$GCAM_LIB"
make clean
make gcam -j 16
```

## Step RUN

After sourcing `environment.sh`:

```sh
"$TOOLDIR/run-pipeline.sh" \
    "$TOOLDIR/configuration-sets/temp/v82_default_scenario_components.xml" \
    "$TOOLDIR/configuration-sets/config/events/0828/reference_batch_SSP_MFA_policy.xml"
```

```sh
"$TOOLDIR/run-pipeline.sh" \
    "$TOOLDIR/configuration-sets/temp/v82_default_scenario_components.xml" \
    "$TOOLDIR/configuration-sets/config/events/0910/batch_SSP_mfa_0910.xml"
```

Run with no arguments to use the bundled defaults.

## Step QUERY

Configure QUERY before starting `run-pipeline.sh`:

```sh
cd "$TOOLDIR/query-tools/batch_query_generator"
python3 build_queries.py query-config.yaml
```

The builder reads query definitions from `query-definitions/` and writes a
timestamped `queries-YYYYmmdd-HHMMSS.xml` file under `batch-queries/`. Set the
`<queryFile>` entry in `batch-queries/modelinterface-batch.xml` to that file.

During RUN, every scenario executes the same synchronized QUERY configuration.
After the Slurm run job returns successfully, `merge-query-results.sh` collects
the per-scenario CSV files and concatenates them into `Final_<jobid>.csv` under
`$SCRATCHDIR/output/run_<timestamp>/`.
