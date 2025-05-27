#!/bin/bash

echo "To start with our fun"
echo "There is a little bit of work you must run."
echo "But first, you need 4 nodes."
echo "Physical nodes have appeal."
echo "But they don't need to be real!"

cat > work.sh << EOF
#!/bin/bash

# Running without Flux, no good
if [[ -z "\${FLUX_JOB_SIZE}" ]]; then
    echo "Running directly without help? Tsk tsk."
    exit
fi

# Running with flux on 4 nodes
if [ "\${FLUX_JOB_SIZE}" -ne 4 ]
  then
  echo "I asked for 4 nodes, yet you give me \${FLUX_JOB_SIZE}?"
  exit
fi

echo "Good job padwan - this is node \${FLUX_TASK_RANK}"
touch work.done
if [[ ! -f "work.done" ]]
  then
  echo "What about non interactively?"
else
  echo "Good job 😎"
  echo "Your next task is in the bin."
  echo "Something you need to do on a whim"
fi
EOF
