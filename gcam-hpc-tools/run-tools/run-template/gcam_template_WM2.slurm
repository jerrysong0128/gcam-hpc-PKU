#!/bin/bash 

#!/bin/bash
#SBATCH -o GCAMRUN.%j.out
#SBATCH --partition=C064M0256G
#SBATCH --qos=low
#SBATCH -J GCAMRUN
#SBATCH --nodes=1
#SBATCH --ntasks=NUM_TASKS
#SBATCH --time=2-00:00:00

export OMP_NUM_THREADS=1



