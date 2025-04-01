#!/bin/bash

name=${1:?}

workdir=vasp_job_${name}

if [ -e ${workdir} ]; then
   echo "Error: ${workdir} already exist. Please choose a different working directory suffix."
   exit 1
done

mkdir ${workdir} && cp $(find . -maxdepth 1 -type f) ${workdir} && cd ${workdir}

### add job allocation settings here ###
export num_threads=2        # max value of 8 with hyperthreading off
export tasks=2              # no max value
export job_time=01:00:00    # no max value
########################################

### check this job script was run by bash and not sbatch ###
if [[ -z "$SLURM_JOB_ID" ]]; then
    echo "Starting Slurm job with ${tasks} MPI tasks and ${num_threads} threads-per-rank in directory ${workdir}."
else
    echo "ERROR: This script was submitted to Slurm. This is a bash script not Slurm script. Submit this script with 'bash <script_name.sh>'"
    exit 1
fi

### ================ Notes on the hardware configuration of Milan nodes ================ ###

## Milan nodes are configured with 8 NUMA domains (verify by running 'numactl -H' on compute node) and 16 Slurm sockets.
## All mention of 'sockets' here is referring to Slurm sockets, not the actual socket hardware component.
## There are 16 sockets because there is one socket per L3 cache ('l3cache_as_socket' in /etc/opt/slurm/slurm.conf).
## So a Milan node has:
##   8 NUMA domains
##   16 sockets
##   2 sockets-per-NUMA-domain
##   8 physical cores-per-socket.
## We want all CPUs (threads) of a rank to share a socket (and therefore cache).
## To do this we set 1 task-per-socket, and cpus-per-task=cores-per-socket=8 IF our problem scales well with this number of threads.

## NeSI's current Slurm version does not support the '--tres-bind' sbatch parameter. When it does '--tres-bind=gres/CPU:closest' should be looked at.

## --cpus-per-task       # Must match '--cores-per-socket'. Max value of 8.
## --distribution        # Specify distribution in terms of "tasks to nodes:CPUs across sockets for binding:CPUs across cores"
## --ntasks              # Can be any number.
## --ntasks-per-socket   # Keep threads of a rank on the same socket. Must be 1 if --cpus-per-task=8. Can be n where n*cpus-per-task ≤ 8 otherwise.
## --cores-per-socket    # Must match --cpus-per-task. Max value of 8.
## --threads-per-core    # turn off multithreading
## --mem-bind=local      # Use memory local to the processor in use
## --switches            # maximum number of leaf switches for the job and the maximum time willing to wait for that number (see output of 'scontrol show topo').

sbatch \
--job-name=${name} \
--account=nesi99999 \
--time=${job_time} \
--cpus-per-task=${num_threads} \
--cores-per-socket=${num_threads} \
--partition=milan \
--distribution=*:block:* \
--ntasks=${tasks} \
--ntasks-per-socket=1 \
--threads-per-core=1 \
--mem-per-cpu=1G \
--mem-bind=local  \
--switches=1@04:00:00 \
--acctg-freq=15 \
<<'EOF'
#!/bin/bash

module purge 2> /dev/null
module load VASP/6.4.2-intel-2022a


if [ -e ./sample_binding.sh ]; then
   srun --job-name=binding_report bash -c 'echo "This VASI am task #${SLURM_PROCID} running on node $(hostname) with $(nproc) CPUs $(taskset -c -p $$)"'
   #####srun -K1 vasp_std &
   #sleep for a bit to let procs initialize
   sleep 45
   bash sample_binding.sh > binding_report_${SLURM_JOB_ID} 2>&1
   wait
else
   echo "WARNING: 'sample_binding.sh' not in current directory so binding will not be printed. Now running VASP..."
   #srun -K1 vasp_std
fi

EOF
