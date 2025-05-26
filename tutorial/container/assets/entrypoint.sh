#!/bin/bash

node /code/matrix.js || true
flux start /bin/bash -c "cat /etc/motd && bash"
