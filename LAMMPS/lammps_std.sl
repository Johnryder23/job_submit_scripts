#!/bin/bash -e
#SBATCH --job-name=LAMMPS_job
#SBATCH --account=nesi99999
#SBATCH --partition=bigmem,hugemem,large,milan
#SBATCH --time=01:00:00
#SBATCH --ntasks=8
#SBATCH --cpus-per-task=2
#SBATCH --nodes=1
#SBATCH --mem=50G
#SBATCH --hint=nomultithread
#SBATCH --output=lammps_job_%j/job_%j.out
#SBATCH --profile=task
#SBATCH --acctg-freq=1

module purge 2> /dev/null
module load LAMMPS/23Jun2022-gimkl-2022a-kokkos-EChemDID

# Copy all files in current directory to a working directory, as to not clutter current directory
cp $(find . -maxdepth 1 -type f) lammps_job_${SLURM_JOB_ID}
cd lammps_job_${SLURM_JOB_ID}

ulimit -c unlimited

srun -n ${SLURM_NTASKS} lmp -in input.in
