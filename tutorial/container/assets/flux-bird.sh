#!/bin/bash

# Running without Flux, no good
if [[ -z "${FLUX_TERMINUS_SESSION}" ]]; then
    echo "Running directly without help? Tsk tsk. Create an alllocation first!"
    exit
fi

cd /tmp/fun
node fluxbird.js
