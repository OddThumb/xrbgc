#!/bin/bash

#############################################################
#                                                           #
#  BandSplit.sh (Ver 1.0)                                   #
#  ------------------------------------------------------   #
#  Simply serial dmcopy by given X-ray energies             #    
#                                                           #
#  * Input: event file,                                     #
#       energy ranges (e.g. '0.5-1.5'/'1.5-4.5'/'4.5-6.0')  #
#       [ each energy ranges need to be divided by '/' ]    #
#                                                           #
#  * Output: filtered event files                           #
#            (corresponding to each energy band)            #
#  ------------------------------------------------------   #
#                                                           #
#############################################################


# Initailze HEASOFT and CIAO
heainit              # HEASOFT 
ciao -o &>/dev/null  # CIAO

echo "
>>> HEASOFT and CIAO are initialized!"


#=========================== Setting and Checking =================================
# Check arguments
if [ $# -eq 0 ]; then
    echo "(error) Usage: cBandSplit (event file) ('band1'/'band2'/'band3')
               Default bands: '0.5-1.5/1.5-4.5/4.5-6.0'
               each band need to be split by '/'
               In one band, energies (in keV) need to be split by '-'"
    return
fi


# Check band format
if [ -z "$2" ]; then
    checkBands='0.5-1.5/1.5-4.5/4.5-6.0'
else
    checkBands=$2
fi
checkBands2=(${checkBands//\// })
checkBands3=$(printf "  /  %s" "${checkBands2[*]}")
read -p ">>> Input ${#checkBands2[*]} band(s):   ${checkBands3:5}
    Keep going? (y) > " GO
GO=${GO:-y}
case $GO in
    [Yy]* ) echo '';;
    [Nn]* ) return;;
esac


# Start from outside of ObsID directory
crntdir=$(pwd)


# Create bands/ directory in crntdir/
mkdir -v bands
cd bands


# Split event file into given bands
outfileS=()
for band in ${checkBands2[*]}; do
    
    band=(${band//-/ })
    elo=$(python -c "print(${band[0]} * 1000)")
    ehi=$(python -c "print(${band[1]} * 1000)")

    outfile="event_${band[0]}-${band[1]}.fits"
    outfileS+=($outfile)

    punlearn dmcopy
    dmcopy "$crntdir/$1[energy=$elo:$ehi]" $outfile

done

echo ">>> Following files are created!
${outfileS[*]}"

cd ..
