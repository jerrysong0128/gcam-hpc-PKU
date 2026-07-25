#!/usr/bin/env bash
#
# Purpose: Store the generated Slurm RUN job produced from the active cluster
# template; run-pipeline.sh rewrites this file for each submission.
# Author: Jingyang Song, Peking University; Jul 2026;
#
#SBATCH --output=gcam-runjob-log/gcamRunjob.%j.out
#SBATCH --partition=C064M0256G   # Use the valid partition on your cluster (MUST BE UPPERCASE) sacctmgr show ass user=`whoami` format=part | uniq
#SBATCH --job-name=gcamRun
#SBATCH --nodes=10
#SBATCH --ntasks=10
#SBATCH --cpus-per-task=8
#SBATCH --time=2-00:00:00

module purge
module load intel_parallel_studio/2019.1
module load mpi/2021.8.0   # Instead of 2021.3.0 which isn't available

export OMP_NUM_THREADS=1
ulimit -s unlimited
srun -n 1 ./gcam-hpc-tools/run-tools/run-task-wrapper.exe /lustre/home/2501112459/Desktop/GCAM_Workspace/gcam-hpc-PKU/gcam-hpc-tools/configuration-sets/temp/v82_default_scenario_components 0 &
srun -n 1 ./gcam-hpc-tools/run-tools/run-task-wrapper.exe /lustre/home/2501112459/Desktop/GCAM_Workspace/gcam-hpc-PKU/gcam-hpc-tools/configuration-sets/temp/v82_default_scenario_components 1 &
srun -n 1 ./gcam-hpc-tools/run-tools/run-task-wrapper.exe /lustre/home/2501112459/Desktop/GCAM_Workspace/gcam-hpc-PKU/gcam-hpc-tools/configuration-sets/temp/v82_default_scenario_components 2 &
srun -n 1 ./gcam-hpc-tools/run-tools/run-task-wrapper.exe /lustre/home/2501112459/Desktop/GCAM_Workspace/gcam-hpc-PKU/gcam-hpc-tools/configuration-sets/temp/v82_default_scenario_components 3 &
srun -n 1 ./gcam-hpc-tools/run-tools/run-task-wrapper.exe /lustre/home/2501112459/Desktop/GCAM_Workspace/gcam-hpc-PKU/gcam-hpc-tools/configuration-sets/temp/v82_default_scenario_components 4 &
srun -n 1 ./gcam-hpc-tools/run-tools/run-task-wrapper.exe /lustre/home/2501112459/Desktop/GCAM_Workspace/gcam-hpc-PKU/gcam-hpc-tools/configuration-sets/temp/v82_default_scenario_components 5 &
srun -n 1 ./gcam-hpc-tools/run-tools/run-task-wrapper.exe /lustre/home/2501112459/Desktop/GCAM_Workspace/gcam-hpc-PKU/gcam-hpc-tools/configuration-sets/temp/v82_default_scenario_components 6 &
srun -n 1 ./gcam-hpc-tools/run-tools/run-task-wrapper.exe /lustre/home/2501112459/Desktop/GCAM_Workspace/gcam-hpc-PKU/gcam-hpc-tools/configuration-sets/temp/v82_default_scenario_components 7 &
srun -n 1 ./gcam-hpc-tools/run-tools/run-task-wrapper.exe /lustre/home/2501112459/Desktop/GCAM_Workspace/gcam-hpc-PKU/gcam-hpc-tools/configuration-sets/temp/v82_default_scenario_components 8 &
srun -n 1 ./gcam-hpc-tools/run-tools/run-task-wrapper.exe /lustre/home/2501112459/Desktop/GCAM_Workspace/gcam-hpc-PKU/gcam-hpc-tools/configuration-sets/temp/v82_default_scenario_components 9 &
wait
