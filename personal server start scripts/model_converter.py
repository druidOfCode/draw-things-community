from safetensors.torch import load_file
from glob import glob
import torch
from tqdm import tqdm
import os
import gc


def main(base_path: str, skip_existing: bool = True):
    """
    Convert safetensors files to pytorch checkpoint (.ckpt) files.

    Args:
        base_path (str): The base path where the safetensors files are located.
        skip_existing (bool): Skip conversion if .ckpt file already exists.

    Returns:
        None
    """
    if not os.path.exists(base_path):
        print(f"Error: Path '{base_path}' does not exist.")
        return
    
    safetensor_files = glob(f"{base_path}/*.safetensors")
    
    if not safetensor_files:
        print(f"No .safetensors files found in '{base_path}'")
        return
    
    print(f"Found {len(safetensor_files)} .safetensors files to convert")
    
    for filename in tqdm(safetensor_files, desc="Converting models"):
        output_filename = filename.replace(".safetensors", ".ckpt")
        
        # Skip if output file already exists and skip_existing is True
        if skip_existing and os.path.exists(output_filename):
            print(f"Skipping {os.path.basename(filename)} - .ckpt already exists")
            continue
            
        try:
            print(f"Loading {os.path.basename(filename)}...")
            ckpt = load_file(filename)
            
            print(f"Saving as {os.path.basename(output_filename)}...")
            torch.save(ckpt, output_filename)
            
            # Force garbage collection to free memory
            del ckpt
            gc.collect()
            
            print(f"✓ Successfully converted {os.path.basename(filename)}")
            
        except Exception as e:
            print(f"✗ Error converting {os.path.basename(filename)}: {str(e)}")
            continue
    
    print("Conversion complete!")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Convert safetensors files to PyTorch checkpoint (.ckpt) files")
    parser.add_argument("--base_path", type=str, required=True, help="Path to directory containing .safetensors files")
    parser.add_argument("--force", action="store_true", help="Overwrite existing .ckpt files")
    args = parser.parse_args()
    
    main(args.base_path, skip_existing=not args.force)
