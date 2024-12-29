# Azure Docker Builds

We hope that Microsoft can eventually provide container bases, but until then we need to make a best effort to do that. This attempts to mirror the logic and match versions for their Azure HPC images builds.

## Base

The base image has core dependencies like hpcx and flux.

```bash
cd ./base
docker build -t ghcr.io/converged-computing/flux-tutorials:azurehpc-2204 .
docker push ghcr.io/converged-computing/flux-tutorials:azurehpc-2204
```

## OSU

*Coming soon*

```bash
cd ./osu
docker build -t ghcr.io/converged-computing/flux-tutorials:azurehpc-2204-osu .
docker push ghcr.io/converged-computing/metric-osu-cpu:azure-hpc-osu
```


