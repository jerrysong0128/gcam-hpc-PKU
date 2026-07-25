#!/usr/bin/env bash
#
# Purpose: Preserve the former RUN entry-point name; new code should call
# run-pipeline.sh directly.
# Author: Jingyang Song, Peking University; Jul 2026;

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/run-pipeline.sh" "$@"
