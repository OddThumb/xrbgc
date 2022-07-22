#!/bin/bash

#############################################################
#                                                           #
#  Reprocessing.sh (Ver 1.1)                                #
#  ------------------------------------------------------   #
#  Run serial "chandra_repro" along with exsisting data!    #
#  ------------------------------------------------------   #
#                                                           #
#############################################################

# Initailze HEASOFT and CIAO
#heainit                   # HEASOFT
#conda activate ciao-4.13  # CIAO


# Read secondary/ directory in every sub-directory
fullpath=($(find . -name secondary))
shortpath=()
for dir in ${fullpath[*]}; do
      segments=(${dir//\// })
      shortpath+=(${segments[1]})
done


# Check directories you want to reprocess
read -p ">>> There are ${#shortpath[*]} input directory: ${shortpath[*]}
    Continue? (y) > " GO
GO=${GO:-y}
case $GO in
    [Yy]* ) echo '';;
    [Nn]* ) return;;
esac


# ...ing...
for dir in ${shortpath[*]}; do
  punlearn chandra_repro
	chandra_repro indir=$dir outdir=$dir/repro
	punlearn ardlib
done


echo ">>> Check "repro" directory in: ${shortpath[*]}"
