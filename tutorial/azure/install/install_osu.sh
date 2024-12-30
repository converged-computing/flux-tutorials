#!/bin/bash

cd /tmp
OSU_VERSION=5.8
wget http://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-$OSU_VERSION.tgz
tar zxvf ./osu-micro-benchmarks-5.8.tgz
cd osu-micro-benchmarks-5.8/
./configure CC=mpicc CXX=mpicxx
make -j 4 && sudo make install

# installs to /usr/local/libexec/osu-benchmarks/mpi
