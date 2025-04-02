#!/bin/bash -e

#SBATCH --job-name=H2O_distributed_memory
#SBATCH --account=nesi99999
#SBATCH --time=00:15:00
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=4
#SBATCH --hint=nomultithread
#SBATCH --mem=4G

module load Gaussian/09-D.01

INPUT_FILE="H2O.gjf"

GAUSSIAN_MEM="$((${SLURM_MEM_PER_NODE} - 2048))"

# It is reconmended to prepare a job-specific scratch directory
export GAUSS_SCRDIR="/nesi/nobackup/${SLURM_JOB_ACCOUNT}/gaussian_job_${SLURM_JOB_ID}"
mkdir -p "${GAUSS_SCRDIR}"

cat << EOF > $INPUT_FILE

%LindaWorkers=$(for n in $(srun hostname | sort -u);do printf "${n}:${SLURM_NPROCS},"; done)
%Mem=${GAUSSIAN_MEM}MB
%Chk=${INPUT_FILE}.chk

# HF/6-31G(d) Opt=ModRedun Test

water geo optimisation HF/6-31G(d)

0 1
H
O 1 0.95
H 2 0.95 1 109.0


EOF

srun g09 < "${INPUT_FILE}"
