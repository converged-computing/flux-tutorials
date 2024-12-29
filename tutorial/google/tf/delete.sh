#!/bin/bash

zone=${1:-us-central1-a}
echo "How many flux instances did you create?"
read count

deletion=""

# The terraform has a bug about self link, so the make destroy stopped working. So we roll our own...
for (( i=1; i<=$count; i++ ))
  do
    # Add leading zeros
    n=${#i}
    if [[ "$n" == "1" ]]; then
       i="00${i}"
    elif [[ "$n" == "2" ]]; then
       count="0${i}"
    fi
    deletion="${deletion} flux-${i}"
done
echo "gcloud compute instances delete ${deletion} --zone=${zone} --quiet"
gcloud compute instances delete ${deletion} --zone=${zone} --quiet
