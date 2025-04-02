#!/bin/bash
#SBATCH --job-name=John_testing
#SBATCH --nodes=1
#SBATCH --time=00:10:00
#SBATCH --ntasks=16
#SBATCH --hint=nomultithread
#SBATCH --cpus-per-task=1
#SBATCH --mem=10G
#SBATCH --output=./RESULTS/slurm-%j.out

module purge 2> /dev/null
module load QuantumESPRESSO/7.2-intel-2022a

#--------------------------------------------------------------------------------
#set the needed environment variables, edit as needed.
export ESPRESSO_PSEUDO="/nesi/nobackup/nesi99999/whitingj/pseudopotentials"
export ESPRESSO_TMPDIR='./RESULTS'

#give a name to your input file that will be created below
export INPUT_FILE='pw_scf_calc.in'

#specify which pseudopotential file to use
PSEUDO_FILE='Si.pbe-n-rrkjus_psl.1.0.0.UPF'

#set QE program do you wish to use, avail options and documentation at 'https://www.quantum-espresso.org/documentation/input-data-description/'
QE_PROGRAM='pw.x'

BIN_DIR=$(echo $PATH | tr ":" "\n" | grep --color=none "QuantumESPRESSO")
#--------------------------------------------------------------------------------

echo -e "executables from:                    $BIN_DIR"
echo -e "looking for pseudopotentials in:     $ESPRESSO_PSEUDO"
echo -e "checking pseudopotential and bin directories exist...\n"
for DIR in "$BIN_DIR" "$ESPRESSO_PSEUDO" ; do
    if test ! -d $DIR ; then
        echo "ERROR: $DIR not existent or not a directory"
        echo "Aborting"
        exit 1
    fi
done
# In case of mixed MPI / OpenMP parallelization you may want to limit
# the maximum number to OpenMP threads so that the number of threads
# per MPI process times the number of MPI processes equals the number
# of available cores to avoid hyperthreading
OMP_NUM_THREADS=1

#................................................................................
#create QE input file, edit as needed
cat > $INPUT_FILE << EOF
 &control
    calculation = 'scf'
    restart_mode='from_scratch',
    tstress = .true.
    tprnfor = .true.
 /
 &system
    ibrav=  2, celldm(1) =10.20, nat=  2, ntyp= 1,
    ecutwfc =18.0,
 /
 &electrons
    diagonalization='david'
    mixing_mode = 'plain'
    mixing_beta = 0.7
    conv_thr =  1.0d-8
 /
ATOMIC_SPECIES
 Si  28.086  $PSEUDO_FILE
ATOMIC_POSITIONS alat
 Si 0.00 0.00 0.00
 Si 0.25 0.25 0.25
K_POINTS
  10
   0.1250000  0.1250000  0.1250000   1.00
   0.1250000  0.1250000  0.3750000   3.00
   0.1250000  0.1250000  0.6250000   3.00
   0.1250000  0.1250000  0.8750000   3.00
   0.1250000  0.3750000  0.3750000   3.00
   0.1250000  0.3750000  0.6250000   6.00
   0.1250000  0.3750000  0.8750000   6.00
   0.1250000  0.6250000  0.6250000   3.00
   0.3750000  0.3750000  0.3750000   1.00
   0.3750000  0.3750000  0.6250000   3.00
EOF
#................................................................................


echo -e 'running job...\n'
# execute QE
srun $QE_PROGRAM < $INPUT_FILE > $ESPRESSO_TMPDIR/calc_results.out

echo 'job finished'

