FROM ghcr.io/converged-computing/flux-tutorials:azure-2404-base

# Build command
# docker build -t ghcr.io/converged-computing/flux-tutorials:azure-2404-lammps-reax .
# lmp -v x 2 -v y 2 -v z 2 -in in.reaxff.hns -nocite

WORKDIR /opt/lammps
RUN git init && \
    git remote add origin https://github.com/lammps/lammps.git && \
    git fetch --depth 1 origin a8687b53724b630fb5f454c8d7be9f9370f8bb3b && \
    git checkout FETCH_HEAD && \
    mkdir build && \
    cd build && \
    cmake ../cmake -D PKG_REAXFF=yes -D BUILD_MPI=yes -D PKG_OPT=yes -D FFT=FFTW3 -D CMAKE_INSTALL_PREFIX=/usr && make && make install 
    
WORKDIR /code
RUN cp -R /opt/lammps/examples/reaxff/HNS/* /code/ && \
    chown -R 1000 /code /opt/lammps

