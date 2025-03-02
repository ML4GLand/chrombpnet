#!/bin/bash
script_path=$1
num_array=$2
concurrency=$3

# Slurm settings
job_name=igvf_sc-islet_10X-Multiome_negatives
partition=carter-compute
cpus_per_task=1
mem=16G
time="14-00:00:00"
array="1-$num_array%$concurrency"
output_path="/cellar/users/aklie/data/datasets/igvf_sc-islet_10X-Multiome/bin/slurm_logs/8_chrombpnet/negatives/%x.%A.%a.out"

# Cmd
cmd="sbatch \
--job-name=$job_name \
--partition=$partition \
--account=$account \
--cpus-per-task=$cpus_per_task \
--mem=$mem \
--time=$time \
--output=$output_path \
--array=$array \
$script_path"
echo -e "Running command:\n$cmd\n"
eval $cmd
