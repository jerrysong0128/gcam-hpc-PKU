# GCAM High Performance Computing Cluster for PKU

BUILD
RUN
QUERY

This guide describes how to set up and build GCAM for high-performance computing (HPC) at PKU. It covers cloning the necessary repositories, preparing dependencies, configuring environment variables, and building the GCAM model.

---
# Step BUILD
## Step B-1: Clone the Repositories

### B-1.1: Load Core Modules
First, clone both the main GCAM core repository and the PKU HPC tools repository into your workspace directory.

```sh
git clone https://github.com/jerrysong0128/gcam-hpc-PKU.git
```

---
### B-1.2: Load GCAM-core
```sh
git submodule status
git submodule update --init gcam-core
```
---
### B-1.3: Load Required Submodules (Initialize Hector Submodule for GCAM Core)

GCAM uses Hector as its climate module, which is included as a git submodule. You need to initialize and update this submodule:

```sh
cd gcam-core
make install_hector
#or
git submodule update --init cvs/objects/climate/source/hector
git submodule update --init output/modelinterface/modelinterface
```
This command ensures that the Hector source code is downloaded and available for building GCAM.

---

## Step B-2: Prepare Required Libraries

### B-2.1: Unzip Prebuilt Libraries

Some required libraries are provided as a zip archive. Unzip them to the appropriate location:

```sh
cd ./gcam-hpc-tools/build-tools/zips
unzip ./libs.zip -d ../
```
This extracts the libraries needed for building and running GCAM.

### B-2.2: Install Java (OpenJDK)

GCAM requires Java for some components. The provided JAVA is for windows machine. To build on high-performance computing (HPC) at PKU, you should extract the provided OpenJDK for linux archive:

```sh
mkdir -p gcam-hpc-tools/build-tools/libs/java_linux
tar -xzf gcam-hpc-PKU/archive/OpenJDK17U-jdk_x64_linux_hotspot_17.0.16_8.tar.gz -C gcam-hpc-PKU/gcam-hpc-tools/build-tools/libs/java_linux --strip-components=1
```
This command creates the target directory and extracts the Java runtime there.
### B-2.3: Install TBB

GCAM requires TBB for some components. The provided TBB is for windows machine. To build on high-performance computing (HPC) at PKU, you should extract the provided TBB for linux archive:

```sh
mkdir -p gcam-hpc-PKU/gcam-hpc-tools/build-tools/libs/tbb-linux
tar -xzf gcam-hpc-PKU/archive/oneapi-tbb-2021.8.0-lin.tgz -C gcam-hpc-PKU/gcam-hpc-tools/build-tools/libs/tbb-linux --strip-components=1
```
This command creates the target directory and extracts the Java runtime there.

## Step B-3: Build GCAM

### B-3.1: Set Environment Variables

Before building, set the required environment variables so that the build system can find all dependencies:

```sh
# Set the workspace path to your local repository location
export GCAM_WORKSPACE=/path/to/repo
# Example:
# export GCAM_WORKSPACE=/lustre/home/<ID>/Desktop/GCAM_Workspace

# Source the setup script to configure library paths and other environment variables
source ../gcam-hpc-PKU/gcam-hpc-tools/build-tools/gcam-hpc-build-relative-libs-wm2.setup
```
This step ensures that all build tools and libraries are correctly referenced during compilation.

---
### B-3.2: Clean Previous Builds

Navigate to the GCAM core directory and clean any previous build artifacts:

```sh
cd ./gcam-core
make clean
```

### B-3.3: Compile GCAM

Build GCAM using multiple threads for faster compilation:

```sh
make gcam -j 8
```
The `-j 8` flag tells `make` to use 16 parallel jobs, which speeds up the build process on multi-core systems.


```
make[2]: Leaving directory '/lustre/home/2501112459/Desktop/GCAM_Workspace/gcam-core/cvs/objects/main/source'
cp ../../main/source/gcam.exe ../../../../exe/
BUILD COMPLETED
Mon Jul 21 22:59:56 CST 2025
make[1]: Leaving directory '/lustre/home/2501112459/Desktop/GCAM_Workspace/gcam-core/cvs/objects/build/linux'
```
If see this the gcam.exe. build completed.



## Notes

- Make sure all paths are correct for your system.
- If you encounter errors related to missing libraries or environment variables, double-check that all previous steps completed successfully.
- For more information about GCAM build, see the [GCAM documentation](https://jgcri.github.io/gcam-doc/gcam-build.html)

## Step RUN

## Step R-1: Run gcamdata

### R-1.1: Load R


## Step R-2: Run gcam-core
```sh
./gcam-hpc-tools/master.sh \
    ./gcam-hpc-tools/configuration-sets/configuration_empty_scenario_components.xml \
    ./gcam-hpc-tools/configuration-sets/reference_batch_1.xml
```