# chrombpnet

# Make scripts

# 1. Negatives

# 2. Bias pipeline


# 3. Run ChromBPNet pipeline

```bash
cmd="./SLURM/chrombpnet_pipeline.sh \
-s scripts/chrombpnet_pipeline/HPAP_chrombpnet_pipeline.sh \
-j HPAP_chrombpnet_pipeline \
-p carter-gpu \
-a carter-gpu \
-g a30:1 \
-c 4 \
-m 80G \
-t 14-00:00:00 \
-o /cellar/users/aklie/data/datasets/HPAP/bin/slurm_logs/chrombpnet/chrombpnet_pipeline \
-n 12 \
-x 3"
echo -e "Running command:\n$cmd"
eval $cmd
```
