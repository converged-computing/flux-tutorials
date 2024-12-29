#!/bin/bash

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
make && sudo make install
