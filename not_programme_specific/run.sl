#!/bin/bash -e

#SBATCH --account       nesi99999
#SBATCH --job-name      sequencing
#SBATCH --time          00:10:00
#SBATCH --array         1-8            # array size must match the number of sequences!
#SBATCH --mem           5G
#SBATCH --cpus-per-task 2
#SBATCH --output        ./job_%j/slurm_%j.out

module purge 2>/dev/null
module load Java

# Check if and array size is correct and sequence files can be found - exit with error otherwise
num_seq_files=$(find . -name "sequence_?.fna" | wc -l)
array_size=${SLURM_ARRAY_TASK_MAX}

if (( ${num_seq_files} >= 2 )); then
    echo -e "carrying on comparing '${num_seq_files}' sequence files in the current directory.\n"
else
    echo -e "ERROR: either not enough sequence files or they can not be found.\nSequence files should be in: ${pwd}\nand be named in the format 'sequence_n.fna' where n is any interger 2 or greater. There are ${num_seq_files} files in ${pwd}"
    exit 1
fi

if [[ ${num_seq_files} == ${array_size}  ]]; then
    echo "array size and sequence file count match. Continuing..."
else
    echo "ERROR: array size and sequence file count do not match. Array size is ${array_size} and number of sequence files is ${num_seq_files}."
    exit 1
fi

index1=${SLURM_ARRAY_TASK_ID}
seq_file=sequence_${index1}.fna

for x in *.fna; do
    [[ $x == $seq_file ]] && continue
    basename="${x%%.*}"
    index2=${basename##*_}
    output_file="alignment_${index1}_${index2}.xmfa"
    output_guide_file=guide_tree_${index1}_${index2}.txt
    echo "./progressiveMauve --output=${output_file} --output-guide-tree=${output_guide_file} --seed-family ${seq_file} ${x}"
done

echo -e "\n------------- finished run with sequence_${index1} and sequence_${index2} -------------"
