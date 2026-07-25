#!/usr/bin/env bash
#
# Purpose: Preserve the former source-download command name; new code should
# call fetch-gcam-source.sh.
# Author: Jingyang Song, Peking University; Jul 2026;

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/fetch-gcam-source.sh" "$@"
