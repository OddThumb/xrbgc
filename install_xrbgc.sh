#!/bin/bash

# where is oncda
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

echo "
# XRBGC" >> ~/.bash_profile
echo "export xrbgc=\"$(pwd)\"" >> ~/.bash_profile
ciaopath=($(conda env list | grep ciao))
ciaopath=${ciaopath[1]}
if [ ${#ciaopath[@]} =< 1 ]; then
    echo "ERROR: CIAO conda environment not found"
	exit 2
else
	echo "export xrbgc_ciao=\"${ciaopath}\"" >> ~/.bash_profile
fi
echo 'alias xginit="source $xrbgc/xrbgcinit.sh"' >> ~/.bash_profile


# If there is no R installed, please install R first
R_EXEC=$(which Rscript)
if [ -z "$R_EXEC" ]; then
  echo "Error: Rscript not found. Please install R first."
  exit 1
fi

for rfile in $(pwd)/Rs/*; do
  sed -i "1i #!$R_EXEC\n" "$rfile"
done
echo "xrbgc=$(pwd)" >> ~/.Renviron 


# Closing message
echo "[ xrbgc is successfully registered! ]
CIAO path that will be used: ${ciaopath}

Following commands are added in your ~/.bash_profile
  export xrbgc=$(pwd)
  export xrbgc_ciao=${ciaopath}
  alias xginit=\"source $xrbgc/xrbgcinit.sh\"

To initialize xrbgc, type:
  $ xginit
"
