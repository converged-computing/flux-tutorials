#!/bin/bash
#FLUX -N 3
#FLUX --cpu-affinity=per-task

cat > /bin/what-i-want-1.sh << EOF
echo
echo "A world of cheese, a joyful spread"
echo "From softest Brie to Cheddar's head."
echo "Each creamy bite, each crumbly art,"
echo "A simple pleasure for the heart."
EOF
chmod +x /bin/what-i-want-1.sh

cat > the-next-clue.txt << EOF
One job id is a good test.
But expand on that, and Flux Bird will make his nest.
EOF

cat > /bin/what-i-want-2.sh << EOF
echo
echo "But in my bin, thoughts now stray,"
echo "To golden flakes that make my day."
echo "A certain dish, it waits, you see,"
echo "For Parmesan's sharp company."
EOF
chmod +x /bin/what-i-want-2.sh

cat > /bin/what-i-want-3.sh << EOF
echo
echo "That nutty zest, that crystal bright,"
echo "Is what my terminal lacks tonight."
echo "A missing star, a flavor haunt,"
echo "A cheesy promise I should want."
sleep 2
echo "Run me again, this time with zest."
sleep 10
touch /bin/what-i-want-run.txt
EOF
chmod +x /bin/what-i-want-3.sh

flux run -N1 bash /bin/what-i-want-1.sh
flux run -N1 bash /bin/what-i-want-2.sh
flux run -N1 bash /bin/what-i-want-3.sh

if [[ -z "${WITHZEST}" ]]; then
   echo "Try again, this time with zest."
else
  echo "We submit three jobs."
  echo "ENTER THE INSTANCE ($FLUX_URI) and find the next clue"
  echo "I'm going to sleep"
  sleep infinity
fi
