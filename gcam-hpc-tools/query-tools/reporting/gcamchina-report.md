# GCAM-China reporting source

[Shared IAMC workflow](README.md) ·
[Wiki: environment and submission](https://github.com/jerrysong0128/gcam-hpc-PKU/wiki/gcamreport)

The upstream [rongqizhu/GCAM-China-reporting](https://github.com/rongqizhu/GCAM-China-reporting)
repository is a parallel submodule at `query-tools/gcamchina-report`.
Initialize it from the repository root:

```bash
git submodule update --init --recursive
```

Use the same `--postprocess gcamreport` command, `GCAMREPORT_SIF` and
`report-config.R` as for core. The adapter detects China from the selected
model directory name or database version. It reads the submodule's queries,
functions and mappings at runtime, and runs its `Reporting.R` calculations.
The submodule itself is not modified.

The current upstream final table is the national `China` report. Province
calculations are aggregated internally; the pipeline does not export province
rows. Variable coverage comes from the China reporting source. Selecting
another region or a variable in `report-config.R` filters the available
report; it does not create additional coverage.

The external adapter supplies the scenario/database, uses actual model periods
(including the 2021 calibration year in the tested China 8.2 database), and
writes `out_iamc_<index>/iamc.csv` with `Model=GCAM-China`. Undefined non-finite
capacity values become blank cells. The existing shell merge produces
`IAMC_Final_<merge-jobid>.csv` for both model variants.

The PKU wm2 China 8.2 SSP1 + SSP2 run exported 117 variables per scenario,
234 rows in the merged CSV, and 20 year columns from 2005 to 2100, including
2021. These are the tested batch's results; coverage for other databases is
subject to the upstream queries and calculations. Check model convergence
and blank capacity values before using the data.

The shared guide contains environment configuration, SIF preparation, the
four-line `events/1013` memo, output locations and recovery settings.
