#!/bin/bash -e

### edit job allocation settings here ###
export tasks=10                       # Number of MPI tasks. No max value, any integer ≥ 1.
export num_threads=8                  # Number of CPUs per-MPI-task. Max value of 8 with hyperthreading off.
export SBATCH_JOB_NAME="my_VASP_job"  # job name that will appear along with the job id number from 'squeue'
export SBATCH_TIMELIMIT=05:00:00      # no max value.
export vasp_executable="vasp_std"     # which VASP binary to run.
export SBATCH_MEM_PER_CPU="2000"      # memory-per-CPU.
export SBATCH_PARTITION="milan"       # Slurm partition. This will be overridden if GPU(s) are requested.
export SBATCH_ACCOUNT="nesi99999"     # NeSI project allocation to bill job to.
export SBATCH_GPUS_PER_TASK="A100:0"  # type and number of GPUs used in the job. Use '<type>:0' for CPU only calculation.
### ===============================  ###

# check working directory name has been provided and print error message if not.
if [ -z "$1" ]; then
  echo -e "Error: No working directory name provided. You must provide a working directory name as the first argument after this script.\nFor example 'bash <script_name.sh> <directory_name>'" >&2
  exit 1
fi
name="$1"

# check working directory does not already exist.
workdir=vasp_job_${name}
if [ -e ${workdir} ]; then
   echo "Warning: ${workdir} already exist. Do you want to overwrite it? (y/n):"
   read -t 15 overwrite
   if [ "${overwrite}" = "y" ]; then
       echo "overwriting some or all files in ${workdir}"
       mkdir -p ${workdir} && find . -maxdepth 1 -type f -exec cp -v '{}' ${workdir} \; && cd ${workdir}
   fi
   if [ "${overwrite}" = "n" ]; then
       echo "Not overwriting ${workdir} and exiting..."
       exit 1
   fi
fi

# if this is a GPU job set the partition name (required) and check tasks:GPU ratio is 1.
if [ "${SBATCH_GPUS_PER_TASK##*:}" -gt 0 ]; then
    export SBATCH_PARTITION="hgx,gpu"
    if  [ "${SBATCH_GPUS_PER_TASK##*:}" -gt 0 ] && [ "${tasks}" -ne "${SBATCH_GPUS_PER_TASK##*:}" ]; then
        echo "Error: Number of MPI tasks (${tasks}) is not equal to the nuumber of GPUs on the node (${SBATCH_GPUS_PER_TASK##*:}). Exiting."
        exit 1
    fi
fi

# check this job script was run by bash and not sbatch
if [ -z "$SLURM_JOB_ID" ]; then
    echo "Starting Slurm job with ${tasks} MPI tasks and ${num_threads} threads-per-task in directory ${workdir}. '~/VASP_job_log.txt' will be updated once the job starts."
else
    echo "ERROR: This script was submitted to Slurm. This is a bash script not Slurm script. Submit this script with 'bash <script_name.sh> <working directory suffix (string)>'"
    exit 1
fi

# submit job with 'sbatch'
sbatch \
--cpus-per-task=${num_threads} \
--cores-per-socket=${num_threads} \
--distribution=*:block:* \
--ntasks=${tasks} \
--ntasks-per-socket=1 \
--threads-per-core=1 \
--mem-bind=local \
--switches=1@04:00:00 \
--profile=task \
--acctg-freq=15 \
<<'EOF'
#!/bin/bash

module purge 2> /dev/null
module load VASP/6.4.2-foss-2023a

echo "Job ${SLURM_JOB_ID} was submitted on $(date) from directory $(pwd)" >> ~/VASP_job_log.txt

if [ "${SBATCH_GPUS_PER_TASK##*:}" -gt 0 ]; then
    echo -e "GPUs used is this job are \n$(nvidia-smi -L)\n"
fi

srun --job-name=print_binding_stats bash -c "echo -e \"Task #\${SLURM_PROCID} is running on node \$(hostname). \n\$(hostname) has the following NUMA configuration:\n\$(lscpu | grep -i --color=none numa)\nTask #\${SLURM_PROCID} has \$(nproc) CPUs, their core IDs are \$(taskset -c -p \$\$ | awk '{print \$NF}')\n===========================================\""

echo -e "\n====== Finished printing CPU binding information, now launching ${vasp_executable} ======\n"
srun -K1 ${vasp_executable}

EOF


### ================ Notes on the hardware configuration of Milan nodes ================ ###

## Milan nodes are configured with 8 NUMA domains (verify by running 'numactl -H' on a Milan node) and 16 Slurm sockets.
## All mention of 'sockets' here is referring to Slurm sockets, not the actual socket hardware component.
## There are 16 sockets because there is one socket per L3 cache ('l3cache_as_socket' in /etc/opt/slurm/slurm.conf).
## So a Milan node has:
##   8 NUMA domains
##   16 sockets
##   2 sockets-per-NUMA-domain
##   8 physical cores-per-socket.
## We want all threads (enumerated by cpus-per-task) of a task to share a socket (and therefore cache).
## To do this we set 1 task-per-socket, and cpus-per-task=cores-per-socket=8 IF our problem scales well with this number of threads.

## NeSI's current Slurm version does not support the '--tres-bind' sbatch parameter. When it does '--tres-bind=gres/CPU:closest' should be looked at.

## --cpus-per-task       # Must match '--cores-per-socket'. Max value of 8.
## --distribution        # Specify distribution in terms of "tasks to nodes:CPUs across sockets for binding:CPUs across cores"
## --ntasks              # Can be any number.
## --ntasks-per-socket   # Keep threads of a task on the same socket. Must be 1 if --cpus-per-task=8. Can be n where n*cpus-per-task ≤ 8 otherwise.
## --cores-per-socket    # Must match --cpus-per-task. Max value of 8.
## --threads-per-core    # turn off multithreading
## --mem-bind=local      # Use memory local to the processor in use
## --switches            # maximum number of leaf switches for the job and the maximum time willing to wait for that number (see output of 'scontrol show topo').

### ==================================================================================== ###

