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

check_source_headers() {
    local file
    while IFS= read -r file; do
        head -n 15 "${file}" | grep -q 'Purpose:'
        head -n 15 "${file}" | grep -q 'Author: Jingyang Song, Peking University; Jul 2026;'
    done < <(
        find "${TOOLS_DIR}" -type f \
            \( -name '*.sh' -o -name '*.setup' -o -name '*.profile' \
               -o -name '*.slurm' -o -name '*.pl' -o -name '*.cpp' -o -name '*.py' \) \
            ! -path '*/build-tools/lib/*' \
            | sort
    )

    grep -q 'Author: Jingyang Song, Peking University; Jul 2026;' \
        "${TOOLS_DIR}/query-tools/batch_query_generator/query-config.yaml"
    grep -q 'Jingyang Song, Peking University; Jul 2026;' \
        "${TOOLS_DIR}/query-tools/batch_query_generator/interactive-query-builder.ipynb"
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
    local query_catalog="${TOOLS_DIR}/query-tools/batch_query_generator/query-definitions/main-queries.xml"

    {
        printf 'selected_regions:\n  - China\n'
        printf 'selected_queries:\n  - iron and steel production by region\n'
        printf 'output_file: %s\n' "${output}"
        printf 'query_files:\n  - %s\n' "${query_catalog}"
        printf 'available_regions:\n  - China\n'
    } > "${config}"

    python3 "${TOOLS_DIR}/query-tools/batch_query_generator/build_queries.py" "${config}"
    python3 -c '
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
assert root.tag == "queries"
assert len(root.findall("aQuery")) == 1
assert root.find("aQuery/region").get("name") == "China"
' "${output}"

    # The former CLI name remains a supported compatibility entry point.
    python3 "${TOOLS_DIR}/query-tools/batch_query_generator/batch_query_generator.py" "${config}" >/dev/null
}

check_modelinterface_batch() {
    local batch_dir="${TOOLS_DIR}/query-tools/batch-queries"
    python3 -c '
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

batch_dir = Path(sys.argv[1])
root = ET.parse(batch_dir / "modelinterface-batch.xml").getroot()
query_file = root.findtext(".//queryFile")
assert query_file
assert (batch_dir / Path(query_file).name).is_file()
' "${batch_dir}"
}

check_run_pipeline_integration() {
    local workspace="${TEST_TMP}/pipeline-workspace"
    local test_tools="${workspace}/gcam-hpc-tools"
    local test_bin="${workspace}/test-bin"

    # Assemble only the files needed to exercise orchestration through Slurm
    # generation; the real 400+ MB dependency bundle is intentionally omitted.
    mkdir -p "${test_tools}/build-tools" "${test_bin}"
    cp "${TOOLS_DIR}/run-pipeline.sh" "${TOOLS_DIR}/environment.sh" "${test_tools}/"
    cp -R "${TOOLS_DIR}/run-tools" "${TOOLS_DIR}/configuration-sets" "${test_tools}/"
    cp -R "${TOOLS_DIR}/build-tools/profiles" "${test_tools}/build-tools/"
    mkdir -p "${test_tools}/query-tools"
    cp -R "${TOOLS_DIR}/query-tools/batch-queries" "${test_tools}/query-tools/"

    mkdir -p \
        "${workspace}/gcam-core/cvs/objects/build/linux" \
        "${workspace}/gcam-core/input" \
        "${workspace}/gcam-core/output/queries" \
        "${workspace}/gcam-core/exe" \
        "${workspace}/gcam-scratch"

    # Cluster profile files call the environment-modules command. A no-op stub
    # is sufficient because this integration test never launches GCAM.
    printf '#!/usr/bin/env bash\nexit 0\n' > "${test_bin}/module"
    chmod +x "${test_bin}/module"

    printf 'y\ny\n2\nn\n' |
        PATH="${test_bin}:${PATH}" \
        GCAM_HPC_WORKSPACE="${workspace}" \
        GCAM_HPC_CLUSTER=wm2 \
        bash "${test_tools}/run-pipeline.sh"

    local generated="${test_tools}/run-tools/slurm-templates/generated-run.slurm"
    test -f "${generated}"
    test "$(grep -c 'run-task-wrapper.exe' "${generated}")" = "2"
    grep -q 'run-tools/run-task-wrapper.exe' "${generated}"
    test -f "${workspace}/gcam-scratch/output/xmldb_queries/modelinterface-batch.xml"
}

check_pipeline_references() {
    grep -q 'run-tools/run-scenario.sh' "${TOOLS_DIR}/run-tools/run-task-wrapper.cpp"
    grep -q 'run-tools/generate-scenarios.sh' "${TOOLS_DIR}/run-pipeline.sh"
    grep -q 'run-tools/merge-query-results.sh' "${TOOLS_DIR}/run-pipeline.sh"
    grep -q 'batch-queries' "${TOOLS_DIR}/run-pipeline.sh"
    grep -q 'modelinterface-batch.xml' "${TOOLS_DIR}/run-tools/run-scenario.sh"

    # Published legacy paths remain resolvable while canonical code uses the
    # standardized names.
    test -x "${TOOLS_DIR}/master.sh"
    test -x "${TOOLS_DIR}/run-tools/run_model.sh"
    test -L "${TOOLS_DIR}/run-tools/mpi_wrapper.exe"
    test -L "${TOOLS_DIR}/run-tools/run-template"
    test -L "${TOOLS_DIR}/run-tools/SPA_mapping"
    test -L "${TOOLS_DIR}/query-tools/user_batch_queries"
}

check_shell_syntax
check_python_syntax
check_source_headers
check_perl_syntax
check_scenario_generation
check_query_generation
check_modelinterface_batch
check_run_pipeline_integration
check_pipeline_references

printf 'All GCAM-HPC regression checks passed.\n'
