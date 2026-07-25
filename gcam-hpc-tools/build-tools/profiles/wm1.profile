# wm1.profile -- WEIMING-1 cluster
# Sourced by environment.sh. Do not source directly.
# Uses PKU HPC system-installed software (boost/java/tbb/gcc); these absolute
# paths are cluster admin config, not user data.

export CXX=/gpfs/share/software/gcc/10.4.0/bin/g++

export BOOST_INCLUDE=/gpfs/share/software/boost/1.83.0/gcc_10.4.0/include
export BOOST_LIB=/gpfs/share/software/boost/1.83.0/gcc_10.4.0/lib

export JAVA_HOME=/gpfs/share/software/java/1.8.0
export JAVA_INCLUDE="${JAVA_HOME}/include"
export JAVA_LIB="${JAVA_HOME}/jre/lib/amd64/server"
export JARS_LIB="${TOOLDIR}/build-tools/libs/jars/*"

export EIGEN_INCLUDE="${TOOLDIR}/build-tools/libs/eigen"

export TBB_INCLUDE=/gpfs/share/software/oneapi_hpc/2023.1/tbb/2021.9.0/include
export TBB_LIB=/gpfs/share/software/oneapi_hpc/2023.1/tbb/2021.9.0/lib/intel64/gcc4.8

export SLURM_TEMPLATE="${TOOLDIR}/run-tools/slurm-templates/wm1-run-template.slurm"
