#!/usr/bin/env bash
#
# Purpose: Load the unified GCAM-HPC environment for source compilation.
# Author: Jingyang Song, Peking University; Jul 2026;
#
# Delegates to environment.sh so the build documentation keeps the familiar
# "source build-tools/build-environment.sh; make gcam -j 16" flow while
# everything stays centralized in one file.
#
# Usage:
#     source build-tools/build-environment.sh
#     cd $GCAM_LIB && make clean && make gcam -j 16

_GCAM_BUILD_SETUP_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "${_GCAM_BUILD_SETUP_DIR}/../environment.sh"
unset _GCAM_BUILD_SETUP_DIR
