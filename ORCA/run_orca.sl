#!/bin/bash
#SBATCH --job-name=my_ORCA_job
#SBATCH --time=01:00:00
#SBATCH --account=nesi99999
#SBATCH --nodes=1
#SBATCH --ntasks=16
#SBATCH --hint=nomultithread
#SBATCH --mem-per-cpu=3G
#SBATCH --partition=large,milan,long
#SBATCH --output=orca_job_%j/slurm-%j.out

module purge 2>/dev/null
module use /nesi/nobackup/nesi99999/whitingj/easybuildinstall/CS400_centos7_bdw/modules/all/
module load ORCA/6.0.1-OpenMPI-4.1.5

INPUT_FILE=input.inp

# ORCA under MPI requires that it be called via its full absolute path
orca_exe=$(which orca)
echo "job will be run in the temporary directory ${TMPDIR}"
cd ${TMPDIR}

ORCA_mem_int=$(echo "scale=0; 0.75 * ${SLURM_MEM_PER_CPU} / 1" | bc)
echo "the memory set in %maxcore will be ${ORCA_mem_int} MB"

cat << EOF > $INPUT_FILE

! Opt B3LYP D3 def2-TZVP def2/J RIJCOSX TIGHTSCF SlowConv noautostart miniprint nopop
%pal nprocs ${SLURM_NTASKS} end
%maxcore ${ORCA_mem_int}
%basis newECP Rh "def2-SD" end end
* xyz 0 1
N         -0.83911        0.76325       -0.31843
C          0.61442        0.72014       -0.25075
C          1.01669       -0.56167        0.49740
O          0.20095       -1.36984        0.93753
H         -1.37884        0.05803        0.17605
H          1.00414        0.66192       -1.27362
C          1.17285        1.95192        0.45211
H          0.87124        2.87150       -0.05988
H          0.81191        2.01288        1.48492
H          2.26726        1.92903        0.48485
H         -1.30551        1.57618       -0.71069
O          2.33980       -0.77979        0.66176
H          3.04559       -0.08055        0.28096
*

EOF

echo "====================================printing input file===================================="
cat $INPUT_FILE
echo "====================================end of input file===================================="

# Don't use "srun" as ORCA does that itself when launching its MPI process. 
${orca_exe} ${INPUT_FILE}

cp -r ./* ${SLURM_SUBMIT_DIR}/orca_job_${SLURM_JOB_ID}
