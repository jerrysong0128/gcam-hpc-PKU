#!/bin/bash

echo
echo "Press CTRL-C to stop this listing..."


while [ 1 ]; do
	squeue -u "${GCAM_HPC_USER:-$(whoami)}"
	sleep 30
done

