#!/bin/bash

echo "
# XRBGC" >> ~/.bash_profile
echo "export xrbgc=$(pwd)" >> ~/.bash_profile
ciaopath=($(conda env list | grep ciao))
ciaopath=${ciaopath[1]}
if [ ${#ciaopath[@]} =< 1 ]; then
    echo "ERROR: CIAO conda environment not found"
	exit 2
else
	echo "export xrbgc_ciao=${ciaopath}" >> ~/.bash_profile
fi
echo 'alias xginit="source $xrbgc/xrbgcinit.sh"' >> ~/.bash_profile

if [ -f ~/.Renviron ]; then
    echo "export xrbgc=$(pwd)" >> ~/.Renviron 
else
    echo "WARNING: Please check whether you have R and ~/.Renviron"
    echo "         The environment variable of 'xrbgc' is registered, anyway"     
    echo "xrbgc=$(pwd)" >> ~/.Renviron
fi

echo "[ xrbgc is successfully registered! ]
CIAO path that will be used: ${ciaopath}

Following commands are added in your ~/.bash_profile
  export xrbgc=$(pwd)
  export xrbgc_ciao=${ciaopath}
  alias xginit=\"source $xrbgc/xrbgcinit.sh\"

To initialize xrbgc, type:
  $ xginit
"
