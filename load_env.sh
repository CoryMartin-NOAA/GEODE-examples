# Source this file to load the GDASApp + GEODE venv environment:
#   source load_env.sh
# Mirrors the "Environment" section of submit_fv3jedi_hofx_atms.sh.

BENCH=${BENCH:-/scratch4/NCEPDEV/stmp/Cory.R.Martin/oct2026/ioda_benchmark}
GDASAPP=${GDASAPP:-${BENCH}/gdasapp}
MODULEFILE_DIR=${MODULEFILE_DIR:-${GDASAPP}/modulefiles}
MODULE=${MODULE:-GDAS/ursa.intel}
GEODE_VENV=${GEODE_VENV:-/scratch4/NCEPDEV/stmp/Cory.R.Martin/oct2026/geode-venv}

module purge
module use "${MODULEFILE_DIR}"
module load "${MODULE}"

# need to load venv
module load rdhpcs-python/3.13
source "${GEODE_VENV}/bin/activate"

# Make sure the build's libraries are found at runtime
export LD_LIBRARY_PATH=${GDASAPP}/build/lib:${LD_LIBRARY_PATH:-}
export OMP_NUM_THREADS=1
