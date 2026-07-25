#!/usr/bin/env bash
#
# Purpose: Poll the current user's Slurm queue while a GCAM-HPC run is active.
# Author: Jingyang Song, Peking University; Jul 2026;

# Keep the monitor simple so it works on login nodes without extra packages.
echo
echo "Press CTRL-C to stop this listing..."


while true; do
	squeue -u "${GCAM_HPC_USER:-$(whoami)}"
	sleep 30
done
