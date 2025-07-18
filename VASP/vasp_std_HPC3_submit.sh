#!/bin/bash -e

### edit job allocation settings here ###
export tasks=4                        # Number of MPI tasks. No max value, any integer ≥ 1.
export num_threads=21                 # Number of CPUs per-MPI-task. Max value of 21 with hyperthreading off. If less than 10, multiple MPI tasks will share a socket.
export SBATCH_JOB_NAME="my_VASP_job"  # job name that will appear in the queue.
export SBATCH_TIMELIMIT=05:00:00      # Walltime. Max value enforced by Slurm limits.
export vasp_executable="vasp_std"     # which VASP binary to run.
export SBATCH_MEM_PER_CPU="2000"      # memory-per-CPU.
export partition=""                   # Slurm partition. Leave empty unless you have a good reason to specify.
export SBATCH_ACCOUNT="nesi99999"     # NeSI project to bill job to.
export SBATCH_GPUS_PER_TASK="none"    # Set to "<type>:<count>", e.g., "A100:1" for GPU jobs, or "none" for CPU-only jobs. Cannot be unset, must stay as "none" if no GPUs are needed.
### ===============================  ###

workdir="$1"

# check this job script was run by bash and not sbatch
if [ -z "${SLURM_JOB_ID}" ]; then
    echo "Setting up a Slurm job with ${tasks} MPI tasks and ${num_threads} threads-per-task in directory './${workdir}'. '~/VASP_job_log.txt' will be updated once the job starts..."
else
    echo "ERROR: This script was submitted directly to Slurm. This is a bash script, not Slurm script. Submit this script with 'bash <script_name.sh> <working directory suffix>'."
    exit 1
fi

# check working directory name has been provided and print error message if not.
if [ -z "$1" ]; then
  echo -e "Error: No working directory name provided. You must provide a working directory name as the first argument after this script.\nFor example 'bash <script_name.sh> <directory_name>'" >&2
  exit 1
fi

# if this is a GPU job check MPI tasks:GPU ratio is 1.
if [[ "${SBATCH_GPUS_PER_TASK}" != "none" ]]; then
    gpu_count="${SBATCH_GPUS_PER_TASK##*:}"
    if [ "${gpu_count}" -gt 0 ] && [ "${tasks}" -ne "${gpu_count}" ]; then
        echo "Error: Number of MPI tasks (${tasks}) must equal number of GPUs (${gpu_count}). Exiting."
        exit 1
    fi
fi

# set partition if defined
if [ -n "${partition}" ]; then
    export SBATCH_PARTITION=${partition}
fi

# check working directory does not already exist.
if [ -e ${workdir} ]; then
   echo "Warning: ${workdir} already exist. Do you want to overwrite it? (y/n):"
   read -r overwrite
   if [ "${overwrite}" = "y" ]; then
       diff -sq ./ ${workdir}
       echo "Copying the following files to ${workdir} (and possibly overwriting them in line with output above):"
       mkdir -p ${workdir} && find . -maxdepth 1 -type f -exec cp -v '{}' ${workdir} \; && cd ${workdir}
   fi
   if [ "${overwrite}" = "n" ]; then
       echo "Not overwriting ${workdir} and exiting..."
       exit 1
   fi
else
   mkdir -p ${workdir} && find . -maxdepth 1 -type f -exec cp -v '{}' ${workdir} \; && cd ${workdir}
fi

# submit job with 'sbatch'
sbatch \
--cpus-per-task=${num_threads} \
--extra-node-info=1:*:1 \
--distribution=*:block:* \
--ntasks=${tasks} \
--mem-bind=local \
--profile=task \
--acctg-freq=15 \
<<'EOF'
#!/bin/bash

module purge 2> /dev/null
module load VASP/6.4.2-foss-2023a

echo "Job ${SLURM_JOB_ID} was submitted on $(date) from directory $(pwd)" >> ~/VASP_job_log.txt

if [ "${SBATCH_GPUS_PER_TASK}" != "none" ]; then
   echo -e "GPUs used in this job are \n$(nvidia-smi -L)\n"
   fi
fi

srun --job-name=print_binding_stats bash -c "echo -e \"Task #\${SLURM_PROCID} is running on node \$(hostname). \n\$(hostname) has the following NUMA configuration:\n\$(lscpu | grep -i --color=none numa)\nTask #\${SLURM_PROCID} has \$(nproc) CPUs, their core IDs are \$(taskset -c -p \$\$ | awk '{print \$NF}')\n===========================================\""

echo -e "\n====== Finished printing CPU binding information, now launching ${vasp_executable} ======\n"
srun -K1 ${vasp_executable}

EOF

### ================ Notes on the hardware configuration of NeSI compute nodes ================ ###
## Genoa
## Genoa nodes are partitioned into 8 NUMA domains. You can verify the number of NUMA domains by running "srun --partition=genoa numactl -H"
## Each NUMA domain has 3 CCDs, 3 memory controllers, and 1 I/O hub.
## A Genoa node has:
##   8 NUMA domains
##   21 physical cores per NUMA domain.

## Milan
## Milan nodes are partitioned into 8 NUMA domains. You can verify the number of NUMA domains by running "srun --partition=milan numactl -H"
## Each NUMA domain has 3 CCDs, 3 memory controllers, and 1 I/O hub.
## A Milan node has:
##   8 NUMA domains
##   16 physical cores per NUMA domain.

## We want all cpus-per-task (i.e., threads of a rank) to share a NUMA domain as this improves data locality between CPUs. This is critically important given optimization (and related FFTs) of a particular orbital are dominated by floating point operations which require quick access to data stored in cache/RAM.
## Note!!! Slurm socket = NUMA domain. i.e, they are set the the same size in the Slurm config.
## Data locality settings:
## --extra-node-info=1:*:1      To ensure your job does not share a Slurm socket with other jobs we restrict node selection to nodes with at least 1 socket that has all (*) cores available. 1 thread is assigned per-core such that simultaneous multithreading is disabled.
## --distribution=*:block:*     Bind tasks to CPUs on the same Slurm socket, and fill that socket before moving to the next consecutive socket. Multiple tasks will share a socket as long as cpus-per-task*ntasks < physical cores-per-Slurm socket.
## --mem-bind=local             Use memory local to the processor in use. The OS should do this anyway but does not hurt to include.

### ==================================================================================== ###
