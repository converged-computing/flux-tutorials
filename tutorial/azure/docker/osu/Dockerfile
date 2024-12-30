FROM ghcr.io/converged-computing/flux-tutorials:azurehpc-2204

# Build command
#  docker build -t ghcr.io/converged-computing/flux-tutorials:azurehpc-2204-osu .
#  docker push ghcr.io/converged-computing/metric-osu-cpu:azure-hpc-osu

ENV DEBIAN_FRONTEND=noninteractive
ENV UCX_NET_DEVICES=mlx5_0:1

# These can be set by the user based on your UCX preference, we have found different
# optimal performance depending on the environment.
# ENV UCX_TLS=ib
# ENV OMPI_MCA_btl_openib_warn_no_device_params_found=0
# Ensure you source and run hpcx_load for changes to PATH/LD_LIBRARY_PATH

# Prepare tutorial per
# https://ulhpc-tutorials.readthedocs.io/en/latest/parallel/mpi/OSU_MicroBenchmarks/

# Flux sched (later than this requires newer gcc and clang)
RUN . /source-hpcx.sh && hpcx_load && \
    git clone --depth 1 https://github.com/ULHPC/tutorials /opt/tutorials && \
    mkdir -p /opt/osu-benchmark && \
    cd /opt/osu-benchmark && \
    ln -s /opt/tutorials/parallel/mpi/OSU_MicroBenchmarks ref.d && \
    ln -s ref.d/Makefile . && \
    ln -s ref.d/scripts  . && \
    mkdir src && \
    cd src && \
    export OSU_VERSION=5.8 && \
    wget --no-check-certificate http://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-${OSU_VERSION}.tgz && \
    tar xf osu-micro-benchmarks-${OSU_VERSION}.tgz && \
    cd /opt/osu-benchmark && \
    # Compile based on openmpi
    mkdir -p build.openmpi && cd build.openmpi && \
    ../src/osu-micro-benchmarks-${OSU_VERSION}/configure CC=mpicc CXX=mpicxx CFLAGS=-I$(pwd)/../src/osu-micro-benchmarks-${OSU_VERSION}/util --prefix=$(pwd) && \
    make -j 4 && make install
