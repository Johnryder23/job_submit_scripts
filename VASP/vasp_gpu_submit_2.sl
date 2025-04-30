#!/bin/bash -e

##General
#SBATCH --partition=hgx,gpu
#SBATCH --gpus-per-task=A100:1   # You can change the 'type' GPU, but do not change the number of gpus-per-task.
#SBATCH --job-name=john_testing
#SBATCH --account=nesi99999
#SBATCH --time=01:00:00
#SBATCH --output=vasp_job_%j/job_%j.out

##Parallel options
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1        # We recommend experimenting with this value. for example set NELM=5 and NSW=3 (or something small) in the INCAR and check how long calculation takes to finish. Can also check CPU efficiency after the job has finished with nn_seff <job_id>
#SBATCH --mem=80G
#####SBATCH --hint=nomultithread
#SBATCH --profile=task
#SBATCH --acctg-freq=5

# Check that ntasks is the same as the number of GPUs, if not exit with error
if [ "${SLURM_NTASKS}" -ne "${SLURM_GPUS_ON_NODE}" ]; then
  echo "Error: Number of MPI tasks (${SLURM_NTASKS}) is not equal to the nuumber of GPUs on the node (${SLURM_GPUS_ON_NODE}). Exiting."
  exit 1
fi

# Copy all files in current directory to the working directory
cp $(find . -maxdepth 1 -type f) vasp_job_${SLURM_JOB_ID}
cd vasp_job_${SLURM_JOB_ID}

# debug info
echo "DEBUG INFO"
echo "======================================================================================="
if [ "${SLURM_GPUS_ON_NODE}" -gt 0 ]; then
   echo -e "GPU(s)?: YES, they are \n$(nvidia-smi -L)\n"
else
   echo "GPU(s)? NO, GPUs not used for this job"
fi
echo "cluster:                             $SLURM_CLUSTER_NAME"
echo "job ID:                              $SLURM_JOBID"
echo "node count:                          $SLURM_NNODES, nodelist is $SLURM_NODELIST"
echo "MPI tasks:                           $SLURM_NPROCS"
echo "MPI tasks per node:                  $SLURM_TASKS_PER_NODE"
echo "CPUs per tasks:                      $SLURM_CPUS_PER_TASK"
echo "partition:                           $SLURM_JOB_PARTITION"
echo "directory from which sbatch was run: $SLURM_SUBMIT_DIR"
echo "each band (analogously, orbital) has ${OMP_NUM_THREADS} OpenMP threads, and therefore is worked on by ${OMP_NUM_THREADS} CPUs."
echo -e "=======================================================================================\n\n"

# sometimes the following is needed to supress warning messages
#export NO_STOP_MESSAGE=1

module purge 2> /dev/null
module load VASP/6.3.2-NVHPC-22.3-GCC-11.3.0-CUDA-11.6.2
###module load VASP/6.2.1-NVHPC-22.3-GCC-11.3.0-CUDA-11.6.2

echo "---- This Job started on $(date) ----"
srun -K1 vasp_std
echo "---- This Job finished on $(date) ----"


