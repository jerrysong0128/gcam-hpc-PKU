#!/usr/bin/env bash
#
# Purpose: Preserve the former query merge job name; new code should call
# merge-query-results.sh.
# Author: Jingyang Song, Peking University; Jul 2026;

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/merge-query-results.sh" "$@"
