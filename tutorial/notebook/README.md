# Flux + Jupyter

This tutorial provides a notebook for learning about Flux! It is based off of the official Flux [Tutorials](https://github.com/flux-framework/Tutorials) but slimmed down for easier build and usage.

 - [Local Development or Usage](#local-usage)

Pre-requisite: Excitement to learn about Flux!
  
## Usage

This entire tutorial runs on your local machine with a single container! You will need to [install Docker](https://docs.docker.com/engine/install/). When you have Docker available, you can build and run the tutorial with:

```bash
docker build -t flux-tutorial .
docker network create jupyterhub

# Here is how to run an entirely contained tutorial (the notebook in the container)
docker run --rm -it --entrypoint /start.sh -v /var/run/docker.sock:/var/run/docker.sock --net jupyterhub --name jupyterhub -p 8888:8888 flux-tutorial
```

If you want to develop the ipynb files, you can bind the tutorials directory:

```bash
docker run --rm -it --entrypoint /start.sh -v $PWD/tutorial:/home/jovyan/flux-tutorial-2024 -v /var/run/docker.sock:/var/run/docker.sock --net jupyterhub --name jupyterhub -p 8888:8888 flux-tutorial
```

And then editing and saving will save to your host. You can also File -> Download if you forget to do
this bind. Either way, when the container is running you can open the localhost or 127.0.0.1 (home sweet home!) link in your browser on port 8888. You'll want to go to flux-tutorial-2024 -> notebook to see the notebook.
You'll need to select http only (and bypass the no certificate warning).
