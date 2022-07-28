#!/bin/bash

# =========================================================
#                     (1) Input files
# =========================================================
# List files for multiple observation
if [ -f evt2.lis ]; then
    echo "evt2.lis file already exists"
    evt2_list=($(cat evt2.lis))
else
    /bin/ls */repro/*evt2.fits >> evt2.lis
    evt2_list=($(cat evt2.lis))
fi
if [ -f bpix1.lis ]; then
    echo "bpix1.lis file already exists"
    bpix_list=($(cat bpix1.lis))
else
    /bin/ls */repro/*repro_bpix1.fits >> bpix1.lis
    bpix_list=($(cat bpix1.lis))
fi
if [ -f asol1.lis ]; then
    echo "asol1.lis file already exists"
    asol_list=($(cat asol1.lis))
else
    /bin/ls */repro/*asol1.fits >> asol1.lis
    asol_list=($(cat asol1.lis))
fi
if [ -f msk1.lis ]; then
    echo "msk1.lis file already exists"
    mask_list=($(cat msk1.lis))
else
    /bin/ls */repro/*msk1.fits >> msk1.lis
    mask_list=($(cat msk1.lis))
fi

# File number check
if [[ ${#evt2_list[@]} -eq ${#bpix_list[@]} ]] && \
   [[ ${#evt2_list[@]} -eq ${#asol_list[@]} ]] && \
   [[ ${#evt2_list[@]} -eq ${#mask_list[@]} ]]; then
    echo ""
else
    echo "Wrong number of files are given"
    exit 1
fi

# Source regions
if [ -f src.lis ]; then
    echo "src.lis file already exists"
else
    /bin/ls info/src*.reg >> src.lis
    src_list=($(cat src.lis))
fi
if [ ${#src_list[@]} -eq 0 ]; then
    echo "Source regions not found in the directory: info/"
    exit 1
else
    echo "There are ${#src_list[@]} source regions for spectrum extraction: ${src_list}"
fi
bkg_reg=info/bkg.reg
if [ -f ${bkg_reg} ]; then
    echo "${bkg_reg} will be used for background spectrum"
else
    echo "${bkg_reg} not found"
    exit 1
fi


# =========================================================
#                     (2) Specextract
# =========================================================
spec_dir=spec
mkdir ${spec_dir}

# Iterate over evt2 and src_list
for i in `seq 0 $((${#evt2_list[@]}-1))`; do
    # Input files
    evt2=${evt2_list[$i]}
    bpix=${bpix_list[$i]}
    asol=${asol_list[$i]}
    mask=${mask_list[$i]}
    
    # Extracting obsid from evt2 file name
    filename0=(${evt2//\// })
    filename1=${filename0[$((${#filename0[@]}-1))]}
    filename2=(${filename1//_/ })
    filename=${filename2[0]}
    obsid=${filename//acisf/}
    
    for j in `seq 0 $((${#src_list[@]}-1))`; do
        src_reg=${src_list[$j]}
        reg_ind0=(${src_reg//\// })
        reg_ind1=(${reg_ind0[1]//./ })
        reg_ind=(${reg_ind1[0]//src/ })

        echo "Extracting spectrum
  | ObsID: $obsid, \
  | $(($i+1))-th source: ${evt2} \
  | $(($j+1))-th region: $src_reg \
  | background region: $bkg_reg"
        
        # Extract source with region
        dmcopy "${evt2}[sky=region(${src_reg})]" "spec/Obs${obsid}_${reg_ind}.fits" verbose=0
        
        punlearn ardlib
        acis_set_ardlib ${bpix} verbose=0
        
        # specextract
        punlearn specextract
        specextract infile="${evt2}[sky=region(${src_reg})]" \
                    outroot="spec/Obs${obsid}_${reg_ind}" \
                    bkgfile="${evt2}[sky=region(${bkg_reg})]" \
                    asp=${asol} mskfile=${mask} badpixfile=${bpix} \
                    weight=no correct=no \
                    grouptype=NONE binspec=NONE \
                    verbose=1 clobber=yes
    done
done


# Organizing *.lis files
mkdir spec/listfiles
mv *.lis spec/listfiles
