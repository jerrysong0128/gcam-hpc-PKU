#!/usr/bin/env bash
#
# Purpose: Download and extract a tagged gcam-core or gcam-china source release.
# Author: Jingyang Song, Peking University; Jul 2026;
#
# Both gcam-core (JGCRI/gcam-core) and gcam-china (umd-cgs/gcam-china) are
# fetched the same way: pull the source-code archive for a given release tag
# from GitHub and unpack it under the workspace. Extracted directory names
# match the gcam-*/cvs/objects/build/linux pattern that environment.sh
# auto-detects.
#
# Usage:
#   ./fetch-gcam-source.sh --variant core  --version gcam-v8.2
#   ./fetch-gcam-source.sh --variant china --version gcam-china-v8
#   ./fetch-gcam-source.sh -v china -t gcam-china-v7.1 --dest /workspace
#
# Releases (use the exact 'tag_name' shown on the release page):
#   gcam-core   https://github.com/JGCRI/gcam-core/releases
#   gcam-china  https://github.com/umd-cgs/gcam-china/releases

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: fetch-gcam-source.sh --variant {core|china} --version TAG [options]

Required:
  -v, --variant {core|china}   Which GCAM variant to fetch.
  -t, --version TAG            Release tag exactly as on GitHub (use the
                               'tag_name' from the release page).
                               Examples: 'gcam-v8.2', 'gcam-china-v8',
                                         'gcam-china-v7.1'.

Options:
  -d, --dest DIR     Workspace root to extract into.
                     Defaults to $GCAM_HPC_WORKSPACE, else the parent of
                     this script's directory.
  -f, --force        Re-download and overwrite an existing extraction.
  -h, --help         Show this help.

Examples:
  fetch-gcam-source.sh --variant core  --version gcam-v8.2
  fetch-gcam-source.sh --variant china --version gcam-china-v8
EOF
}

variant=""
version=""
dest=""
force=0

while [ $# -gt 0 ]; do
    case "$1" in
        -v|--variant) variant="${2:-}"; shift 2 ;;
        -t|--version) version="${2:-}"; shift 2 ;;
        -d|--dest)    dest="${2:-}"; shift 2 ;;
        -f|--force)   force=1; shift ;;
        -h|--help)    usage; exit 0 ;;
        --) shift; break ;;
        *) echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

if [ -z "$variant" ] || [ -z "$version" ]; then
    echo "ERROR: --variant and --version are required" >&2
    usage >&2
    exit 2
fi

case "$variant" in
    core)  repo="JGCRI/gcam-core" ;;
    china) repo="umd-cgs/gcam-china" ;;
    *) echo "ERROR: --variant must be 'core' or 'china' (got '$variant')" >&2; exit 2 ;;
esac

if [ -z "$dest" ]; then
    if [ -n "${GCAM_HPC_WORKSPACE:-}" ]; then
        dest="$GCAM_HPC_WORKSPACE"
    else
        script_dir="$(cd "$(dirname "$0")" && pwd)"
        dest="$(cd "$script_dir/.." && pwd)"
    fi
fi

if [ ! -d "$dest" ]; then
    echo "ERROR: destination is not a directory: $dest" >&2
    exit 1
fi

repo_name="$(basename "$repo")"
# Pick a target dir name that is self-describing and matches the
# gcam-*/cvs/objects/build/linux pattern auto-detected by
# environment.sh. We avoid duplicate prefixes when the upstream tag
# already encodes the variant (e.g. 'gcam-china-v8').
case "$version" in
    gcam-core-*|gcam-china-*) target_name="$version" ;;
    gcam-*)                   target_name="${repo_name}-${version#gcam-}" ;;
    *)                        target_name="${repo_name}-${version}" ;;
esac
target_dir="$dest/$target_name"
url="https://github.com/${repo}/archive/refs/tags/${version}.tar.gz"

log() { printf '[fetch_gcam_source] %s\n' "$*"; }

if [ -d "$target_dir" ] && [ "$force" -eq 0 ]; then
    log "Already present: $target_dir"
    log "Use --force to re-download."
    exit 0
fi

if [ "$force" -eq 1 ] && [ -d "$target_dir" ]; then
    log "Removing existing $target_dir"
    rm -rf "$target_dir"
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

archive="$tmpdir/source.tar.gz"
log "Fetching $url"
if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 3 --retry-delay 5 -o "$archive" "$url"
elif command -v wget >/dev/null 2>&1; then
    wget -O "$archive" "$url"
else
    echo "ERROR: need curl or wget on PATH to download release archive" >&2
    exit 1
fi

extracted_top="$(tar -tzf "$archive" | head -1 | awk -F/ '{print $1}')"
if [ -z "$extracted_top" ]; then
    echo "ERROR: archive appears empty: $archive" >&2
    exit 1
fi

if [ -e "$dest/$extracted_top" ] && [ "$extracted_top" != "$target_name" ]; then
    log "WARNING: $dest/$extracted_top already exists; aborting to avoid overwrite."
    exit 1
fi

log "Extracting into $dest"
tar -xzf "$archive" -C "$dest"

if [ "$extracted_top" != "$target_name" ]; then
    log "Renaming $extracted_top -> $target_name"
    mv "$dest/$extracted_top" "$target_dir"
fi

if [ -d "$target_dir/cvs/objects/build/linux" ]; then
    log "Done. GCAM source ready at: $target_dir"
else
    echo "[fetch_gcam_source] WARNING: extracted, but cvs/objects/build/linux not found under $target_dir" >&2
    echo "                    The release layout may have changed." >&2
fi
