#!/usr/bin/env bash
#
# Purpose: Preserve the former scenario runner path used by older compiled
# task wrappers; new code should call run-scenario.sh.
# Author: Jingyang Song, Peking University; Jul 2026;

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/run-scenario.sh" "$@"
