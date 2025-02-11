#!/bin/bash

# Help text
usage="xginit [-h] [-i -e]
where:
      -h  Show this help text
      -i  Initialize (remove) directory: ~/cxcds_param4
          (Default: false)
      -e  Show expamles of workflow (xgmanual)
          (Default: false)"

# Default values
init_rm=false
example=false

# Get arguments
while getopts ":hi:e:" opt; do
    case $opt in
        h)  echo "$usage"
            exit 0
            ;;
        i)  init_rm="$OPTARG"
            ;;
        e)  example="$OPTARG"
            ;;
        :)  printf "missing argument for -%s\n" "$OPTARG" >&2
            echo "$usage" >&2
            exit 1
            ;;
        \?) printf "illegal option: -%s\n" "$OPTARG" >&2
            echo "$usage" >&2
            exit 1
            ;;
    esac
done


# Initialize (remove) cxcds_param4 directory or not
if $init_rm; then
	rm -rf ~/cxcds_param4
fi

# where is conda
if [ -f "$CONDA_PREFIX/etc/profile.d/conda.sh" ]; then
  source "$CONDA_PREFIX/etc/profile.d/conda.sh"
elif [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
  source "$HOME/miniconda3/etc/profile.d/conda.sh"
elif [ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]; then
  source "$HOME/anaconda3/etc/profile.d/conda.sh"
else
  echo "Error: conda.sh not found!"
  exit 1
fi

# Activate ciao
conda activate $xrbgc_ciao
export PATH="$xrbgc:$xrbgc/bashs:$xrbgc/Rs:$xrbgc/Pythons:$PATH"

# CIAO version info
echo "Reading installed ciao config..."
ciao_ver=$(${xrbgc_ciao}/bin/ciaover)

echo "
 ┌──────────────────────────────┐

          xrbgc (v1.0.0)         
                                  
      > Author: Sang In Kim       
      > Date: 08 Nov 2023          
                                   
     Wrapper scripts for CIAO    

$ciao_ver     
                                      
                                 
    Ref: Fruscione et al.(2006)  
 └──────────────────────────────┘
"

# Show examples of workflow (xgmanual)
if $example; then
	source $xrbgc/xgmanual
fi
