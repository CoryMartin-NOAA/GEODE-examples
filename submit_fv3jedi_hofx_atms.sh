#!/bin/bash
#SBATCH --job-name=fv3jedi_hofx_atms
#SBATCH --account=da-cpu
#SBATCH --qos=batch
#SBATCH --nodes=8
#SBATCH --ntasks=96
#SBATCH --ntasks-per-node=12
#SBATCH --time=00:30:00
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --output=fv3jedi_hofx_atms.%j.out
#SBATCH --error=fv3jedi_hofx_atms.%j.err
#
# Sets up a run directory and runs fv3jedi_hofx_nomodel.x (ATMS N20, CRTM)
# on the C384 cubed-sphere history backgrounds.
#
# Submit with:  sbatch submit_fv3jedi_hofx_atms.sh
# NOTE: ntasks must equal 6 * LAYOUT^2 (LAYOUT=4 -> 96).

set -e
set -x

# ---------------------------------------------------------------------------
# User settings
# ---------------------------------------------------------------------------
BENCH=/scratch4/NCEPDEV/stmp/Cory.R.Martin/oct2026/ioda_benchmark
GDASAPP=${BENCH}/gdasapp
INPUTS=${BENCH}/test_case/inputs
EXEC=${GDASAPP}/build/bin/fv3jedi_hofx_nomodel.x
MODULEFILE_DIR=${GDASAPP}/modulefiles
MODULE=GDAS/ursa.intel

FIX=/scratch3/NCEPDEV/global/role.glopara/fix/gdas
FV3JEDI_FIX=${FIX}/fv3jedi/20241115
CRTM_FIX=${FIX}/crtm/20220805/2.3.0_jedi

# Valid time of the background / center of the DA window
WINDOW_BEGIN=2026-10-12T21:00:00Z
WINDOW_LENGTH=PT6H
WINDOW_END=2026-10-13T03:00:00Z
VALID_TIME=2026-10-13T00:00:00Z

# Background (C384, 127 levels); f006 from the 20261012 18z cycle is valid at VALID_TIME
BKG_FHR=006
NPX=385
NPZ=127
LAYOUT=4

# Observations
OBS_NAME=radiance_atms_n20
SENSOR_ID=atms_n20
OBS_FILE=${INPUTS}/iodanc/gdas.t00z.${OBS_NAME}.nc

RUNDIR=${RUNDIR:-/scratch4/NCEPDEV/stmp/${USER}/geode_ioda_test_case/run_hofx_atms_${SLURM_JOB_ID:-manual}}

# Link (default) or copy large inputs: LINK_CMD="cp"
LINK_CMD=${LINK_CMD:-"ln -sf"}

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------
module purge
module use "${MODULEFILE_DIR}"
module load "${MODULE}"

# need to load venv
module load rdhpcs-python/3.13
source /scratch4/NCEPDEV/stmp/Cory.R.Martin/oct2026/geode-venv/bin/activate

# Make sure the build's libraries are found at runtime
export LD_LIBRARY_PATH=${GDASAPP}/build/lib:${LD_LIBRARY_PATH:-}
export OMP_NUM_THREADS=1

# ---------------------------------------------------------------------------
# Run directory
# ---------------------------------------------------------------------------
mkdir -p "${RUNDIR}"/{bkg,obs,crtm,fv3jedi,diags}
cd "${RUNDIR}"

# Executable
${LINK_CMD} "${EXEC}" ./fv3jedi_hofx_nomodel.x

# FV3-JEDI / FMS files (relative paths: FMS requires them local)
${LINK_CMD} "${FV3JEDI_FIX}/fv3files/akbk${NPZ}.nc4"       fv3jedi/akbk.nc4
${LINK_CMD} "${FV3JEDI_FIX}/fv3files/fmsmpp.nml"            fv3jedi/fmsmpp.nml
${LINK_CMD} "${FV3JEDI_FIX}/fv3files/field_table_gfdl"      fv3jedi/field_table

# Backgrounds (names expected by the GDAS cube sphere history config)
${LINK_CMD} "${INPUTS}/bkg/gdas.t18z.csg_atm.f${BKG_FHR}.nc" bkg/cubed_sphere_grid_atmf006.nc
${LINK_CMD} "${INPUTS}/bkg/gdas.t18z.csg_sfc.f${BKG_FHR}.nc" bkg/cubed_sphere_grid_sfcf006.nc

# Observations
${LINK_CMD} "${OBS_FILE}" "obs/${OBS_NAME}.nc"

# CRTM coefficients: emissivity, aerosol/cloud, and sensor-specific files
for f in NPOESS.VISice NPOESS.VISland NPOESS.VISsnow NPOESS.VISwater \
         NPOESS.IRice NPOESS.IRland NPOESS.IRsnow Nalli.IRwater FASTEM6.MWwater; do
  ${LINK_CMD} "${CRTM_FIX}/${f}.EmisCoeff.bin" crtm/.
done
${LINK_CMD} "${CRTM_FIX}/AerosolCoeff.bin" crtm/.
${LINK_CMD} "${CRTM_FIX}/CloudCoeff.bin"   crtm/.
${LINK_CMD} "${CRTM_FIX}/${SENSOR_ID}.SpcCoeff.bin" crtm/.
${LINK_CMD} "${CRTM_FIX}/${SENSOR_ID}.TauCoeff.bin" crtm/.

# ---------------------------------------------------------------------------
# YAML
# ---------------------------------------------------------------------------
# All 22 ATMS channels; ATMS observes brightnessTemperature directly, so no
# radiance -> brightness temperature conversion is needed.
CHANNELS="1-22"

cat > hofx_nc.yaml <<EOF
time window:
  begin: ${WINDOW_BEGIN}
  length: ${WINDOW_LENGTH}

geometry:
  fms initialization:
    namelist filename: ./fv3jedi/fmsmpp.nml
    field table filename: ./fv3jedi/field_table
  akbk: ./fv3jedi/akbk.nc4
  layout: [${LAYOUT}, ${LAYOUT}]
  npx: ${NPX}
  npy: ${NPX}
  npz: ${NPZ}

state:
  datapath: ./bkg
  filetype: cube sphere history
  provider: ufs
  datetime: "${VALID_TIME}"
  filenames:
  - cubed_sphere_grid_atmf006.nc
  - cubed_sphere_grid_sfcf006.nc
  max allowable geometry difference: 1e-4
  state variables:
  - eastward_wind
  - northward_wind
  - air_temperature
  - water_vapor_mixing_ratio_wrt_moist_air
  - cloud_liquid_ice
  - cloud_liquid_water
  - air_pressure_at_surface
  - ozone_mass_mixing_ratio
  - snow_water
  - rain_water
  - graupel
  - geopotential_height_at_surface
  - skin_temperature_at_surface
  - cloud_ice_number_concentration
  - rain_number_concentration
  - slmsk
  - sheleg
  - vtype
  - stype
  - vfrac
  - soilt
  - soilm
  - eastward_wind_at_surface
  - northward_wind_at_surface
  - ratio_of_wind_at_surface_adjacent_layer_to_wind_at_10m
  - air_temperature_at_2m
  field io names:
    eastward_wind: ugrd
    northward_wind: vgrd
    air_temperature: tmp
    layer_thickness: delz
    air_pressure_thickness: dpres
    air_pressure_at_surface: pressfc
    water_vapor_mixing_ratio_wrt_moist_air: spfh
    cloud_liquid_ice: icmr
    cloud_liquid_water: clwmr
    snow_water: snmr
    rain_water: rwmr
    graupel: grle
    cloud_ice_number_concentration: nccice
    rain_number_concentration: nconrd
    ozone_mass_mixing_ratio: o3mr
    ratio_of_wind_at_surface_adjacent_layer_to_wind_at_10m: f10m
    geopotential_height_at_surface: hgtsfc
    slmsk: land
    sheleg: weasd
    skin_temperature_at_surface: tmpsfc
    stype: sotyp
    vfrac: veg
    eastward_wind_at_surface: ugrd_hyblev1
    northward_wind_at_surface: vgrd_hyblev1
    soilm: soilw1
    soilt: soilt1
    air_temperature_at_2m: tmp2m

observations:
  get values:
    variable change:
      variable change name: Model2GeoVaLs
      hydrometeor effective radii method: gsi
  observers:
  - obs space:
      name: ${OBS_NAME}
      use data frame container: true
      obsdatain:
        engine:
          type: H5File
          obsfile: ./obs/${OBS_NAME}.nc
      obsdataout:
        engine:
          type: H5File
          obsfile: ./diags/diag_${OBS_NAME}_iodanc.nc
      io pool:
        max pool size: 1
      observed variables: [brightnessTemperature]
      simulated variables: [brightnessTemperature]
      channels: &${OBS_NAME}_simulated_channels ${CHANNELS}
    obs operator:
      name: CRTM
      Absorbers: [H2O, O3, CO2]
      Clouds: [Water, Ice]
      Cloud_Fraction: 1.0
      obs options:
        Sensor_ID: ${SENSOR_ID}
        EndianType: little_endian
        CoefficientPath: ./crtm/
EOF

cat > hofx_geode.yaml <<EOF
time window:
  begin: ${WINDOW_BEGIN}
  length: ${WINDOW_LENGTH}

geometry:
  fms initialization:
    namelist filename: ./fv3jedi/fmsmpp.nml
    field table filename: ./fv3jedi/field_table
  akbk: ./fv3jedi/akbk.nc4
  layout: [${LAYOUT}, ${LAYOUT}]
  npx: ${NPX}
  npy: ${NPX}
  npz: ${NPZ}

state:
  datapath: ./bkg
  filetype: cube sphere history
  provider: ufs
  datetime: "${VALID_TIME}"
  filenames:
  - cubed_sphere_grid_atmf006.nc
  - cubed_sphere_grid_sfcf006.nc
  max allowable geometry difference: 1e-4
  state variables:
  - eastward_wind
  - northward_wind
  - air_temperature
  - water_vapor_mixing_ratio_wrt_moist_air
  - cloud_liquid_ice
  - cloud_liquid_water
  - air_pressure_at_surface
  - ozone_mass_mixing_ratio
  - snow_water
  - rain_water
  - graupel
  - geopotential_height_at_surface
  - skin_temperature_at_surface
  - cloud_ice_number_concentration
  - rain_number_concentration
  - slmsk
  - sheleg
  - vtype
  - stype
  - vfrac
  - soilt
  - soilm
  - eastward_wind_at_surface
  - northward_wind_at_surface
  - ratio_of_wind_at_surface_adjacent_layer_to_wind_at_10m
  - air_temperature_at_2m
  field io names:
    eastward_wind: ugrd
    northward_wind: vgrd
    air_temperature: tmp
    layer_thickness: delz
    air_pressure_thickness: dpres
    air_pressure_at_surface: pressfc
    water_vapor_mixing_ratio_wrt_moist_air: spfh
    cloud_liquid_ice: icmr
    cloud_liquid_water: clwmr
    snow_water: snmr
    rain_water: rwmr
    graupel: grle
    cloud_ice_number_concentration: nccice
    rain_number_concentration: nconrd
    ozone_mass_mixing_ratio: o3mr
    ratio_of_wind_at_surface_adjacent_layer_to_wind_at_10m: f10m
    geopotential_height_at_surface: hgtsfc
    slmsk: land
    sheleg: weasd
    skin_temperature_at_surface: tmpsfc
    stype: sotyp
    vfrac: veg
    eastward_wind_at_surface: ugrd_hyblev1
    northward_wind_at_surface: vgrd_hyblev1
    soilm: soilw1
    soilt: soilt1
    air_temperature_at_2m: tmp2m

observations:
  get values:
    variable change:
      variable change name: Model2GeoVaLs
      hydrometeor effective radii method: gsi
  observers:
  - obs space:
      name: ${OBS_NAME}
      use data frame container: true
      obsdatain:
        engine:
          type: GEODE
          obsfile: ./obs/${OBS_NAME}.nc
          query file: ./obs/${OBS_NAME}.query.yaml
      obsdataout:
        engine:
          type: H5File
          obsfile: ./diags/diag_${OBS_NAME}_geode.nc
      io pool:
        max pool size: 1
      observed variables: [brightnessTemperature]
      simulated variables: [brightnessTemperature]
      channels: &${OBS_NAME}_simulated_channels ${CHANNELS}
    obs operator:
      name: CRTM
      Absorbers: [H2O, O3, CO2]
      Clouds: [Water, Ice]
      Cloud_Fraction: 1.0
      obs options:
        Sensor_ID: ${SENSOR_ID}
        EndianType: little_endian
        CoefficientPath: ./crtm/
EOF

cat > obs/${OBS_NAME}.query.yaml <<EOF
data type: atms_n20
start time: ${WINDOW_BEGIN}
end time: ${WINDOW_END}

variables:
  - latitude
  - longitude
  - brightnessTemperature
  - dateTime
EOF

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
NTASKS=$((6 * LAYOUT * LAYOUT))
echo "Running in ${RUNDIR} with ${NTASKS} tasks"
srun -n "${NTASKS}" ./fv3jedi_hofx_nomodel.x hofx_nc.yaml hofx_nc.log
echo "Finished: $(date)"
srun -n "${NTASKS}" ./fv3jedi_hofx_nomodel.x hofx_geode.yaml hofx_geode.log
echo "Finished: $(date)"
