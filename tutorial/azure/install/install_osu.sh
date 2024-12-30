#!/bin/bash

. /opt/hpcx-v2.15-gcc-MLNX_OFED_LINUX-5-ubuntu22.04-cuda12-gdrcopy2-nccl2.17-x86_64/hpcx-mt-init.sh
hpcx_load

cd /tmp
OSU_VERSION=5.8
wget http://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-$OSU_VERSION.tgz
tar zxvf ./osu-micro-benchmarks-5.8.tgz
cd osu-micro-benchmarks-5.8/
./configure CC=mpicc CXX=mpicxx
make -j 4 && sudo make install

# installs to /usr/local/libexec/osu-benchmarks/mpi
