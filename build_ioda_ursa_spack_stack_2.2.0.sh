#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SOURCE_DIR="${IODA_SOURCE_DIR:-${ROOT}/ioda-internal}"
BUILD_DIR="${IODA_BUILD_DIR:-${ROOT}/ioda-internal-build}"
INSTALL_DIR="${IODA_INSTALL_DIR:-${ROOT}/ioda-internal-install}"

BUILD_TYPE="Release"
BUILD_JOBS="${BUILD_JOBS:-4}"

DO_INSTALL=0

if [[ "${1:-}" == "--install" ]]; then
    DO_INSTALL=1
elif [[ $# -gt 0 ]]; then
    echo "Usage: $0 [--install]"
    exit 1
fi

# Load modules and activate the Python environment.
source "${ROOT}/setup_ioda_env_ursa_spack_stack_2.2.0.sh"

PYTHON="${VIRTUAL_ENV}/bin/python"

# Determine pybind11 CMake location.
PYBIND11_DIR="$("${PYTHON}" -c 'import pybind11; print(pybind11.get_cmake_dir())')"

# Required dependency paths from the loaded modules.
: "${oops_ROOT:?oops_ROOT is not set}"
: "${jedi_cmake_ROOT:?jedi_cmake_ROOT is not set}"
: "${fckit_ROOT:?fckit_ROOT is not set}"
: "${eckit_ROOT:?eckit_ROOT is not set}"
: "${hdf5_ROOT:?hdf5_ROOT is not set}"
: "${netcdf_c_ROOT:?netcdf_c_ROOT is not set}"
: "${netcdf_cxx4_ROOT:?netcdf_cxx4_ROOT is not set}"

# Configure IODA.
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

# Configure IODA.
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

ecbuild \
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
    -DCMAKE_PREFIX_PATH="${oops_ROOT};${jedi_cmake_ROOT};${fckit_ROOT};${eckit_ROOT};${hdf5_ROOT};${netcdf_c_ROOT};${netcdf_cxx4_ROOT}" \
    -DIODA_BUILD_GEODE=ON \
    -DBUILD_PYTHON_BINDINGS=ON \
    -DPython3_EXECUTABLE="${PYTHON}" \
    -Dpybind11_DIR="${PYBIND11_DIR}" \
    "${SOURCE_DIR}"

# Build the GEODE reader tests.
cmake --build "${BUILD_DIR}" \
    --target ioda_reader_geode ioda_reader_geode_synthetic \
    --parallel "${BUILD_JOBS}"

echo
echo "Build completed successfully."
echo "Build directory: ${BUILD_DIR}"

if [[ "${DO_INSTALL}" == "1" ]]; then
    echo
    echo "Installing IODA C++ libraries and headers..."

    cmake \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
        -DCMAKE_INSTALL_CONFIG_NAME="${BUILD_TYPE}" \
        -P "${BUILD_DIR}/src/cmake_install.cmake"

    echo "Installation completed: ${INSTALL_DIR}"
fi
