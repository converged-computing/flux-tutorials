FROM ghcr.io/converged-computing/slurm

# docker build -t ghcr.io/converged-computing/slurm-operator:with-flux .

# This is the standard slurm operator base, but we add flux from conda-forge
RUN yum update -y && yum install -y bzip2 curl iproute munge && \
    curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba && yum clean all

# COPY ./env.yaml /tmp/env.yaml
# RUN 
