#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${ROOT}/ioda-venv-ursa-spack-stack-2.2.0"

# Start from a clean module environment.
if declare -F deactivate >/dev/null 2>&1; then
    deactivate
fi

module purge
module use /contrib/spack-stack/spack-stack-2.2.0/envs/ue-oneapi-2025.3.1/modules/Core

# Intel oneAPI compiler and MPI stack.
module load stack-intel-oneapi-compilers/2025.3.1
module load stack-intel-oneapi-mpi/2021.17

# NetCDF/HDF5 modules from Spack-stack.
STACK_NETCDF_DIR=/contrib/spack-stack/spack-stack-2.2.0/envs/ue-oneapi-2025.3.1/modules/intel-oneapi-mpi/2021.17/intel-oneapi-compilers/2025.3.1
module use "${STACK_NETCDF_DIR}"

module load hdf5/2.1.0
module load netcdf-c/4.9.2
module load netcdf-cxx4/4.3.1

# JEDI and build dependencies.
module load python/3.13.13
module load jedi-cmake/1.4.0
module load fckit/0.14.3
module load eckit/2.0.7
module load oops/1.13.0.20260914
module load py-pybind11/2.13.6
module load ecbuild/3.15.2

# Additional IODA configuration/test dependencies.
module load gsl-lite/0.41.0
module load udunits
module load nccmp

# Activate the project's Python environment.
if [[ ! -f "${VENV_DIR}/bin/activate" ]]; then
    echo "ERROR: Python virtual environment not found: ${VENV_DIR}" >&2
    return 1 2>/dev/null || exit 1
fi

source "${VENV_DIR}/bin/activate"

# Verify Python version and pybind11 availability.
python -c '
import sys
import pybind11

if sys.version_info[:2] != (3, 13):
    raise SystemExit(f"Expected Python 3.13, got {sys.version}")

print(f"Python environment ready: {sys.executable}")
print(f"pybind11 version: {pybind11.__version__}")
print(f"pybind11 CMake directory: {pybind11.get_cmake_dir()}")
'
