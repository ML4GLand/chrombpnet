import os
import h5py
import numpy as np
import hdf5plugin
import argparse
import logging
from tqdm.auto import tqdm
from modiscolite.util import calculate_window_offsets

def setup_logger():
    """Set up logging configuration."""
    logging.basicConfig(
        level=logging.DEBUG,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[logging.StreamHandler()]
    )
    return logging.getLogger(__name__)

def parse_args():
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description="Average .counts_scores.h5 files across different runs.")
    parser.add_argument("--files", nargs='+', required=True, help="Whitespace-separated list of .h5 files to process.")
    parser.add_argument("--output_file", required=True, help="Path to save the averaged results as a file.")
    parser.add_argument("--window", type=int, default=None, help="Window size to extract from the center (set to None to disable).")
    parser.add_argument("--max_seqs", type=int, default=None, help="Maximum number of sequences to use per file (first dimension).")
    return parser.parse_args()

def load_and_average_h5(files, window, max_seqs):
    """Load .h5 files and compute the average across the same keys efficiently."""
    count = 0
    shap_sum, raw_sum, projected_shap_sum = None, None, None
    
    for file in tqdm(files, desc="Processing files"):
        logger.debug(f"Loading file: {file}")
        with h5py.File(file, "r") as f:
            center = f['shap']['seq'].shape[2] // 2 if window else None
            start, end = calculate_window_offsets(center, window) if window else (None, None)
            
            shape = f['shap']['seq'].shape
            seq_limit = min(max_seqs, shape[0]) if max_seqs else shape[0]
            
            if shap_sum is None:
                shap_sum = np.zeros((seq_limit, shape[1], end - start if window else shape[2]))
                raw_sum = np.zeros_like(shap_sum)
                projected_shap_sum = np.zeros_like(shap_sum)
            
            shap = np.empty((seq_limit, shape[1], end - start if window else shape[2]))
            raw = np.empty_like(shap)
            projected_shap = np.empty_like(shap)
            
            f['shap']['seq'].read_direct(shap, np.s_[:seq_limit, :, start:end] if window else np.s_[:seq_limit])
            f['raw']['seq'].read_direct(raw, np.s_[:seq_limit, :, start:end] if window else np.s_[:seq_limit])
            f['projected_shap']['seq'].read_direct(projected_shap, np.s_[:seq_limit, :, start:end] if window else np.s_[:seq_limit])
            
            np.add(shap_sum, shap, out=shap_sum)
            np.add(raw_sum, raw, out=raw_sum)
            np.add(projected_shap_sum, projected_shap, out=projected_shap_sum)
            
            count += 1
            logger.debug(f"Processed file {file}, shape: {shap.shape}")
    
    shap_avg = shap_sum / count
    raw_avg = raw_sum / count
    projected_shap_avg = projected_shap_sum / count
    
    logger.debug(f"Computed mean shapes - shap: {shap_avg.shape}, raw: {raw_avg.shape}, projected_shap: {projected_shap_avg.shape}")
    
    return shap_avg, raw_avg, projected_shap_avg

def save_averaged_data(output_file, shap, raw, projected_shap):
    """Save averaged data into a new .h5 file."""
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    logger.info(f"Saving averaged data to {output_file}")
    with h5py.File(output_file, "w") as out:
        out.create_group("shap")
        out.create_group("raw")
        out.create_group("projected_shap")
        
        out.create_dataset("shap/seq", data=shap, compression="gzip", compression_opts=9)
        out.create_dataset("raw/seq", data=raw, compression="gzip", compression_opts=9)
        out.create_dataset("projected_shap/seq", data=projected_shap, compression="gzip", compression_opts=9)
    
    logger.info(f"Averaged data successfully saved to {output_file}")

if __name__ == "__main__":
    logger = setup_logger()
    args = parse_args()
    
    logger.info("Starting .h5 averaging script.")
    
    if not args.files:
        logger.error("No .h5 files provided. Exiting.")
        exit(1)
    
    shap, raw, projected_shap = load_and_average_h5(args.files, args.window, args.max_seqs)
    save_averaged_data(args.output_file, shap, raw, projected_shap)
    
    logger.info("Processing completed successfully.")
