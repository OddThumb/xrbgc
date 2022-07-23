#!/bin/bash

echo "# XRBGC" >> ~/.bash_profile
echo "export xrbgc=$(pwd)" >> ~/.bash_profile
echo 'alias xginit="source $xrbgc/xrbgcinit.sh"' >> ~/.bash_profile

echo "
To initialize, xrbgc,
  $ xginit
You need CIAO-4.14 conda environment with name 'ciao'
"
