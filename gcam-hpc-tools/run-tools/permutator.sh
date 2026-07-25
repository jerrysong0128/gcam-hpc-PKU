#!/usr/bin/env bash
#
# Purpose: Preserve the former scenario generator name; new code should call
# generate-scenarios.sh.
# Author: Jingyang Song, Peking University; Jul 2026;

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/generate-scenarios.sh" "$@"
