#!/bin/bash -e

if [ ! -n ${SLURM_JOB_ID+x} ]; then
    echo "ERROR: seems you have submitted this script to Slurm. This is a bash script, not a Slurm script. Please submit with 'bash <this_script>'"
    exit 1
fi

calc_paths=($(find . -type f -name "INCAR" -exec dirname {} \;))
echo -e "Message: running VASP in each of the following directories:"
echo "${calc_paths[@]}" | tr " " "\n"
echo -e "\nMessage: each calculation will run as an array job under the parent job ID given below:"

sbatch --array=0-$((${#calc_paths[@]}-1)) \
--job-name=vasp_bulk_submission \
--account=nesi99999 \
--time=01:00:00 \
--nodes=1 \
--ntasks=16 \
--hint=nomultithread \
--mem=3G \
<<'EOF'
#!/bin/bash -e

module load VASP.xx.xx

# no parameter substitution because EOF is in quotes so need to set 'calc_paths' again. i.e., everything enclosed by EOF is submitted as is to the sbatch command.
calc_paths=($(find . -type f -name "INCAR" -exec dirname {} \;))
cd ${calc_paths[SLURM_ARRAY_TASK_ID]}

echo -e "Message: This output is from the job in $(pwd). Upon successfull job completion, this output file will be moved to $(pwd)\n"
echo -e "Message: this is job array number ${SLURM_ARRAY_TASK_ID} of parent job ${SLURM_JOB_ID}\n"

srun -K1 vasp_std

mv ../slurm_${SLURM_JOB_ID}_${SLURM_ARRAY_ID}.out .

EOF
