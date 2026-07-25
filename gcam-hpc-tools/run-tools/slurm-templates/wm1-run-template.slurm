#!/bin/bash

#SBATCH --output=gcam-runjob-log/gcamRunjob.%j.out
#SBATCH --partition=C032M0128G     # Use the valid partition on your cluster (MUST BE UPPERCASE)
#SBATCH --job-name=gcamRun         # Set your job name
#SBATCH --nodes=NUM_TASKS
#SBATCH --ntasks-per-node=8
#SBATCH --time=10:00:00

module purge
module load intel/2019.1
module load mpi/2021.3.0  # From available Intel oneAPI MPI versions

export OMP_NUM_THREADS=1
ulimit -s unlimited

