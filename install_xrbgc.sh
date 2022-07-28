#!/bin/bash

echo "# XRBGC" >> ~/.bash_profile
echo "export xrbgc=$(pwd)" >> ~/.bash_profile
echo 'alias xginit="source $xrbgc/xrbgcinit.sh"' >> ~/.bash_profile

echo 'You need CIAO>=4.14 conda environment with name "ciao"

Following commands are added in your ~/.bash_profile
  export xrbgc=$(pwd)"
  alias xginit="source $xrbgc/xrbgcinit.sh"

To initialize, xrbgc,
  $ xginit
'
