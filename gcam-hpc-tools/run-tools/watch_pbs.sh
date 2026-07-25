#!/usr/bin/env bash
#
# Purpose: Preserve the former queue-monitor command name; new code should call
# monitor-jobs.sh.
# Author: Jingyang Song, Peking University; Jul 2026;

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/monitor-jobs.sh" "$@"
