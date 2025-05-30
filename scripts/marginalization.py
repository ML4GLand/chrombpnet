#!/usr/bin/env python

import os
import argparse
import torch
import pandas as pd
import pyfaidx

from bpnetlite.bpnet import BPNet
from bpnetlite.marginalize import marginalization_report
import seqpro as sp

NARROWPEAKS_SCHEMA = [
    "chrom",
    "start",
    "end",
    "name",
    "score",
    "strand",
    "signal_value",
    "p_value",
    "q_value",
    "peak"
]

def extract_sequences(genome_fasta, peaks_path, n_seqs, flank=1057, seed=1234):
    genome = pyfaidx.Fasta(genome_fasta)
    peaks = pd.read_csv(peaks_path, header=None, sep="\t", names=NARROWPEAKS_SCHEMA)
    peaks = peaks.sort_values('q_value', ascending=False).drop_duplicates(subset=['chrom', 'start', 'end'])

    peaks['mid'] = (peaks['start'] + peaks['end']) // 2
    peaks['start'] = peaks['mid'] - flank
    peaks['end'] = peaks['mid'] + flank

    peaks_sub = peaks.sample(n=n_seqs, random_state=seed)

    sequences = []
    for _, row in peaks_sub.iterrows():
        seq = genome[row['chrom']][row['start']:row['end']].seq
        sequences.append(seq)

    return sequences


def main(args):
    os.makedirs(args.output_dir, exist_ok=True)

    # Extract and encode sequences
    sequences = extract_sequences(args.genome_fasta, args.peaks_bed, args.num_seqs, flank=args.flank, seed=args.seed)
    X = sp.k_shuffle(sequences, k=2, seed=args.seed, alphabet=sp.DNA)
    X = torch.tensor(sp.ohe(X, alphabet=sp.DNA).transpose(0, 2, 1), dtype=torch.uint8)

    # Load model
    model = BPNet.from_chrombpnet(args.model_path).cuda().eval()

    # Run marginalization report
    marginalization_report(
        model,
        args.motif_file,
        X=X,
        output_dir=args.output_dir,
        verbose=True,
        batch_size=args.batch_size
    )

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run marginalization analysis for a single model")
    parser.add_argument("-m", "--model_path", required=True, help="Path to trained chromBPNet model (.h5)")
    parser.add_argument("-f", "--motif_file", required=True, help="Path to MEME motif file")
    parser.add_argument("-g", "--genome_fasta", required=True, help="Path to genome FASTA file")
    parser.add_argument("-p", "--peaks_bed", required=True, help="Path to peaks BED file (expects a .schema file in same dir)")
    parser.add_argument("-o", "--output_dir", required=True, help="Directory to write output files")
    parser.add_argument("-n", "--num_seqs", type=int, default=100, help="Number of sequences to sample")
    parser.add_argument("--flank", type=int, default=1057, help="Number of bp to extend around peak midpoint")
    parser.add_argument("--seed", type=int, default=1234, help="Random seed for reproducibility")
    parser.add_argument("-b", "--batch_size", type=int, default=16, help="Batch size for model prediction")

    args = parser.parse_args()
    main(args)
