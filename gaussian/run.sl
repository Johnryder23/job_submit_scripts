#!/bin/bash

#SBATCH --job-name=gaussian_shared_memory_job
#SBATCH --account=uoa04034
#SBATCH --time=10:00:00
#SBATCH --cpus-per-task=8
#SBATCH --hint=nomultithread
#SBATCH --mem=8G
#SBATCH --partition=large,milan
#SBATCH --output=/nesi/nobackup/uoa04034/gaussian_job_%j/gaussian_job_%j.out
#SBATCH --error=/nesi/nobackup/uoa04034/gaussian_job_%j/gaussian_job_%j.err

module purge 2> /dev/null
module load Gaussian/09-D.01

INPUT_FILE="H2O.gjf" # Can name this whatever you want, needs to end in .gjf though.
GAUSSIAN_MEM="$((${SLURM_MEM_PER_NODE} - 2048))"

# cd into working directory. Directory created by Slurm '--output'.
cd /nesi/nobackup/uoa04034/gaussian_job_${SLURM_JOB_ID}

# It is recommended to prepare a job-specific scratch directory
export GAUSS_SCRDIR="./scratch_dir"
mkdir -p "${GAUSS_SCRDIR}"

cat << EOF > $INPUT_FILE

%CPU=$(taskset -cp $$ | awk -F':' '{print $2}')
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

echo -e "\nresults from this job are in \n==========================================================\n$(pwd)\n=========================================================="
echo -e "\na copy of the stdout and stderr files will be in home directory too.\n"

cp gaussian_job_*.??? ~/
