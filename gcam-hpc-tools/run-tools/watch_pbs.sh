#!/bin/bash

echo
echo "Press CTRL-C to stop this listing..."


while [ 1 ]; do
	squeue -u 2501112459
	sleep 30
done

