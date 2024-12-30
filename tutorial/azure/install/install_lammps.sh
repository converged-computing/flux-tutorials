#!/bin/bash

. /opt/hpcx-v2.15-gcc-MLNX_OFED_LINUX-5-ubuntu22.04-cuda12-gdrcopy2-nccl2.17-x86_64/hpcx-mt-init.sh
hpcx_load

# This is the exact version we used in our performance study
cd /tmp
mkdir lammps
cd lammps
git init
git remote add origin https://github.com/lammps/lammps.git
git fetch --depth 1 origin a8687b53724b630fb5f454c8d7be9f9370f8bb3b
git checkout FETCH_HEAD 
mkdir build
cd build
cmake ../cmake -D PKG_REAXFF=yes -D BUILD_MPI=yes -D PKG_OPT=yes -D FFT=FFTW3 -D CMAKE_INSTALL_PREFIX=/usr
make -j && sudo make install
