FROM fluxrm/flux-sched:jammy
USER root
# docker build -t fluxrm/flux-sched:jammi .
# docker run -it fluxrm/flux-sched:jammi
RUN apt-get update && apt-get install -y vim wget curl git
RUN git clone https://github.com/vladimir-vovk/jmatrix /code

ENV NVM_DIR=/opt/nvm
ENV NODE_VERSION=20
RUN mkdir -p $NVM_DIR && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
RUN bash -c "source $NVM_DIR/nvm.sh && nvm install $NODE_VERSION"

ENV fluxuser=bigcheese
RUN useradd -ms /bin/bash $fluxuser && \
    usermod -aG sudo $fluxuser && \
    echo "$fluxuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
RUN echo 'export PS1="🧀 \W # "' >> /root/.bashrc && \
    echo 'export PS1="🧀 \W # "' >> /home/$fluxuser/.bashrc
WORKDIR /code
COPY ./assets/matrix.js ./matrix.js
RUN /bin/bash -c "source $NVM_DIR/nvm.sh && npm install"

# Add the fun!
COPY ./assets/fun /tmp/fun
WORKDIR /tmp/fun
RUN /bin/bash -c "source $NVM_DIR/nvm.sh && npm install chalk terminal-image gif-decode"

WORKDIR /tmp/thenest
COPY ./assets/flux-bird.sh ./flux-bird.sh

# Enter the abyss...
WORKDIR /abyss
COPY ./assets/dont-run-me.sh ./.dont-run-me.sh
COPY ./assets/entrypoint.sh /entrypoint.sh
COPY ./assets/something-you-do-on-a-whim-batch-me-baby.sh /bin/something-you-do-on-a-whim-batch-me-baby.sh
COPY ./assets/fun/motd /etc/motd
ENTRYPOINT ["/bin/bash", "-c", "source $NVM_DIR/nvm.sh && bash /entrypoint.sh"]
