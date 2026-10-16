#!/bin/bash
#SBATCH --job-name=fv3jedi_hofx
#SBATCH --account=da-cpu
#SBATCH --qos=batch
#SBATCH --nodes=8
#SBATCH --ntasks=96
#SBATCH --ntasks-per-node=12
#SBATCH --time=00:30:00
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --output=fv3jedi_hofx.%j.out
#SBATCH --error=fv3jedi_hofx.%j.err
#
# Sets up a run directory and runs fv3jedi_hofx_nomodel.x (CrIS FSR N20, CRTM)
# on the C384 cubed-sphere history backgrounds.
#
# Submit with:  sbatch submit_fv3jedi_hofx.sh
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
VALID_TIME=2026-10-13T00:00:00Z

# Background (C384, 127 levels); f006 from the 20261012 18z cycle is valid at VALID_TIME
BKG_FHR=006
NPX=385
NPZ=127
LAYOUT=4

# Observations
OBS_NAME=radiance_cris_fsr_n20
SENSOR_ID=cris-fsr_n20
OBS_FILE=${INPUTS}/iodanc/gdas.t00z.${OBS_NAME}.nc

RUNDIR=${RUNDIR:-/scratch4/NCEPDEV/stmp/${USER}/geode_ioda_test_case/run_hofx_${SLURM_JOB_ID:-manual}}

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
# CrIS FSR channel sets (same as the GDAS radiance_cris-fsr_n20 observer), by band
BAND1="19, 24, 26, 27, 28, 31, 32, 33, 37, 39, 42, 44, 47, 49, 50,
  51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68,
  69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86,
  87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103,
  104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117,
  118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131,
  132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145,
  146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159,
  160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173,
  174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187,
  188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 208,
  211, 216, 224, 234, 236, 238, 239, 242, 246, 248, 255, 264, 266, 268,
  275, 279, 283, 285, 291, 295, 301, 305, 311, 332, 342, 389, 400, 402,
  404, 406, 410, 427, 439, 440, 441, 445, 449, 455, 458, 461, 464, 467,
  470, 473, 475, 482, 486, 487, 490, 493, 496, 499, 501, 503, 505, 511,
  513, 514, 518, 519, 520, 522, 529, 534, 563, 568, 575, 592, 594, 596,
  598, 600, 602, 604, 611, 614, 616, 618, 620, 622, 626, 631, 638, 646,
  648, 652, 659, 673, 675, 678, 684, 688, 694, 700, 707, 710, 713"
BAND2="714, 718, 720, 722, 725, 728, 735, 742, 748, 753, 762, 780, 784, 798, 849,
  860, 862, 866, 874, 882, 890, 898, 906, 907, 908, 914, 937, 972, 973,
  978, 980, 981, 988, 995, 998, 1000, 1003, 1008, 1009, 1010, 1014, 1017,
  1018, 1020, 1022, 1024, 1026, 1029, 1030, 1032, 1034, 1037, 1038, 1041,
  1042, 1044, 1046, 1049, 1050, 1053, 1054, 1058, 1060, 1062, 1064, 1066,
  1069, 1076, 1077, 1080, 1086, 1091, 1095, 1101, 1109, 1112, 1121, 1128,
  1133, 1163, 1172, 1187, 1189, 1205, 1211, 1219, 1231, 1245, 1271, 1289,
  1300, 1313, 1316, 1325, 1329, 1346, 1347, 1473, 1474, 1491, 1499, 1553,
  1570"
BAND3="1596, 1602, 1619, 1624, 1635, 1939, 1940, 1941, 1942, 1943, 1944,
  1945, 1946, 1947, 1948, 1949, 1950, 1951, 1952, 1953, 1954, 1955, 1956,
  1957, 1958, 1959, 1960, 1961, 1962, 1963, 1964, 1965, 1966, 1967, 1968,
  1969, 1970, 1971, 1972, 1973, 1974, 1975, 1976, 1977, 1978, 1979, 1980,
  1981, 1982, 1983, 1984, 1985, 1986, 1987, 2119, 2140, 2143, 2147, 2153,
  2158, 2161, 2168, 2171, 2175, 2182"

# Collapse to single lines so the lists are valid inline YAML
BAND1=$(echo ${BAND1}); BAND2=$(echo ${BAND2}); BAND3=$(echo ${BAND3})

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
        max pool size: 8
      observed variables: [spectralRadiance]
      derived variables: [brightnessTemperature]
      simulated variables: [brightnessTemperature]
      channels: &${OBS_NAME}_simulated_channels ${BAND1}, ${BAND2}, ${BAND3}
    obs operator:
      name: CRTM
      Absorbers: [H2O, O3, CO2]
      obs options:
        Sensor_ID: ${SENSOR_ID}
        EndianType: little_endian
        CoefficientPath: ./crtm/
    # Observation Pre Filters (QC)
    # ----------------------------
    obs pre filters:
    # Step 1: Create Derived Variables
    # Assign channel wavenumbers in m-1
    - filter: Variable Assignment
      assignments:
      - name: MetaData/sensorCentralWavenumber
        type: float
        channels: &${OBS_NAME}_band1 ${BAND1}
        function:
          name: ObsFunction/LinearCombination
          options:
            variables:
            - name: ObsValue/spectralRadiance
              channels: *${OBS_NAME}_band1 
            coefs: [62.5]
            intercept: 64937.5
            use channel numbers: true

    - filter: Variable Assignment
      assignments:
      - name: MetaData/sensorCentralWavenumber
        type: float
        channels: &${OBS_NAME}_band2 ${BAND2}
        function:
          name: ObsFunction/LinearCombination
          options:
            variables:
            - name: ObsValue/spectralRadiance
              channels: *${OBS_NAME}_band2 
            coefs: [62.5]
            intercept: 76375
            use channel numbers: true

    - filter: Variable Assignment
      assignments:
      - name: MetaData/sensorCentralWavenumber
        type: float
        channels: &${OBS_NAME}_band3 ${BAND3}
        function:
          name: ObsFunction/LinearCombination
          options:
            variables:
            - name: ObsValue/spectralRadiance
              channels: *${OBS_NAME}_band3
            coefs: [62.5]
            intercept: 116812.5
            use channel numbers: true

    # Step 2: Transform radiance to brightness temperature
    - filter: Variable Transforms
      Transform: SatBrightnessTempFromRad
      transform from:
        name: ObsValue/spectralRadiance
        channels: *${OBS_NAME}_simulated_channels
      spectral variable:
        name: MetaData/sensorCentralWavenumber
        channels: *${OBS_NAME}_simulated_channels
      radiance units: wavenumber
      planck1: 1.191042953e-16
      planck2: 1.4387774e-2

    # Step 4: Create cloudFree variable
    - filter: Variable Assignment
      assignments:
      - name: DerivedMetaData/cloudFree 
        type: int
        function:
          name: ObsFunction/Arithmetic
          options:
            variables:
            - name: ObsValue/cloudCoverTotal
            coefs: [-100] 
            intercept: 100 

    # Step 5: Data Thinning
    - filter: Gaussian Thinning
      filter variables:
      - name: brightnessTemperature
        channels: *${OBS_NAME}_simulated_channels
      horizontal_mesh: 145
      use_reduced_horizontal_grid: true
      distance_norm: geodesic
      priority_variable: DerivedMetaData/cloudFree
      action:
        name: reduce obs space
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
          type: H5File
          obsfile: ./obs/${OBS_NAME}.nc
      obsdataout:
        engine:
          type: H5File
          obsfile: ./diags/diag_${OBS_NAME}_iodanc.nc
      io pool:
        max pool size: 8
      observed variables: [spectralRadiance]
      derived variables: [brightnessTemperature]
      simulated variables: [brightnessTemperature]
      channels: &${OBS_NAME}_simulated_channels ${BAND1}, ${BAND2}, ${BAND3}
    obs operator:
      name: CRTM
      Absorbers: [H2O, O3, CO2]
      obs options:
        Sensor_ID: ${SENSOR_ID}
        EndianType: little_endian
        CoefficientPath: ./crtm/
    # Observation Pre Filters (QC)
    # ----------------------------
    obs pre filters:
    # Step 1: Create Derived Variables
    # Assign channel wavenumbers in m-1
    - filter: Variable Assignment
      assignments:
      - name: MetaData/sensorCentralWavenumber
        type: float
        channels: &${OBS_NAME}_band1 ${BAND1}
        function:
          name: ObsFunction/LinearCombination
          options:
            variables:
            - name: ObsValue/spectralRadiance
              channels: *${OBS_NAME}_band1 
            coefs: [62.5]
            intercept: 64937.5
            use channel numbers: true

    - filter: Variable Assignment
      assignments:
      - name: MetaData/sensorCentralWavenumber
        type: float
        channels: &${OBS_NAME}_band2 ${BAND2}
        function:
          name: ObsFunction/LinearCombination
          options:
            variables:
            - name: ObsValue/spectralRadiance
              channels: *${OBS_NAME}_band2 
            coefs: [62.5]
            intercept: 76375
            use channel numbers: true

    - filter: Variable Assignment
      assignments:
      - name: MetaData/sensorCentralWavenumber
        type: float
        channels: &${OBS_NAME}_band3 ${BAND3}
        function:
          name: ObsFunction/LinearCombination
          options:
            variables:
            - name: ObsValue/spectralRadiance
              channels: *${OBS_NAME}_band3
            coefs: [62.5]
            intercept: 116812.5
            use channel numbers: true

    # Step 2: Transform radiance to brightness temperature
    - filter: Variable Transforms
      Transform: SatBrightnessTempFromRad
      transform from:
        name: ObsValue/spectralRadiance
        channels: *${OBS_NAME}_simulated_channels
      spectral variable:
        name: MetaData/sensorCentralWavenumber
        channels: *${OBS_NAME}_simulated_channels
      radiance units: wavenumber
      planck1: 1.191042953e-16
      planck2: 1.4387774e-2

    # Step 4: Create cloudFree variable
    - filter: Variable Assignment
      assignments:
      - name: DerivedMetaData/cloudFree 
        type: int
        function:
          name: ObsFunction/Arithmetic
          options:
            variables:
            - name: ObsValue/cloudCoverTotal
            coefs: [-100] 
            intercept: 100 

    # Step 5: Data Thinning
    - filter: Gaussian Thinning
      filter variables:
      - name: brightnessTemperature
        channels: *${OBS_NAME}_simulated_channels
      horizontal_mesh: 145
      use_reduced_horizontal_grid: true
      distance_norm: geodesic
      priority_variable: DerivedMetaData/cloudFree
      action:
        name: reduce obs space
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
