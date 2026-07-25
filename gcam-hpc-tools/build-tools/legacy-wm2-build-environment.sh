#!/usr/bin/env bash
#
# Purpose: Configure the legacy WEIMING-2 repository-local build environment.
# Author: Jingyang Song, Peking University; Jul 2026;
#
# Prefer build-environment.sh for new workflows. This file remains available
# for users who still depend on the original WM2 layout.

# === Set GCAM_WORKSPACE ===
if [ -z "$GCAM_WORKSPACE" ]; then
    echo "NOTICE: Please set GCAM_WORKSPACE to the absolute path of your gcam-hpc-PKU repo"
    echo "Example: export GCAM_WORKSPACE=/path/to/your/gcam-workspace/gcam-hpc-PKU/"
    return 1
fi

# === GCAM Paths ===
export GCAM_INCLUDE=$GCAM_WORKSPACE/gcam-core/cvs/objects
export GCAM_LIB=$GCAM_WORKSPACE/gcam-core/cvs/objects/build/linux

# === Boost Paths ===
export BOOST_INCLUDE=$GCAM_WORKSPACE/gcam-hpc-tools/build-tools/libs/boost-lib
export BOOST_LIB=$GCAM_WORKSPACE/gcam-hpc-tools/build-tools/libs/boost-lib/lib

# === Java Paths ===
export JAVA_HOME=$GCAM_WORKSPACE/gcam-hpc-tools/build-tools/libs/java_linux
export JAVA_INCLUDE=$JAVA_HOME/include
export JAVA_LIB=$JAVA_HOME/lib/server
export JARS_LIB=$GCAM_WORKSPACE/gcam-hpc-tools/build-tools/libs/jars/*

# === Eigen Path ===
export EIGEN_INCLUDE=$GCAM_WORKSPACE/gcam-hpc-tools/build-tools/libs/eigen

# === TBB Paths ===
export TBB_INCLUDE=$GCAM_WORKSPACE/gcam-hpc-tools/build-tools/libs/tbb-linux/include
export TBB_LIB=$GCAM_WORKSPACE/gcam-hpc-tools/build-tools/libs/tbb-linux/lib/intel64/gcc4.8

# === Compiler ===
module load gcc/12.2.0
export CXX=g++
