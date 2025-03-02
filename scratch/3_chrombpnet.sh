#!/bin/bash
script_path=$1
num_array=$2
concurrency=$3

# Slurm settings
job_name=igvf_sc-islet_10X-Multiome_chrombpnet_pipeline
partition=carter-gpu
account=carter-gpu
gpus="a30:1"
cpus_per_task=4
mem=80G
time="14-00:00:00"
array="1-$num_array%$concurrency"
output_path="/cellar/users/aklie/data/datasets/igvf_sc-islet_10X-Multiome/bin/slurm_logs/8_sequence_models/chrombpnet/%x.%A.%a.out"

# Cmd
cmd="sbatch \
--job-name=$job_name \
--partition=$partition \
--account=$account \
--cpus-per-task=$cpus_per_task \
--gpus=$gpus \
--mem=$mem \
--time=$time \
--output=$output_path \
--array=$array \
$script_path"
echo -e "Running command:\n$cmd\n"
eval $cmd
