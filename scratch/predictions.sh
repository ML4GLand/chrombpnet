#!/bin/bash

# Default values
DEFAULT_JOB_NAME="predictions"
DEFAULT_PARTITION="carter-gpu"
DEFAULT_ACCOUNT="carter-gpu"
DEFAULT_GPUS="1"
DEFAULT_CPUS_PER_TASK=4
DEFAULT_MEM="32G"
DEFAULT_TIME="14-00:00:00"
DEFAULT_OUTPUT_PATH="./"

# Help message
usage() {
    echo "Usage: $0 [-s script_path] [-j job_name] [-p partition] [-a account] [-g gpus] [-c cpus_per_task] [-m mem] [-t time] [-o output] [-n num_array] [-x concurrency]"
    echo "Options:"
    echo "  -s  Path to the script to be submitted (required)"
    echo "  -j  Job name (default: $DEFAULT_JOB_NAME)"
    echo "  -p  Partition (default: $DEFAULT_PARTITION)"
    echo "  -a  Account (default: $DEFAULT_ACCOUNT)"
    echo "  -g  GPUs (default: $DEFAULT_GPUS). You can specify a int number of GPUs or a GPU type (e.g. a30:1)"
    echo "  -c  CPUs per task (default: $DEFAULT_CPUS_PER_TASK)"
    echo "  -m  Memory allocation (default: $DEFAULT_MEM)"
    echo "  -t  Time limit (default: $DEFAULT_TIME)"
    echo "  -o  Output path (default: $DEFAULT_OUTPUT_PATH). SLURM log files will be written to this path with %x.%A.%a.out format"
    echo "  -n  Number of array jobs (required)"
    echo "  -x  Concurrency limit for array jobs (required)"
    echo "  -h  Show this help message"
    exit 1
}

# Parse command-line arguments
while getopts "s:j:p:a:g:c:m:t:o:n:x:h" opt; do
    case ${opt} in
        s) script_path=$OPTARG ;;
        j) job_name=$OPTARG ;;
        p) partition=$OPTARG ;;
        a) account=$OPTARG ;;
        g) gpus=$OPTARG ;;
        c) cpus_per_task=$OPTARG ;;
        m) mem=$OPTARG ;;
        t) time=$OPTARG ;;
        o) output_path=$OPTARG ;;
        n) num_array=$OPTARG ;;
        x) concurrency=$OPTARG ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Validate required arguments
if [ -z "$script_path" ] || [ -z "$num_array" ] || [ -z "$concurrency" ]; then
    echo "Error: script_path, num_array, and concurrency are required arguments."
    usage
fi

# Set defaults for optional arguments
job_name=${job_name:-$DEFAULT_JOB_NAME}
partition=${partition:-$DEFAULT_PARTITION}
account=${account:-$DEFAULT_ACCOUNT}
gpus=${gpus:-$DEFAULT_GPUS}
cpus_per_task=${cpus_per_task:-$DEFAULT_CPUS_PER_TASK}
mem=${mem:-$DEFAULT_MEM}
time=${time:-$DEFAULT_TIME}
output_path=${output_path:-$DEFAULT_OUTPUT_PATH}/%x.%A.%a.out

# Slurm array setting
array="1-$num_array%$concurrency"

# Command to submit the job
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
