#!/usr/bin/env bash
#
# Purpose: Run fast, cluster-independent regression checks for the GCAM-HPC
# RUN and QUERY pipelines before and after refactoring.
# Author: Jingyang Song, Peking University; Jul 2026;

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="${REPO_ROOT}/gcam-hpc-tools"
TEST_TMP="$(mktemp -d)"
trap 'rm -rf "${TEST_TMP}"' EXIT

check_shell_syntax() {
    local file
    while IFS= read -r file; do
        bash -n "${file}"
    done < <(
        find "${TOOLS_DIR}" -type f \
            \( -name '*.sh' -o -name '*.setup' -o -name '*.profile' -o -name '*.slurm' \) \
            ! -path '*/build-tools/lib/*' \
            | sort
    )
}

check_python_syntax() {
    python3 -c '
from pathlib import Path
import sys

root = Path(sys.argv[1])
files = sorted(root.rglob("*.py"))
for path in files:
    compile(path.read_text(encoding="utf-8"), str(path), "exec")
print(f"Python syntax OK: {len(files)} files")
' "${TOOLS_DIR}/query-tools"
}

check_perl_syntax() {
    perl -c "${TOOLS_DIR}/run-tools/parse-scenario-batch.pl"
}

check_scenario_generation() {
    local fixture_dir="${TEST_TMP}/scenario-generation"
    mkdir -p "${fixture_dir}"
    cp "${TOOLS_DIR}/configuration-sets/config/v82_default/v82_default_scenario_components.xml" \
        "${fixture_dir}/template.xml"
    cp "${TOOLS_DIR}/configuration-sets/config/v82_default/v82_default_batch_2.xml" \
        "${fixture_dir}/batch.xml"

    # The bundled batch fixture contains one base set and two policy choices.
    printf 'y\n' |
        TOOLDIR="${TOOLS_DIR}" bash "${TOOLS_DIR}/run-tools/generate-scenarios.sh" \
            "${fixture_dir}/template.xml" "${fixture_dir}/batch.xml"

    local count
    count="$(find "${fixture_dir}" -maxdepth 1 -name 'template_[0-9]*.xml' | wc -l | tr -d ' ')"
    test "${count}" = "2"
    grep -q 'scenarioName' "${fixture_dir}/template_0.xml"
    grep -q 'scenarioName' "${fixture_dir}/template_1.xml"
}

check_query_generation() {
    local config="${TEST_TMP}/query-test.yaml"
    local output="${TEST_TMP}/query-output.xml"
    local query_catalog="${TOOLS_DIR}/query-tools/batch_query_generator/queries_xml/Main_queries.xml"

    {
        printf 'selected_regions:\n  - China\n'
        printf 'selected_queries:\n  - iron and steel production by region\n'
        printf 'output_file: %s\n' "${output}"
        printf 'query_files:\n  - %s\n' "${query_catalog}"
        printf 'available_regions:\n  - China\n'
    } > "${config}"

    python3 "${TOOLS_DIR}/query-tools/batch_query_generator/batch_query_generator.py" "${config}"
    python3 -c '
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
assert root.tag == "queries"
assert len(root.findall("aQuery")) == 1
assert root.find("aQuery/region").get("name") == "China"
' "${output}"
}

check_pipeline_references() {
    grep -q 'run-tools/run-scenario.sh' "${TOOLS_DIR}/run-tools/run-task-wrapper.cpp"
    grep -q 'run-tools/generate-scenarios.sh' "${TOOLS_DIR}/run-pipeline.sh"
    grep -q 'run-tools/merge-query-results.sh' "${TOOLS_DIR}/run-pipeline.sh"
    grep -q 'user_batch_queries' "${TOOLS_DIR}/run-pipeline.sh"
    grep -q 'xmldb_batch.xml' "${TOOLS_DIR}/run-tools/run-scenario.sh"
}

check_shell_syntax
check_python_syntax
check_perl_syntax
check_scenario_generation
check_query_generation
check_pipeline_references

printf 'All GCAM-HPC regression checks passed.\n'
