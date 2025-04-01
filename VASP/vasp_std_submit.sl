#!/bin/bash -e

#SBATCH --job-name=binding_testing
#SBATCH --account=nesi99999
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=2
#SBATCH --partition=milan
#SBATCH --nodes=1
#SBATCH --distribution=block:block:*   # Specify distribution in terms of "distribution of tasks across nodes:distribution of CPUs across sockets:distribution of CPUs across cores"
#SBATCH --extra-node-info=1:8:1        # sockets-per-node:cores-per-socket:threads-per-core
#SBATCH --mem=5G
#SBATCH --mem-bind=local               # Use memory local to the processor in use
#SBATCH --switches=1@04:00:00          # maximum number of leaf switches for the job as well as a maximum time willing to wait for that number (see output of 'scontrol show topo').
#SBATCH --output=vasp_job_%j/job_%j.out
#SBATCH --acctg-freq=10

# '--extra-node-info' - make job allocation of size 'sockets:cores per socket:threads per core'.
# Milan nodes are configured with 8 NUMA domains (verify by running 'numactl -H' on compute node) and 16 Slurm sockets (because 'l3cache_as_socket' in /etc/opt/slurm/slurm.conf).
# i.e., there are 8 physical cores per L3 cache, so there are 128/8=16 sockets and 8 cores-per-socket.
# Summary for Milan hardware:
#   16 cores-per-NUMA domain.
#   16 sockets (as defined by Slurm)
#   8 cores-per-socket
# We want any interger number of sockets (up to 16), 8 (and always 8) cores-per-socket, and 1 threaad-per-core.
# Requesting resources this way ensures you request in whole NUMA domains, and not parts of a domain.
# '--extra-node-info' will implicitly set the number of tasks (if --ntasks is not specified) as one task per requested thread.

# NeSI's current Slurm version does not support the '--tres-bind' sbatch parameter. When it does '--tres-bind=gres/CPU:closest' should be looked at.


# Copy all files in current directory to a working directory, as to not clutter current directory
cp $(find . -maxdepth 1 -type f) vasp_job_${SLURM_JOB_ID}
cd vasp_job_${SLURM_JOB_ID}

module purge 2> /dev/null
module load VASP/6.4.2-foss-2023a

if [ -e ./report_binding.sh ]; then
   srun -K1 vasp_std &
   sleep 15
   bash report_binding.sh > binding_report_${SLURM_JOB_ID} 2>&1
   wait
else
   echo "WARNING: report_binding.sh not in current directory so binding will not be printed."
   srun -K1 vasp_std
fi
