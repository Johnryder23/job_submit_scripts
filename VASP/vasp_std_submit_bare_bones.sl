#!/bin/bash -e

#SBATCH --ntasks=21
#SBATCH --cpus-per-task=4
#SBATCH --job-name=my_VASP_job
#SBATCH --time=01:00:00
#SBATCH --mem-per-cpu=950
#SBATCH --account=nesi99999
#SBATCH --extra-node-info=1:*:*     # Restrict node selection to nodes with at least 1 completely free socket.
#SBATCH --distribution=*:block:*    # Bind tasks to CPUs on the same socket, and fill that socket before moving to the next consecutive socket.
#SBATCH --threads-per-core=1        # Turn off simultaneous multithreading (hyperthreading).
#SBATCH --mem-bind=local
#SBATCH --profile=task
#SBATCH --acctg-freq=15

## There are few reasons to specify `#SBATCH --partition` on the new HPC. Please only set this if you have a good reason to use Genoa or Milan nodes.

module purge 2> /dev/null
module load VASP/6.4.2-foss-2023a

# update vasp job log once job starts running.
echo "Job ${SLURM_JOB_ID} was submitted on $(date) from directory $(pwd)" >> ~/VASP_job_log.txt

# Start two job steps, one that prints proc binding and the other starts VASP.
srun --job-name=print_binding_stats bash -c "echo -e \"Task #\${SLURM_PROCID} is running on node \$(hostname). \n\$(hostname) has the following NUMA configuration:\n\$(lscpu | grep -i --color=none numa)\nTask #\${SLURM_PROCID} has \$(nproc) CPUs, their core IDs are \$(taskset -c -p \$\$ | awk '{print \$NF}')\n===========================================\""
echo -e "\n====== Finished printing CPU binding information, now launching VASP ======\n"
srun -K1 vasp_std

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
## --extra-node-info=1:*:*      To ensure your job does not share a Slurm socket with other jobs we restrict node selection to nodes with at least 1 socket that has all (*) cores and threads available.
## --distribution=*:block:*     Bind tasks to CPUs on the same Slurm socket, and fill that socket before moving to the next consecutive socket. Multiple tasks will share a socket as long as cpus-per-task*ntasks < physical cores-per-Slurm socket.
## --threads-per-core=1         Disable hyperthreding. In other words, don't let cores appear to have two CPUs.
## --mem-bind=local             Use memory local to the processor in use. The OS should do this anyway but does not hurt to include.

### ==================================================================================== ###
