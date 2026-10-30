#!/bin/bash
# run the first example of the geode project
# using a test container and sample data on Ursa

set -euo pipefail

container_image="/scratch3/NCEPDEV/da/Cory.R.Martin/geode/containers/geode_env_20260925.sif"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
script_path="$script_dir/$(basename -- "${BASH_SOURCE[0]}")"

if [[ -z "${SINGULARITY_CONTAINER:-}" ]]; then
  exec singularity exec \
    --bind /scratch3 \
    --bind /scratch4 \
    --cleanenv \
    "$container_image" \
    bash "$script_path" "$@"
fi

# Clone and install GEODE inside the container.
user_name="$(id -un)"
test_dir="/scratch4/NCEPDEV/stmp/${user_name}/geode_test"
mkdir -p "$test_dir"
cd "$test_dir"
if [[ -d geode ]]; then
  rm -rf -- geode
fi
git clone --recursive https://github.com/noaa-emc/geode.git
cd geode
python -m pip install --user --no-build-isolation -e ".[dev]"

# modify GEODE config to point to Hyundeok's test lake
config="$HOME/.config/geode/geode.yaml"
desired='root_dir: "/scratch3/NCEPDEV/da/Hyundeok.Choi/geode_tmp"'

if grep -Fxq "$desired" "$config"; then
  echo "root_dir is already set correctly"
elif grep -q '^root_dir:' "$config"; then
  sed -i 's|^root_dir:.*|root_dir: "/scratch3/NCEPDEV/da/Hyundeok.Choi/geode_tmp"|' "$config"
  echo "Updated root_dir"
else
  printf '\n%s\n' "$desired" >> "$config"
  echo "Added root_dir"
fi

# ensure matplotlib and cartopy are installed in this environment
python -m pip install --user matplotlib cartopy

# run the first example script from the geode-examples directory
cd "$script_dir"
python "$script_dir/first_geode_example.py"

# assert that there is output from the first example script by looking for plot.png
if [ -f "$script_dir/plot.png" ]; then
  echo "Plot generated successfully"
else
  echo "Plot not found"
  exit 1
fi
