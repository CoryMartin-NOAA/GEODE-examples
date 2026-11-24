# GEODE-examples
Repository containing useful scripts, notebooks, etc. for GEODE that probably shouldn't live in the main repo

## Building IODA with GEODE support on Ursa

The following scripts provide a reproducible build environment for the IODA GEODE reader using NOAA's Spack-stack 2.2.0 environment with Intel oneAPI.

### Requirements

- Access to NOAA Ursa.
- Spack-stack 2.2.0, Intel oneAPI 2025.3.1.
- A local checkout of the GEODE repository.

### Build

Create the Python virtual environment and install GEODE and the synthetic-test dependency (Icechunk):

```bash
./create_ioda_venv_ursa_spack_stack_2.2.0.sh /path/to/GEODE
```

Configure the environment and build the IODA GEODE reader and synthetic reader tests:

```bash
./build_ioda_ursa_spack_stack_2.2.0.sh
```

or

```bash
IODA_SOURCE_DIR="$PWD/ioda-test" IODA_BUILD_DIR="$PWD/ioda-test-build" IODA_INSTALL_DIR="$PWD/ioda-test-install" ./build_ioda_ursa_spack_stack_2.2.0.sh
```


To install the build:

```bash
./build_ioda_ursa_spack_stack_2.2.0.sh --install
```

The environment can also be loaded independently in an interactive shell:

```bash
source ./setup_ioda_env_ursa_spack_stack_2.2.0.sh
```
