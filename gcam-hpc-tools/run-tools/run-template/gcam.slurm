#!/bin/bash 

#!/bin/bash
#SBATCH -o GCAMRUN.%j.out
#SBATCH -p C064M0256G
#SBATCH --qos=low
#SBATCH -J GCAMRUN
#SBATCH --nodes=1
#SBATCH --ntasks=4

export OMP_NUM_THREADS=1




   srun ./gcam-hpc-PKU/gcam-hpc-tools/run-tools/mpi_wrapper.exe ./gcam-hpc-PKU/gcam-hpc-tools/configuration-sets/configuration_empty_scenario_components 0

