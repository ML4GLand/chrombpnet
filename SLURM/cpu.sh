#!/bin/bash

# Default values
DEFAULT_JOB_NAME="cpu"
DEFAULT_PARTITION="carter-compute"
DEFAULT_ACCOUNT="carter-compute"
DEFAULT_CPUS_PER_TASK=4
DEFAULT_MEM="32G"
DEFAULT_TIME="14-00:00:00"
DEFAULT_OUTPUT_PATH="./"

# Help message
usage() {
    echo "SLURM submission script for job with CPU only tasks. Use to run any bash script."
    echo "Usage: $0 [-s script_path] [-j job_name] [-p partition] [-a account] [-c cpus_per_task] [-m mem] [-t time] [-o output]"
    echo "Options:"
    echo "  -s  Path to the script to be submitted (required)"
    echo "  -j  Job name (default: $DEFAULT_JOB_NAME)"
    echo "  -p  Partition (default: $DEFAULT_PARTITION)"
    echo "  -a  Account (default: $DEFAULT_ACCOUNT)"
    echo "  -c  CPUs per task (default: $DEFAULT_CPUS_PER_TASK)"
    echo "  -m  Memory allocation (default: $DEFAULT_MEM)"
    echo "  -t  Time limit (default: $DEFAULT_TIME)"
    echo "  -o  Output path (default: $DEFAULT_OUTPUT_PATH). SLURM log files will be written to this path with %x.%A.%a.out format"
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
        c) cpus_per_task=$OPTARG ;;
        m) mem=$OPTARG ;;
        t) time=$OPTARG ;;
        o) output_path=$OPTARG ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Validate required arguments
if [ -z "$script_path" ]; then
    echo "Error: script_path is required arguments."
    usage
fi

# Set defaults for optional arguments
job_name=${job_name:-$DEFAULT_JOB_NAME}
partition=${partition:-$DEFAULT_PARTITION}
account=${account:-$DEFAULT_ACCOUNT}
cpus_per_task=${cpus_per_task:-$DEFAULT_CPUS_PER_TASK}
mem=${mem:-$DEFAULT_MEM}
time=${time:-$DEFAULT_TIME}
output_path=${output_path:-$DEFAULT_OUTPUT_PATH}/%x.%A.%a.out

# Command to submit the job
cmd="sbatch \
--job-name=$job_name \
--partition=$partition \
--account=$account \
--cpus-per-task=$cpus_per_task \
--mem=$mem \
--time=$time \
--output=$output_path \
$script_path"

echo -e "Running command:\n$cmd\n"
eval $cmd
