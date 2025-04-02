#### General scripts

`run.sl` determines the number of files of a particular name (in the example script they are called `sequence_?.fna`). It then makes sure the number of files and the Slurm array size match. Finally there is a `for` loop that runs the programme on each input file.
