# wm2.profile -- WEIMING-2 cluster
# Sourced by environment.sh. Do not source directly.
# Provides build env (compiler, BOOST/JAVA/TBB/EIGEN, JARS) and SLURM_TEMPLATE.

module load gcc/12.2.0
export CXX=g++

_GCAM_LIBS="${TOOLDIR}/build-tools/libs"

export BOOST_INCLUDE="${_GCAM_LIBS}/boost-lib"
export BOOST_LIB="${_GCAM_LIBS}/boost-lib/lib"

export JAVA_HOME="${_GCAM_LIBS}/java_linux"
export JAVA_INCLUDE="${JAVA_HOME}/include"
export JAVA_LIB="${JAVA_HOME}/lib/server"
export JARS_LIB="${_GCAM_LIBS}/jars/*"

export EIGEN_INCLUDE="${_GCAM_LIBS}/eigen"

export TBB_INCLUDE="${_GCAM_LIBS}/tbb-linux/include"
export TBB_LIB="${_GCAM_LIBS}/tbb-linux/lib/intel64/gcc4.8"

export SLURM_TEMPLATE="${TOOLDIR}/run-tools/slurm-templates/wm2-run-template.slurm"

unset _GCAM_LIBS
