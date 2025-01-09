FROM ghcr.io/converged-computing/flux-tutorials:azure-2404-base

# Build command
# docker build -t ghcr.io/converged-computing/flux-tutorials:azure-2404-osu .

RUN git clone --depth 1 https://github.com/ULHPC/tutorials /opt/tutorials && \
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
