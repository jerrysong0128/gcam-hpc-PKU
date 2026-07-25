# Purpose: Provide a fail-fast template for configuring a non-PKU cluster.
# Author: Jingyang Song, Peking University; Jul 2026;
#
# custom.profile -- template for non-PKU clusters
# Copy this file to <yoursite>.profile and fill in the values, then set
# GCAM_HPC_CLUSTER=<yoursite> in environment.sh.
#
# Each ${VAR:?...} below fails fast with a clear message if you forget one.

# --- Modules / compiler ---------------------------------------------------
# Example: module load gcc/12 boost openjdk tbb
# export CXX=g++

: "${CXX:?set CXX in your profile (e.g. g++ or /path/to/g++)}"

# --- Boost ----------------------------------------------------------------
: "${BOOST_INCLUDE:?set BOOST_INCLUDE to the directory containing boost/ headers}"
: "${BOOST_LIB:?set BOOST_LIB to the directory containing libboost_*.so}"

# --- Java + Jars ----------------------------------------------------------
: "${JAVA_HOME:?set JAVA_HOME (must contain include/jni.h and a server libjvm)}"
export JAVA_INCLUDE="${JAVA_INCLUDE:-${JAVA_HOME}/include}"
export JAVA_LIB="${JAVA_LIB:-${JAVA_HOME}/lib/server}"
export JARS_LIB="${JARS_LIB:-${TOOLDIR}/build-tools/libs/jars/*}"

# --- Eigen ----------------------------------------------------------------
export EIGEN_INCLUDE="${EIGEN_INCLUDE:-${TOOLDIR}/build-tools/libs/eigen}"

# --- TBB ------------------------------------------------------------------
: "${TBB_INCLUDE:?set TBB_INCLUDE to the directory containing tbb/ headers}"
: "${TBB_LIB:?set TBB_LIB to the directory containing libtbb.so}"

# --- Slurm template -------------------------------------------------------
# Copy run-tools/slurm-templates/wm2-run-template.slurm to a site-specific one
# (different partition, time limit, modules) and point SLURM_TEMPLATE at it.
: "${SLURM_TEMPLATE:?set SLURM_TEMPLATE to a slurm template file (see run-tools/run-template/)}"
