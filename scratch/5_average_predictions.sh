#!/bin/bash
script_path=$1

# Slurm settings
job_name=igvf_sc-islet_10X-Multiome_average_predictions
partition=carter-compute
cpus_per_task=5
mem=16G
time="14-00:00:00"
output_path="/cellar/users/aklie/data/datasets/igvf_sc-islet_10X-Multiome/bin/slurm_logs/8_chrombpnet/predictions/%x.%A.out"

# Cmd
cmd="sbatch \
--job-name=$job_name \
--partition=$partition \
--cpus-per-task=$cpus_per_task \
--mem=$mem \
--time=$time \
--output=$output_path \
$script_path"
echo -e "Running command:\n$cmd\n"
eval $cmd
