# Flux on Azure

## Usage

### 1. Build Images

Note that you should [build](build) the images first. Follow the instructions in the README there.

### 2. Deploy Terraform

You'll first need to export the image full identifier to the environment:

```bash
export TF_VAR_vm_image_storage_reference=/subscriptions/xxxxxxx/resourceGroups/xxxxx/providers/Microsoft.Compute/images/flux-framework
```
Note that I needed to clone this and do from the cloud shell in the Azure portal.

```bash
git clone https://github.com/converged-computing/flux-tutorials
cd flux-tutorials/tutorial/azure
```
Check the [start-script.sh](start-script.sh) and variables at the top of [main.tf](main.tf) (e.g., customize the size and other parameters) and then:

```bash
make
```

The shell can be buggy - if it seems like it's hanging, it's that terraform is waiting for you to enter "yes." You can type it (despite not seeing it) and press enter and it works every time... 50% of the time. :) I added a command to the Makefile to get around this:

```bash
make apply-approved
```

You can also run each command separately:

```bash
# Terraform init
make init

# Terraform validate
make validate

# Create (one of the below)
make apply
make apply-approved

# Destroy
make destroy
```

When it's done, save the public and private key to local files:

```bash
terraform output -json public_key | jq -r > id_azure.pub
terraform output -json private_key | jq -r > id_azure
chmod 600 id_azure*
```

Then get the instance ip addresses from the command line (or portal), and ssh in!

```bash
ip_address=$(az vmss list-instance-public-ips -g terraform-testing -n flux | jq -r .[0].ipAddress)
ssh -i ./id_azure azureuser@${ip_address}
```

To get a difference instance, just use the index (e.g., index 1 is the second instance)

```bash
follower_address=$(az vmss list-instance-public-ips -g terraform-testing -n flux | jq -r .[1].ipAddress)
ssh -i ./id_azure azureuser@${follower_address}
```

Note that if the lead broker doesn't come up as flux_0 (flux with all zeros, Azure is not predicable like that) we will need to update.

```bash
lead_broker=$(az vmss list-instances -g terraform-testing -n flux | jq -r .[0].osProfile.computerName)
echo "The lead broker is ${lead_broker}"
```
To run in parallel, let's write a list of hosts, and then issue the command

```bash
for address in $(az vmss list-instance-public-ips -g terraform-testing -n flux | jq -r .[].ipAddress)
  do
    echo "azureuser@$address" >> hosts.txt
done
```

```bash
git clone https://github.com/lilydjwg/pssh /tmp/pssh
export PATH=/tmp/pssh/bin:$PATH
```

#### Scripts

Here is how you can fix all your brokers:

```bash
for address in $(az vmss list-instance-public-ips -g terraform-testing -n flux | jq -r .[].ipAddress)
 do
   echo "Updating $address"
   scp -i ./id_azure update_brokers.sh azureuser@${address}:/tmp/update_brokers.sh
   # This is what the command would look like in serial
   # ssh -i ./id_azure azureuser@$address "/bin/bash /tmp/update_brokers.sh flux $lead_broker"
done

# This is done in parallel
pssh -h hosts.txt -x "-i ./id_azure" "/bin/bash /tmp/update_brokers.sh flux $lead_broker"
```

Note that I've also provided a script to install the OSU benchmarks with the same strategy above:

```bash
for address in $(az vmss list-instance-public-ips -g terraform-testing -n flux | jq -r .[].ipAddress)
 do
   echo "Updating $address"
   scp -i ./id_azure install_osu.sh azureuser@${address}:/tmp/install_osu.sh
done
pssh -h hosts.txt -x "-i ./id_azure" "/bin/bash /tmp/install_osu.sh flux $lead_broker"
```

This installs to `/usr/local/libexec/osu-benchmarks/mpi`. And lammps:

```bash
for address in $(az vmss list-instance-public-ips -g terraform-testing -n flux | jq -r .[].ipAddress)
 do
   echo "Updating $address"
   scp -i ./id_azure install_lammps.sh azureuser@${address}:/tmp/install_lammps.sh
done
pssh -h hosts.txt -x "-i ./id_azure" "/bin/bash /tmp/install_lammps.sh flux $lead_broker"
```
That installs to `/usr/bin/lmp`


### 3. Checks

Check the cluster status, the overlay status, and try running a job:

```bash
flux resource list
```
```bash
flux run -N 2 hostname
```

### 4. Benchmarks

Try running a benchmark!

#### OSU

```bash
flux run -N2 /usr/local/libexec/osu-micro-benchmarks/mpi/collective/osu_allreduce 
flux run -N2 -n2 /usr/local/libexec/osu-micro-benchmarks/mpi/pt2pt/osu_latency
```
```console
# OSU MPI Latency Test v5.8
# Size          Latency (us)
0                       1.57
1                       1.56
2                       1.56
4                       1.56
8                       1.57
16                      1.57
32                      1.70
64                      1.76
128                     1.80
256                     2.31
512                     2.36
1024                    2.52
2048                    2.70
4096                    3.46
8192                    3.96
16384                   5.24
32768                   6.85
65536                   9.18
131072                 14.20
262144                 17.30
524288                 27.94
1048576                50.00
2097152                92.04
4194304               177.34
```

#### LAMMPS

You can decrease the problem size for a faster run (x,y,z parameters).
```bash
cd /tmp/lammps/examples/reaxff/HNS
flux run -N2 -n 192 -o cpu-affinity=per-task lmp -v x 8 -v y 16 -v z 16 -in in.reaxff.hns -nocite
```

<details>

<summary>LAMMPS output</summary>

```console
LAMMPS (17 Apr 2024 - Development - a8687b5)
OMP_NUM_THREADS environment is not set. Defaulting to 1 thread. (src/comm.cpp:98)
  using 1 OpenMP thread(s) per MPI task
Reading data file ...
  triclinic box = (0 0 0) to (22.326 11.1412 13.778966) with tilt (0 -5.02603 0)
  8 by 4 by 6 MPI processor grid
  reading atoms ...
  304 atoms
  reading velocities ...
  304 velocities
  read_data CPU = 0.012 seconds
Replication is creating a 8x16x16 = 2048 times larger system...
  triclinic box = (0 0 0) to (178.608 178.2592 220.46346) with tilt (0 -80.41648 0)
  4 by 6 by 8 MPI processor grid
  bounding box image = (0 -1 -1) to (0 1 1)
  bounding box extra memory = 0.03 MB
  average # of replicas added to proc = 48.64 out of 2048 (2.38%)
  622592 atoms
  replicate CPU = 0.005 seconds
Neighbor list info ...
  update: every = 20 steps, delay = 0 steps, check = no
  max neighbors/atom: 2000, page size: 100000
  master list distance cutoff = 11
  ghost atom cutoff = 11
  binsize = 5.5, bins = 48 33 41
  2 neighbor lists, perpetual/occasional/extra = 2 0 0
  (1) pair reaxff, perpetual
      attributes: half, newton off, ghost
      pair build: half/bin/ghost/newtoff
      stencil: full/ghost/bin/3d
      bin: standard
  (2) fix qeq/reax, perpetual, copy from (1)
      attributes: half, newton off
      pair build: copy
      stencil: none
      bin: none
Setting up Verlet run ...
  Unit style    : real
  Current step  : 0
  Time step     : 0.1
Per MPI rank memory allocation (min/avg/max) = 252.5 | 252.7 | 253 Mbytes
   Step          Temp          PotEng         Press          E_vdwl         E_coul         Volume    
         0   300           -113.27833      439.01464     -111.57687     -1.7014647      7019230      
        10   300.82459     -113.28061      818.23773     -111.57918     -1.7014335      7019230      
        20   302.60711     -113.2858       1779.7064     -111.58448     -1.7013214      7019230      
        30   302.90619     -113.28656      4424.6361     -111.58547     -1.701093       7019230      
        40   301.12001     -113.28117      6444.965      -111.5804      -1.7007665      7019230      
        50   297.98897     -113.27178      6568.4529     -111.57138     -1.7004009      7019230      
        60   295.18676     -113.26338      6325.9237     -111.56334     -1.7000345      7019230      
        70   294.84699     -113.26231      6840.651      -111.56264     -1.6996686      7019230      
        80   297.64748     -113.27065      8213.699      -111.57135     -1.6993062      7019230      
        90   301.45139     -113.28199      9328.5706     -111.58301     -1.6989859      7019230      
       100   302.49959     -113.28506      10225.066     -111.5863      -1.6987587      7019230      
Loop time of 36.4598 on 192 procs for 100 steps with 622592 atoms

Performance: 0.024 ns/day, 1012.773 hours/ns, 2.743 timesteps/s, 1.708 Matom-step/s
100.0% CPU use with 192 MPI tasks x 1 OpenMP threads

MPI task timing breakdown:
Section |  min time  |  avg time  |  max time  |%varavg| %total
---------------------------------------------------------------
Pair    | 20.824     | 23.166     | 25.392     |  16.3 | 63.54
Neigh   | 0.36547    | 0.37331    | 0.37996    |   0.5 |  1.02
Comm    | 0.11136    | 1.8392     | 4.6777     |  67.7 |  5.04
Output  | 0.0010649  | 0.098938   | 0.20956    |  17.5 |  0.27
Modify  | 10.573     | 10.98      | 11.841     |  13.0 | 30.11
Other   |            | 0.00211    |            |       |  0.01

Nlocal:        3242.67 ave        3264 max        3216 min
Histogram: 10 26 23 5 0 5 38 50 30 5
Nghost:        12107.3 ave       12136 max       12071 min
Histogram: 6 12 23 11 16 23 34 29 33 5
Neighs:    1.07023e+06 ave 1.07661e+06 max 1.06257e+06 min
Histogram: 13 27 21 2 2 11 37 50 24 5

Total # of neighbors = 2.0548396e+08
Ave neighs/atom = 330.04593
Neighbor list builds = 5
Dangerous builds not checked
Total wall time: 0:00:37
```

</details>

### 4. Cleanup

This should work (but see [debugging](#debugging)).

```bash
make destroy
```

But if not, you can either delete the resource group from the console, or the command line:

```bash
az group delete --name terraform-testing
```

Note that this current build does not have flux-pmix, which might lead to issues with MPI. It's an issue of the VM base being compiled with a libpmix.so that has a different ABI than what flux is expecting. I will be looking into it.

### Info

Here is various output about the environment, collected on December 29, 2024.

```bash
ucx_info -d
```

<details>

<summary>UCX info output</summary>

```console
#
# Memory domain: self
#     Component: self
#             register: unlimited, cost: 0 nsec
#           remote key: 0 bytes
#           rkey_ptr is supported
#         memory types: host (access,reg_nonblock,reg,cache)
#
#      Transport: self
#         Device: memory
#           Type: loopback
#  System device: <unknown>
#
#      capabilities:
#            bandwidth: 0.00/ppn + 19360.00 MB/sec
#              latency: 0 nsec
#             overhead: 10 nsec
#            put_short: <= 4294967295
#            put_bcopy: unlimited
#            get_bcopy: unlimited
#             am_short: <= 8K
#             am_bcopy: <= 8K
#               domain: cpu
#           atomic_add: 32, 64 bit
#           atomic_and: 32, 64 bit
#            atomic_or: 32, 64 bit
#           atomic_xor: 32, 64 bit
#          atomic_fadd: 32, 64 bit
#          atomic_fand: 32, 64 bit
#           atomic_for: 32, 64 bit
#          atomic_fxor: 32, 64 bit
#          atomic_swap: 32, 64 bit
#         atomic_cswap: 32, 64 bit
#           connection: to iface
#      device priority: 0
#     device num paths: 1
#              max eps: inf
#       device address: 0 bytes
#        iface address: 8 bytes
#       error handling: ep_check
#
#
# Memory domain: tcp
#     Component: tcp
#             register: unlimited, cost: 0 nsec
#           remote key: 0 bytes
#         memory types: host (access,reg_nonblock,reg,cache)
#
#      Transport: tcp
#         Device: ib0
#           Type: network
#  System device: <unknown>
#
#      capabilities:
#            bandwidth: 2200.00/ppn + 0.00 MB/sec
#              latency: 5203 nsec
#             overhead: 50000 nsec
#            put_zcopy: <= 18446744073709551590, up to 6 iov
#  put_opt_zcopy_align: <= 1
#        put_align_mtu: <= 0
#             am_short: <= 8K
#             am_bcopy: <= 8K
#             am_zcopy: <= 64K, up to 6 iov
#   am_opt_zcopy_align: <= 1
#         am_align_mtu: <= 0
#            am header: <= 8037
#           connection: to ep, to iface
#      device priority: 1
#     device num paths: 1
#              max eps: 256
#       device address: 6 bytes
#        iface address: 2 bytes
#           ep address: 10 bytes
#       error handling: peer failure, ep_check, keepalive
#
#      Transport: tcp
#         Device: lo
#           Type: network
#  System device: <unknown>
#
#      capabilities:
#            bandwidth: 11.91/ppn + 0.00 MB/sec
#              latency: 10960 nsec
#             overhead: 50000 nsec
#            put_zcopy: <= 18446744073709551590, up to 6 iov
#  put_opt_zcopy_align: <= 1
#        put_align_mtu: <= 0
#             am_short: <= 8K
#             am_bcopy: <= 8K
#             am_zcopy: <= 64K, up to 6 iov
#   am_opt_zcopy_align: <= 1
#         am_align_mtu: <= 0
#            am header: <= 8037
#           connection: to ep, to iface
#      device priority: 1
#     device num paths: 1
#              max eps: 256
#       device address: 18 bytes
#        iface address: 2 bytes
#           ep address: 10 bytes
#       error handling: peer failure, ep_check, keepalive
#
#      Transport: tcp
#         Device: eth0
#           Type: network
#  System device: <unknown>
#
#      capabilities:
#            bandwidth: 2200.00/ppn + 0.00 MB/sec
#              latency: 5212 nsec
#             overhead: 50000 nsec
#            put_zcopy: <= 18446744073709551590, up to 6 iov
#  put_opt_zcopy_align: <= 1
#        put_align_mtu: <= 0
#             am_short: <= 8K
#             am_bcopy: <= 8K
#             am_zcopy: <= 64K, up to 6 iov
#   am_opt_zcopy_align: <= 1
#         am_align_mtu: <= 0
#            am header: <= 8037
#           connection: to ep, to iface
#      device priority: 0
#     device num paths: 1
#              max eps: 256
#       device address: 6 bytes
#        iface address: 2 bytes
#           ep address: 10 bytes
#       error handling: peer failure, ep_check, keepalive
#
#
# Connection manager: tcp
#      max_conn_priv: 2064 bytes
#
# Memory domain: sysv
#     Component: sysv
#             allocate: unlimited
#           remote key: 12 bytes
#           rkey_ptr is supported
#         memory types: host (access,alloc,cache)
#
#      Transport: sysv
#         Device: memory
#           Type: intra-node
#  System device: <unknown>
#
#      capabilities:
#            bandwidth: 0.00/ppn + 15360.00 MB/sec
#              latency: 80 nsec
#             overhead: 10 nsec
#            put_short: <= 4294967295
#            put_bcopy: unlimited
#            get_bcopy: unlimited
#             am_short: <= 100
#             am_bcopy: <= 8256
#               domain: cpu
#           atomic_add: 32, 64 bit
#           atomic_and: 32, 64 bit
#            atomic_or: 32, 64 bit
#           atomic_xor: 32, 64 bit
#          atomic_fadd: 32, 64 bit
#          atomic_fand: 32, 64 bit
#           atomic_for: 32, 64 bit
#          atomic_fxor: 32, 64 bit
#          atomic_swap: 32, 64 bit
#         atomic_cswap: 32, 64 bit
#           connection: to iface
#      device priority: 0
#     device num paths: 1
#              max eps: inf
#       device address: 8 bytes
#        iface address: 8 bytes
#       error handling: ep_check
#
#
# Memory domain: posix
#     Component: posix
#             allocate: <= 235268272K
#           remote key: 24 bytes
#           rkey_ptr is supported
#         memory types: host (access,alloc,cache)
#
#      Transport: posix
#         Device: memory
#           Type: intra-node
#  System device: <unknown>
#
#      capabilities:
#            bandwidth: 0.00/ppn + 15360.00 MB/sec
#              latency: 80 nsec
#             overhead: 10 nsec
#            put_short: <= 4294967295
#            put_bcopy: unlimited
#            get_bcopy: unlimited
#             am_short: <= 100
#             am_bcopy: <= 8256
#               domain: cpu
#           atomic_add: 32, 64 bit
#           atomic_and: 32, 64 bit
#            atomic_or: 32, 64 bit
#           atomic_xor: 32, 64 bit
#          atomic_fadd: 32, 64 bit
#          atomic_fand: 32, 64 bit
#           atomic_for: 32, 64 bit
#          atomic_fxor: 32, 64 bit
#          atomic_swap: 32, 64 bit
#         atomic_cswap: 32, 64 bit
#           connection: to iface
#      device priority: 0
#     device num paths: 1
#              max eps: inf
#       device address: 8 bytes
#        iface address: 8 bytes
#       error handling: ep_check
#
#
# Memory domain: mlx5_ib0
#     Component: ib
#             register: unlimited, dmabuf, cost: 180 nsec
#           remote key: 8 bytes
#           local memory handle is required for zcopy
#           memory invalidation is supported
#         memory types: host (access,reg,cache)
#
#      Transport: dc_mlx5
#         Device: mlx5_ib0:1
#           Type: network
#  System device: mlx5_ib0 (0)
#
#      capabilities:
#            bandwidth: 23588.47/ppn + 0.00 MB/sec
#              latency: 660 nsec
#             overhead: 40 nsec
#            put_short: <= 172
#            put_bcopy: <= 8256
#            put_zcopy: <= 1G, up to 11 iov
#  put_opt_zcopy_align: <= 512
#        put_align_mtu: <= 4K
#            get_bcopy: <= 8256
#            get_zcopy: 65..1G, up to 11 iov
#  get_opt_zcopy_align: <= 512
#        get_align_mtu: <= 4K
#             am_short: <= 186
#             am_bcopy: <= 8254
#             am_zcopy: <= 8254, up to 3 iov
#   am_opt_zcopy_align: <= 512
#         am_align_mtu: <= 4K
#            am header: <= 138
#               domain: device
#           atomic_add: 32, 64 bit
#           atomic_and: 32, 64 bit
#            atomic_or: 32, 64 bit
#           atomic_xor: 32, 64 bit
#          atomic_fadd: 32, 64 bit
#          atomic_fand: 32, 64 bit
#           atomic_for: 32, 64 bit
#          atomic_fxor: 32, 64 bit
#          atomic_swap: 32, 64 bit
#         atomic_cswap: 32, 64 bit
#           connection: to iface
#      device priority: 50
#     device num paths: 1
#              max eps: inf
#       device address: 5 bytes
#        iface address: 7 bytes
#       error handling: buffer (zcopy), remote access, peer failure, ep_check
#
#
#      Transport: rc_verbs
#         Device: mlx5_ib0:1
#           Type: network
#  System device: mlx5_ib0 (0)
#
#      capabilities:
#            bandwidth: 23588.47/ppn + 0.00 MB/sec
#              latency: 600 + 1.000 * N nsec
#             overhead: 75 nsec
#            put_short: <= 124
#            put_bcopy: <= 8256
#            put_zcopy: <= 1G, up to 5 iov
#  put_opt_zcopy_align: <= 512
#        put_align_mtu: <= 4K
#            get_bcopy: <= 8256
#            get_zcopy: 65..1G, up to 5 iov
#  get_opt_zcopy_align: <= 512
#        get_align_mtu: <= 4K
#             am_short: <= 123
#             am_bcopy: <= 8255
#             am_zcopy: <= 8255, up to 4 iov
#   am_opt_zcopy_align: <= 512
#         am_align_mtu: <= 4K
#            am header: <= 127
#               domain: device
#           atomic_add: 64 bit
#          atomic_fadd: 64 bit
#         atomic_cswap: 64 bit
#           connection: to ep
#      device priority: 50
#     device num paths: 1
#              max eps: 256
#       device address: 5 bytes
#           ep address: 7 bytes
#       error handling: peer failure, ep_check
#
#
#      Transport: rc_mlx5
#         Device: mlx5_ib0:1
#           Type: network
#  System device: mlx5_ib0 (0)
#
#      capabilities:
#            bandwidth: 23588.47/ppn + 0.00 MB/sec
#              latency: 600 + 1.000 * N nsec
#             overhead: 40 nsec
#            put_short: <= 220
#            put_bcopy: <= 8256
#            put_zcopy: <= 1G, up to 14 iov
#  put_opt_zcopy_align: <= 512
#        put_align_mtu: <= 4K
#            get_bcopy: <= 8256
#            get_zcopy: 65..1G, up to 14 iov
#  get_opt_zcopy_align: <= 512
#        get_align_mtu: <= 4K
#             am_short: <= 234
#             am_bcopy: <= 8254
#             am_zcopy: <= 8254, up to 3 iov
#   am_opt_zcopy_align: <= 512
#         am_align_mtu: <= 4K
#            am header: <= 186
#               domain: device
#           atomic_add: 32, 64 bit
#           atomic_and: 32, 64 bit
#            atomic_or: 32, 64 bit
#           atomic_xor: 32, 64 bit
#          atomic_fadd: 32, 64 bit
#          atomic_fand: 32, 64 bit
#           atomic_for: 32, 64 bit
#          atomic_fxor: 32, 64 bit
#          atomic_swap: 32, 64 bit
#         atomic_cswap: 32, 64 bit
#           connection: to ep
#      device priority: 50
#     device num paths: 1
#              max eps: 256
#       device address: 5 bytes
#           ep address: 10 bytes
#       error handling: buffer (zcopy), remote access, peer failure, ep_check
#
#
#      Transport: ud_verbs
#         Device: mlx5_ib0:1
#           Type: network
#  System device: mlx5_ib0 (0)
#
#      capabilities:
#            bandwidth: 23588.47/ppn + 0.00 MB/sec
#              latency: 630 nsec
#             overhead: 105 nsec
#             am_short: <= 116
#             am_bcopy: <= 4088
#             am_zcopy: <= 4088, up to 5 iov
#   am_opt_zcopy_align: <= 512
#         am_align_mtu: <= 4K
#            am header: <= 3992
#           connection: to ep, to iface
#      device priority: 50
#     device num paths: 1
#              max eps: inf
#       device address: 5 bytes
#        iface address: 3 bytes
#           ep address: 6 bytes
#       error handling: peer failure, ep_check
#
#
#      Transport: ud_mlx5
#         Device: mlx5_ib0:1
#           Type: network
#  System device: mlx5_ib0 (0)
#
#      capabilities:
#            bandwidth: 23588.47/ppn + 0.00 MB/sec
#              latency: 630 nsec
#             overhead: 80 nsec
#             am_short: <= 180
#             am_bcopy: <= 4088
#             am_zcopy: <= 4088, up to 3 iov
#   am_opt_zcopy_align: <= 512
#         am_align_mtu: <= 4K
#            am header: <= 132
#           connection: to ep, to iface
#      device priority: 50
#     device num paths: 1
#              max eps: inf
#       device address: 5 bytes
#        iface address: 3 bytes
#           ep address: 6 bytes
#       error handling: peer failure, ep_check
#
#
# Connection manager: rdmacm
#      max_conn_priv: 54 bytes
#
# Memory domain: cma
#     Component: cma
#             register: unlimited, cost: 9 nsec
#         memory types: host (access,reg_nonblock,reg,cache)
#
#      Transport: cma
#         Device: memory
#           Type: intra-node
#  System device: <unknown>
#
#      capabilities:
#            bandwidth: 0.00/ppn + 11145.00 MB/sec
#              latency: 80 nsec
#             overhead: 2000 nsec
#            put_zcopy: unlimited, up to 16 iov
#  put_opt_zcopy_align: <= 1
#        put_align_mtu: <= 1
#            get_zcopy: unlimited, up to 16 iov
#  get_opt_zcopy_align: <= 1
#        get_align_mtu: <= 1
#           connection: to iface
#      device priority: 0
#     device num paths: 1
#              max eps: inf
#       device address: 8 bytes
#        iface address: 4 bytes
#       error handling: peer failure, ep_check
#
```

</details>

This looks to be memory copy bandwidth:

```bash
$ ucx_info -M
# Using built-in memcpy() for size inf..inf
# Memcpy bandwidth:
#           4096 bytes: 76386.180 MB/s
#           8192 bytes: 89185.127 MB/s
#          16384 bytes: 93675.259 MB/s
#          32768 bytes: 53620.904 MB/s
#          65536 bytes: 51693.470 MB/s
#         131072 bytes: 51912.292 MB/s
#         262144 bytes: 48203.195 MB/s
#         524288 bytes: 43202.249 MB/s
#        1048576 bytes: 36308.450 MB/s
#        2097152 bytes: 36124.949 MB/s
#        4194304 bytes: 36190.920 MB/s
#        8388608 bytes: 36184.046 MB/s
#       16777216 bytes: 36257.343 MB/s
#       33554432 bytes: 36221.641 MB/s
#       67108864 bytes: 36208.731 MB/s
#      134217728 bytes: 29613.116 MB/s
#      268435456 bytes: 27458.495 MB/s
```

Device info:

```console
$ ibv_devinfo 
hca_id: mlx5_ib0
        transport:                      InfiniBand (0)
        fw_ver:                         20.31.1014
        node_guid:                      0015:5dff:fe33:ff2b
        sys_image_guid:                 946d:ae03:0045:397a
        vendor_id:                      0x02c9
        vendor_part_id:                 4124
        hw_ver:                         0x0
        board_id:                       MT_0000000223
        phys_port_cnt:                  1
                port:   1
                        state:                  PORT_ACTIVE (4)
                        max_mtu:                4096 (5)
                        active_mtu:             4096 (5)
                        sm_lid:                 1
                        port_lid:               674
                        port_lmc:               0x00
                        link_layer:             InfiniBand
```
```console
$ ibv_devices 
    device                 node GUID
    ------              ----------------
    mlx5_ib0            00155dfffe33ff2b
```

More devices...

```console
$ flux exec -r 0-1 lspci
0101:00:00.0 Infiniband controller: Mellanox Technologies MT28908 Family [ConnectX-6 Virtual Function]
01e1:00:00.0 Non-Volatile memory controller: Microsoft Corporation Device b111
1e7f:00:00.0 Non-Volatile memory controller: Microsoft Corporation Device b111
0101:00:00.0 Infiniband controller: Mellanox Technologies MT28908 Family [ConnectX-6 Virtual Function]
5e51:00:00.0 Non-Volatile memory controller: Microsoft Corporation Device b111
7718:00:00.0 Non-Volatile memory controller: Microsoft Corporation Device b111
```

And networking.

```console
$ ip link
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP mode DEFAULT group default qlen 1000
    link/ether 00:22:48:aa:35:d1 brd ff:ff:ff:ff:ff:ff
3: ib0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 2044 qdisc mq state UP mode DEFAULT group default qlen 256
    link/infiniband 00:00:01:48:fe:80:00:00:00:00:00:00:00:15:5d:ff:fd:33:ff:2b brd 00:ff:ff:ff:ff:12:40:1b:80:08:00:00:00:00:00:00:ff:ff:ff:ff
    altname ibP257p0s0
    altname ibP257s63111
```

Some software:

```console
$ which mpirun
/opt/hpcx-v2.15-gcc-MLNX_OFED_LINUX-5-ubuntu22.04-cuda12-gdrcopy2-nccl2.17-x86_64/ompi/bin/mpirun
```
```console
$ mpirun --version
mpirun (Open MPI) 4.1.5rc2
Report bugs to http://www.open-mpi.org/community/help/
```
```console
$ gcc --version
gcc (Ubuntu 11.4.0-1ubuntu1~22.04) 11.4.0
Copyright (C) 2021 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
```

### Debugging

Depending on your environment, terraform (e.g., `make` or `make destroy` doesn't always work. I get this error from the Azure Cloud Shell:

```console
terraform destroy
random_pet.id: Refreshing state... [id=usable-grouper]
random_string.fqdn: Refreshing state... [id=lhppiw]
╷
│ Error: building account: could not acquire access token to parse claims: running Azure CLI: exit status 1: ERROR: Failed to connect to MSI. Please make sure MSI is configured correctly.
│ Get Token request returned: <Response [400]>
│ 
│   with provider["registry.terraform.io/hashicorp/azurerm"],
│   on main.tf line 28, in provider "azurerm":
│   28: provider "azurerm" {
│ 
╵
make: *** [Makefile:22: destroy] Error 1
```

If I open a new cloud shell, it seems to magically go away. But you can also interact with the `az` tool (that does seem to to work) or issue commands via clicking directly in the portal.
