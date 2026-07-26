# GCAM High Performance Computing Cluster for PKU

BUILD · RUN · QUERY

This guide describes the PKU HPC workflow for building GCAM, expanding and
running scenario ensembles, executing a preconfigured QUERY set for every
scenario, and merging the resulting CSV files.

The same toolkit works with **any version of `gcam-core` or `gcam-china`** — pick the release you want from upstream and the tools auto-detect the variant.

---
Visit this [Wiki](https://github.com/jerrysong0128/gcam-hpc-PKU/wiki)

## Quickstart

1. Clone this repo somewhere on the cluster, e.g. `~/GCAM_Workspace/gcam-hpc-PKU`.
2. Fetch a GCAM source release with the bundled script (downloads the tagged
   tarball from GitHub and extracts it next to `gcam-hpc-tools/`):
   ```bash
   # gcam-core
   ./gcam-hpc-tools/build-tools/fetch-gcam-source.sh --variant core  --version gcam-v8.2

   # gcam-china
   ./gcam-hpc-tools/build-tools/fetch-gcam-source.sh --variant china --version gcam-china-v8
   ```
   Pick any release tag from the upstream repos:
   - gcam-core: <https://github.com/JGCRI/gcam-core/releases>
   - gcam-china: <https://github.com/umd-cgs/gcam-china/releases>

   The extracted directory matches `gcam-*/cvs/objects/build/linux` and is
   auto-detected (e.g. `gcam-core-v8.2/`, `gcam-china-v8/`). If you prefer to
   download manually, just unpack the archive into the workspace yourself.
3. Edit two lines in `gcam-hpc-tools/build-tools/environment.sh`:
   ```bash
   export GCAM_HPC_WORKSPACE=/absolute/path/to/gcam-hpc-PKU
   export GCAM_HPC_CLUSTER=wm2     # or wm1, or a custom profile you add
   ```
4. Source it once per shell:
   ```bash
   source $GCAM_HPC_WORKSPACE/gcam-hpc-tools/build-tools/environment.sh
   ```
   This exports everything the build and run flows need (`GCAMDIR`, `TOOLDIR`,
   `SCRATCHDIR`, dependency paths and `SLURM_TEMPLATE`). No compatibility setup
   scripts are required.

To support a new site, copy `build-tools/profiles/custom.profile` to `<yoursite>.profile`, fill in the paths, and set `GCAM_HPC_CLUSTER=<yoursite>`.

## Step BUILD

```sh
source $GCAM_HPC_WORKSPACE/gcam-hpc-tools/build-tools/environment.sh
cd "$GCAM_LIB"
make clean
make gcam -j 16
```

## Step RUN

Configure QUERY first, then run the scenario pipeline. With the bundled GCAM
8.2 example:

```sh
"$TOOLDIR/run-pipeline.sh" \
    "$TOOLDIR/configuration-sets/config/v82_default/v82_default_scenario_components.xml" \
    "$TOOLDIR/configuration-sets/config/v82_default/v82_default_batch_2.xml"
```

Running without arguments selects these same defaults. `run-pipeline.sh`
synchronizes GCAM inputs and the prepared QUERY files into `gcam-scratch/`,
expands one configuration per scenario, writes
`run-tools/slurm-templates/generated-run.slurm`, and submits the RUN and
dependent merge jobs after confirmation.

## Step QUERY

Configure QUERY before starting `run-pipeline.sh`:

```sh
cd "$TOOLDIR/query-tools/batch_query_generator"
python3 build_queries.py query-config.yaml
```

The builder reads query definitions from `query-definitions/` and writes a
timestamped `queries-YYYYmmdd-HHMMSS.xml` file under `user_batch_queries/`.
Set the `<queryFile>` entry in `user_batch_queries/modelinterface-batch.xml`
to that file. Generated `queries-*.xml` files are local inputs and are not
tracked by Git.

During RUN, every scenario executes the same synchronized QUERY configuration.
After the Slurm run job returns successfully, `merge-query-results.sh` collects
the per-scenario CSV files and concatenates them into `Final_<jobid>.csv` under
`$SCRATCHDIR/output/run_<timestamp>/`.

## Repository and runtime layout

```text
gcam-hpc-PKU/
├── gcam-hpc-tools/
│   ├── build-tools/
│   │   ├── environment.sh
│   │   └── fetch-gcam-source.sh
│   ├── configuration-sets/
│   ├── query-tools/
│   │   ├── batch_query_generator/
│   │   └── user_batch_queries/
│   │       └── modelinterface-batch.xml
│   ├── run-tools/
│   └── run-pipeline.sh
├── gcam-runjob-log/
└── gcam-scratch/
    ├── input/
    └── output/
```

`gcam-runjob-log/` and `gcam-scratch/{input,output}/` are retained in Git with
`.gitkeep` files, while their runtime contents are ignored. Local regression
tests and generated `user_batch_queries/queries-*.xml` files are also excluded
from the published repository.
