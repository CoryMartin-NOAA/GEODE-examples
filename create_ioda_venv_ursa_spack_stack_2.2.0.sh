#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${ROOT}/ioda-venv-ursa-spack-stack-2.2.0"

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 /path/to/GEODE"
    exit 1
fi

GEODE_SOURCE_DIR="$(cd "$1" && pwd)"

if [[ ! -f "${GEODE_SOURCE_DIR}/pyproject.toml" ]]; then
    echo "ERROR: GEODE source directory does not contain pyproject.toml:"
    echo "  ${GEODE_SOURCE_DIR}"
    exit 1
fi

# Start with the Spack-stack Python, not an already activated venv.
if declare -F deactivate >/dev/null 2>&1; then
    deactivate
fi

module purge
module use /contrib/spack-stack/spack-stack-2.2.0/envs/ue-oneapi-2025.3.1/modules/Core

module load stack-intel-oneapi-compilers/2025.3.1
module load stack-intel-oneapi-mpi/2021.17
module load python/3.13.13

PYTHON="$(command -v python)"

echo "Using Python: ${PYTHON}"
"${PYTHON}" --version

if [[ -d "${VENV_DIR}" ]]; then
    echo "ERROR: Virtual environment already exists: ${VENV_DIR}" >&2
    echo "Remove it manually if you want to recreate it." >&2
    exit 1
fi

"${PYTHON}" -m venv "${VENV_DIR}"

VENV_PYTHON="${VENV_DIR}/bin/python"

"${VENV_PYTHON}" -m pip install setuptools

echo
echo "Installing GEODE from: ${GEODE_SOURCE_DIR}"
(
    cd "${GEODE_SOURCE_DIR}"
    "${VENV_PYTHON}" -m pip install --no-build-isolation -e ".[dev]"
)

echo
echo "Installing Icechunk (synthetic test data generation only)..."
"${VENV_PYTHON}" -m pip install icechunk

echo
echo "Verifying Python dependencies..."
"${VENV_PYTHON}" -c '
import geode
import icechunk
print(f"GEODE: {geode.__file__}")
print(f"Icechunk: {icechunk.__version__}")
'

echo
echo "Virtual environment created: ${VENV_DIR}"
echo "Activate it with:"
echo "  source '${VENV_DIR}/bin/activate'"
