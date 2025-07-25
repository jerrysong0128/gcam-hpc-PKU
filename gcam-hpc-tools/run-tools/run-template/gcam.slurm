#!/bin/bash 

#!/bin/bash
#SBATCH --output=gcam-runjob-log/gcamRunjob.%j.out
#SBATCH --partition=C064M0256G   # Use the valid partition on your cluster (MUST BE UPPERCASE) sacctmgr show ass user=`whoami` format=part | uniq
#SBATCH --job-name=gcamRun
#SBATCH --nodes=2
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=8
#SBATCH --time=2-00:00:00

module purge
module load intel_parallel_studio/2019.1
module load mpi/2021.8.0   # Instead of 2021.3.0 which isn't available

export OMP_NUM_THREADS=1
ulimit -s unlimited
srun -n 1 ./gcam-hpc-tools/run-tools/mpi_wrapper.exe ./gcam-hpc-tools/configuration-sets/configuration_empty_scenario_components 0 &
srun -n 1 ./gcam-hpc-tools/run-tools/mpi_wrapper.exe ./gcam-hpc-tools/configuration-sets/configuration_empty_scenario_components 1 &
wait
