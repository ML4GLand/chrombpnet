# Dependencies
In its current form, this pipeline requires a lot of dependency set-up.

## ChromBPNet
Follow the [ChromBPnet repository installation guide](https://github.com/kundajelab/chrombpnet?tab=readme-ov-file#installation) to get conda environment necessary to run "most" pipeline steps

You will also need to install `wiggletools`...

```bash
conda install -c bioconda wiggletools
```

## Auxiliary scripts
Several scripts in the `scripts` directory are necessary for running minor steps in the pipeline. You will need to clone this repository to access them.

## wigToBigWig
This is necessary for converting wig files to bigwig files. You can download the tool [here](http://hgdownload.soe.ucsc.edu/admin/exe/linux.x86_64/). You will need to add the path to the tool to your `PATH` variable.

## Motif clustering
If you want to run the motif clustering step of the pipeline, you'll need to install the gimme package

## Variant scoring
If you want to run the variant scorer step of the pipeline, you'll need to clone the variant-scorer GitHub repository



# Overview
The workflow is broken down into the following steps:

0. [Make scripts](#0.-Make-scripts)
1. [Create matched negative region sets from called peaks](#1.-Create-matched-negative-region-sets-from-called-peaks)
2. [Run bias model training pipeline](#2.-Run-bias-model-training-pipeline)
3. [Run ChromBPNet pipeline](#3.-Run-ChromBPNet-pipeline)
4. [Making predictions](#4.-Making-predictions)
5. [Averaging predictions](#5.-Averaging-predictions)
6. [Generating contributions scores](#6.-Generating-contributions-scores)

Each step is run as a bash script that carries out the necessary sub-steps for that part of the pipeline. The scripts for each step can be generated using the `make_scripts_from_templates.ipynb` notebook. This notebook essentially walks through the process.

1. Pointing to the correct input files. Some assumptions on how the input files are organized are made in the notebook.
2. Generating the necessary output directories and file paths. See the `make_scripts_from_templates.ipynb` notebook and [#Output structure](#Output-structure) for more details.
3. Generating the necessary bash scripts to be run on the cluster. These are generated using templates that can be found and modified here: https://github.com/ML4GLand/chrombpnet/tree/main/templates

These scripts can then be run as desired. I use an HPC cluster managed by a `SLURM` and have provided SLURM submission scripts that can be used to run the above scripts on said cluster. There are 4 main ways to run the scripts:

1. `cpu.sh` - Run the script as a single job. This is used in situations where parallelization across folds, cell types is not necessary or is easier to configure per cell type.
2. `cpu_array.sh` - Run the script as an array job. This is used in situations where parallelization across folds and cell types improves efficiency.
3. `gpu.sh` - Run the script as a single job on a GPU node. This is used in situations where the script requires a GPU but does not need to be parallelized multiple jobs.
4. `gpu_array.sh` - Run the script as an array job on a GPU node. This is used in situations where the script requires a GPU and needs to be parallelized across multiple jobs to be efficient.

As a rule of thumb, anything that involves a model (e.g. training, predicting, etc.) MUST be run on a GPU node.

# Steps

## 0. Make scripts
Modify `make_scripts_from_templates.ipynb` as specified to generate the scripts to be run.

## 1. Create matched negative region sets from called peaks
We need to generate matched negative regions for each cell type across each fold. So this requires running num_folds * num_cell_types jobs. This is most efficiently done as an array job.

I don't know yet if each individual job can be parallelized using multiple CPUs, but this step is usually pretty quick (<20 minutes for 100k-300k peaks) so I'm not sure it matters.  It also does not take up a lot of memory. I've seen the usage usually stay below 8G but I typically set it to 16G to be safe.

```bash
cmd="./SLURM/cpu_array.sh \
-s scripts/negatives/HPAP_negatives.sh \
-j HPAP_negatives \
-p carter-compute \
-a carter-compute \
-c 4 \
-m 16G \
-o /cellar/users/aklie/data/datasets/HPAP/bin/slurm_logs/negatives \
-n 12 \
-x 12"
echo -e "Running command:\n$cmd"
eval $cmd
```

## 2. Run bias model training pipeline
We can usually get away with training a single bias model for each fold for a given dataset. That is, if you have multiple cell types you are training on, you can usually pick one and train a single bias model for each fold. I typically just use the cell type with a large number of fragments to train bias models, using a `beta` parameter of 0.5 to start. This `beta` parameter controls the maximum number of reads a region can have when training the bias model on negative regions. This may need to be tuned (see [here](https://github.com/kundajelab/chrombpnet/wiki/FAQ#2-what-is-the-intuition-in-choosing-the-hyperparameter-for-bias_threshold_factor-how-to-retrain-the-bias-model-based-on-this-) for more details)

Even though we usually only need to train 5 models at this stage (one for each fold), each fold typically takes ~12-24 hours to run so this is best parallelized across multiple jobs.
I do not know if any parts of this step can be parallelized using multiple CPUs yet so I give it a moderate amount of CPUs to use. This step is also pretty CPU memory intensive as the preprocessing of fragment/bam/tagAlign files takes up a lot of RAM. For datasets with 100M fragments for a given cell type, this typically needs to be set > 50G. 

```bash
cmd="./SLURM/gpu_array.sh \
-s scripts/bias/HPAP_bias_pipeline.sh \
-j HPAP_bias_pipeline \
-p carter-gpu \
-a carter-gpu \
-g a30:1 \
-c 4 \
-m 80G \
-t 14-00:00:00 \
-o /cellar/users/aklie/data/datasets/HPAP/bin/slurm_logs/bias_pipeline \
-n 12 \
-x 3"
echo -e "Running command:\n$cmd"
eval $cmd
```

## 3. Run ChromBPNet pipeline
Once the bias models are trained, we can run the ChromBPNet pipeline to train our full chrombpnet models. Here we have to go back to training across both folds and cell types, making it much more efficient to parallelize across multiple jobs. For bias models, we simply need to point each fold to the correct bias model. That is, if I have two cell types A and B, they both get the same bias model for fold 0. The same goes for fold 1, etc.

Similarly to above, I do not know if any parts of this step can be parallelized using multiple CPUs yet so I give it a moderate amount of CPUs to use. The generation of unstranded count bigwigs is repeated in this step so it is also pretty CPU memory intensive. For datasets with 100M fragments for a given cell type, this typically needs to be set > 50G. 

Because we use the same bias model across cell types for a given fold, it is important to verify that the bias transfer across cell types worked as expected. This can be determined by reading the report generated by this step in the pipeline

```bash
cmd="./SLURM/gpu_array.sh \
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

## 4. Generate prediction bigwigs for visualization at peaks
Once the models are trained, we can generate predictions for each fold and cell type. This can be theoretically done at any position in the genome, but we typcially care most about the predictions at the called peaks. 

This step is pretty quick but can easily be parallelized across multiple jobs. This step doesn't appear to be very memory intensive. I typically set it to 32G but this also might be overkill.

```bash
cmd="./SLURM/gpu_array.sh \
-s scripts/predictions/HPAP_predictions.sh \
-j HPAP_predictions \
-p carter-gpu \
-a carter-gpu \
-g 1 \
-c 4 \
-m 32G \
-o /cellar/users/aklie/data/datasets/HPAP/bin/slurm_logs/chrombpnet/predictions \
-n 12 \
-x 12"
echo -e "Running command:\n$cmd"
eval $cmd
```

## 5. Averaging predictions
Though training and evaluating our pipeline over folds is a good idea to get a sense of how well our model generalizes and the robustness of our predictions, we ideally would like our final outputs to be at a cell type level. To achieve this, we can average the predictions across folds for each cell type. This is not impossible to set-up as a single script for all cell types, but for the way I set up the scripts and the fact that we typically have < 20 cell types in our dataset, it was easier to set up as individual jobs for each cell type.

Averaging does not involve a model so it can be run on a CPU node. This step is relatively pretty quick (<1hr) and not very memory intensive. I typically set it to 16G. This step runs `wiggletools` to calculate the average across bigwig files, and I'm not sure if it can be parallelized within each cell type (job). For now I typically set it to 5 CPUs per job to match the fold (in case it can be parallelized).

```bash
celltypes=(Acinar Alpha A_Stellate Beta Delta Ductal Endothelial Gamma Immune MUC5B_Ductal Q_Stellate Schwann)
for celltype in ${celltypes[@]}; do
    cmd="./SLURM/cpu.sh \
-s scripts/predictions/HPAP_${celltype}_average_predictions.sh \
-j HPAP_${celltype}_average_predictions \
-p carter-compute \
-a carter-compute \
-c 1 \
-m 4G \
-o /cellar/users/aklie/data/datasets/HPAP/bin/slurm_logs/chrombpnet/predictions"
    echo -e "Running command:\n$cmd"
    eval $cmd
done
```

## 6. Generating contributions scores for all peaks
Along with predictions, it is also extremely useful to calculate nucleotide-resolution contribution scores for each input peak. This is done across each fold and cell type and is potentially the most compute intensive step of the pipeline. It is highly recommended to parallelize this step across multiple jobs, and since it involves a model, it must be run on a GPU node.

I'm not sure about the memory requirements for this step, but I typically get away with setting it to 32G. I don't think this can really be parallelized in any way within a job, but I give it a few CPUs (usually 4) just in case.

```bash
cmd="./SLURM/gpu_array.sh \
-s scripts/contributions/HPAP_contributions.sh \
-j HPAP_contributions \
-p carter-gpu \
-a carter-gpu \
-g a30:1 \
-o /cellar/users/aklie/data/datasets/HPAP/bin/slurm_logs/chrombpnet/contributions \
-n 12 \
-x 12"
echo -e "Running command:\n$cmd"
eval $cmd
```

## 7. Average contribution scores
Similarly to predictions, we would like to average the contribution scores across folds for each cell type. We do this in much the same way as averaging predictions.

The major difference however, is we need to average both the bigwig files and the output h5 files (see [#Output structure](#Output-structure) for more details). This ends up being a more time intensive step than averaging predictions, but will usually finish in < 1hr and < 16G of RAM. Similarly to averaging predictions, I'm not sure if this step can be parallelized within each cell type (job). For now I typically set it to 5 CPUs per job to match the fold (in case it can be parallelized).

```bash
celltypes=(Acinar Alpha A_Stellate Beta Delta Ductal Endothelial Gamma Immune MUC5B_Ductal Q_Stellate Schwann)
for celltype in ${celltypes[@]}; do
    cmd="./SLURM/cpu.sh \
-s scripts/contributions/HPAP_${celltype}_average_contributions.sh \
-j HPAP_${celltype}_average_contributions \
-p carter-compute \
-a carter-compute \
-c 1 \
-m 4G \
-o /cellar/users/aklie/data/datasets/HPAP/bin/slurm_logs/chrombpnet/contributions"
    echo -e "Running command:\n$cmd"
    eval $cmd
done
```

## 8. De novo motif discovery
Though individual peak contributions are interesting, we can get a better sense of overall model behavior by looking at recurring highly contributing motifs across peaks and clustering them. The TF-MoDISco pipeline is an excellent tool for this. We can run this algorithm for both the counts and profile predictions.

This is one of the more compute intensive steps of the pipeline, and should be parallelized across multiple jobs. This step is lightweight on memory (32G should suffice) and can be parallelized across multiple CPUs within a job. I typically set it to 32 CPUs per job if possible to take advantage of the parallelization speed-up. Since this step only requires contributions scores, it can be run on a CPU node.

```bash
cmd="./SLURM/cpu_array.sh \
-s scripts/motifs/HPAP_motif_discovery.sh \
-j HPAP_motif_discovery \
-p carter-compute \
-a carter-compute \
-c 32 \
-m 32G \
-o /cellar/users/aklie/data/datasets/HPAP/bin/slurm_logs/chrombpnet/motif_discovery \
-n 24 \
-x 5"
echo -e "Running command:\n$cmd"
eval $cmd
```

## 9. Motif clustering
It's likely that models for different cell types and contributions for the profile and counts heads within a cell type will learn a set of shared motifs. It becomes useful to cluster motifs to form a more concise set.

```bash
cmd="./SLURM/cpu.sh \
-s scripts/motifs/HPAP_motif_clustering.sh \
-j HPAP_motif_clustering \
-p carter-compute \
-a carter-compute \
-c 4 \
-m 16G \
-o /cellar/users/aklie/data/datasets/HPAP/bin/slurm_logs/chrombpnet/motif_clustering"
echo -e "Running command:\n$cmd"
eval $cmd
```


## 10. Motif annotation and filtering
It is often a good idea to inspect the results of motif clustering and annotation. 

1. TomTom match filtering
2. Information content filtering
3. Redundant cluster filtering





## 10. Motif hit calling


## 11. Variant scoring

```bash
variant_lists=(HPAP_2hGlu_MAGIC HPAP_FG_MAGIC HPAP_FI_MAGIC HPAP_HbA1c_MAGIC HPAP_T1D_Chiou_2021)
for variant_list in ${variant_lists[@]}; do
    cmd="./SLURM/gpu_array.sh \
-s scripts/variant_scoring/${variant_list}_variant_scoring.sh \
-j ${variant_list}_variant_scoring \
-p carter-gpu \
-a carter-gpu \
-g a30:1 \
-c 4 \
-m 16G \
-o /cellar/users/aklie/data/datasets/HPAP/bin/slurm_logs/chrombpnet/variant_scoring \
-n 12 \
-x 12"
    echo -e "Running command:\n$cmd"
    eval $cmd
done
```


One small note. Our cluster has two different types of GPUs, an NVIDIA RTX1080: and a NVIDIA a30. The a30 is much more powerful than the RTX, so for all intensive GPU jobs (model training and contribution scores), I typically specify only a30 GPUs can be used. Predictions are more lightweight so I allow the scheduler to pick any available GPU.


# Output strcuture