#!/bin/bash
echo "# XRBGC" >> ~/.bash_profile
echo "export xrbgc=$(pwd)" >> ~/.bash_profile
ciaopath=($(conda env list | grep ciao))
ciaopath=${ciaopath[1]}
if [ ${#ciaopath[@]} == 1 ]; then
    echo "ERROR: CIAO conda environment not found"
	exit 2
else
	echo "export xrbgc_ciao=${ciaopath}" >> ~/.bash_profile
fi
echo 'alias xginit="source $xrbgc/xrbgcinit.sh"' >> ~/.bash_profile
echo 'You need CIAO>=4.15 conda environment with name "ciao"

Following commands are added in your ~/.bash_profile
  export xrbgc=$(pwd)"
  alias xginit="source $xrbgc/xrbgcinit.sh"

To initialize, xrbgc,
  $ xginit
'
