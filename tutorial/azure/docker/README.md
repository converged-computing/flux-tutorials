# Azure Docker Builds

These are simple images that mirror our ubuntu 24.04 builds.

## OSU

```bash
cd ./osu
docker build -t ghcr.io/converged-computing/flux-usernetes:azure-2404-osu .
docker push ghcr.io/converged-computing/metric-osu-cpu:azure-hpc-osu
```

## LAMMPS

```bash
cd ./lammps-reax
docker build -t ghcr.io/converged-computing/flux-tutorials:azure-2404-lammps-reax .
docker push ghcr.io/converged-computing/metric-osu-cpu:azure-hpc-lammps-reax
```
