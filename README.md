# GCAM High Performance Computing Cluster for PKU

BUILD · RUN · QUERY

This guide describes how to set up and build GCAM for high-performance computing (HPC) at PKU. It covers cloning the necessary repositories, preparing dependencies, configuring environment variables, and building the GCAM model.

The same toolkit works with **any version of `gcam-core` or `gcam-china`** — pick the release you want from upstream and the tools auto-detect the variant.

---
Visit this [Wiki](https://github.com/jerrysong0128/gcam-hpc-PKU/wiki)

## Quickstart

1. Clone this repo somewhere on the cluster, e.g. `~/GCAM_Workspace/gcam-hpc-PKU`.
2. Drop a GCAM source release under that workspace:
   - gcam-core: <https://github.com/JGCRI/gcam-core/releases>
   - gcam-china: <https://github.com/umd-cgs/gcam-china/releases>

   Any directory matching `gcam-*/cvs/objects/build/linux` is auto-detected (e.g. `gcam-core-v8.2/`, `gcam-china-7.0/`).
3. Edit two lines in `gcam-hpc-tools/gcam_workspace.setup`:
   ```bash
   export GCAM_HPC_WORKSPACE=/absolute/path/to/gcam-hpc-PKU
   export GCAM_HPC_CLUSTER=wm2     # or wm1, or a custom profile you add
   ```
4. Source it once per shell:
   ```bash
   source $GCAM_HPC_WORKSPACE/gcam-hpc-tools/gcam_workspace.setup
   ```
   This exports everything the build and run flows need (`GCAMDIR`, `TOOLDIR`, `SCRATCHDIR`, `BOOST_*`, `JAVA_*`, `TBB_*`, `EIGEN_INCLUDE`, `JARS_LIB`, `SLURM_TEMPLATE`). No other exports are needed.

To support a new site, copy `build-tools/profiles/custom.profile` to `<yoursite>.profile`, fill in the paths, and set `GCAM_HPC_CLUSTER=<yoursite>`.

## Step BUILD

```sh
source $GCAM_HPC_WORKSPACE/gcam-hpc-tools/build-tools/gcam-hpc-build.setup
cd "$GCAM_LIB"
make clean
make gcam -j 16
```

## Step RUN

After sourcing `gcam_workspace.setup`:

```sh
"$TOOLDIR/master.sh" \
    "$TOOLDIR/configuration-sets/temp/v82_default_scenario_components.xml" \
    "$TOOLDIR/configuration-sets/config/events/0828/reference_batch_SSP_MFA_policy.xml"
```

```sh
"$TOOLDIR/master.sh" \
    "$TOOLDIR/configuration-sets/temp/v82_default_scenario_components.xml" \
    "$TOOLDIR/configuration-sets/config/events/0910/batch_SSP_mfa_0910.xml"
```

Run with no arguments to use the bundled defaults.

## Step QUERY

After the slurm job finishes, the per-task CSVs are concatenated into `Final_<jobid>.csv` under `$SCRATCHDIR/output/run_<timestamp>/` by `cat_queries.sh`.
