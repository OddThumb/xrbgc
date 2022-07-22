#!/bin/bash

# Running wavdetect for every single observation
mkdir -v wcs_corr
mv merged_half merged_half_old


/bin/ls */repro/*evt2.fits > evt2_old.lis
/bin/ls */repro/*bpix1.fits > bpix1_old.lis
/bin/ls */repro/*msk1.fits > msk1_old.lis
/bin/ls */repro/*asol1.fits > asol1_old.lis
/bin/ls merged_half_old/*_broad_thresh.img > img.lis
/bin/ls merged_half_old/*_broad_thresh.psfmap > psf.lis
/bin/ls merged_half_old/*_broad_thresh.expmap > exp.lis

evt2list=($(cat evt2_old.lis))
bpix1list=($(cat bpix1_old.lis))
msk1list=($(cat msk1_old.lis))
asollist=($(cat asol1_old.lis))
imglist=($(cat img.lis))
psflist=($(cat psf.lis))
explist=($(cat exp.lis))


for evt in ${evt2list[*]}; do
  echo ${evt}
  dmkeypar ${evt} ONTIME echo+
done


# OBSID: 15615 has the longeset ONTIME: 85309.157 s
ref=15615


loopseq=$(seq 0 $((${#imglist[*]}-1)))
for i in $loopseq; do
  name0=(${imglist[$i]//\// })
  name1=(${name0[1]//\_/ })
  name=${name1[0]}

  echo ">>> detecting sources (ObsID: ${name})"
  punlearn wavdetect
  wavdetect \
    infile=${imglist[$i]} psffile=${psflist[$i]} expfile=${explist[$i]} \
    scales="1 1.414 2 2.828" outfile=wcs_corr/${name}_broad.src\
    scell=wcs_corr/${name}_broad.cell imagefile=wcs_corr/${name}_broad.recon \
    defnbkg=wcs_corr/${name}_broad.nbkg interdir=./ mode=h clob+
done

loopseq=$(seq 0 $((${#imglist[*]}-1)))
for i in $loopseq; do
  name0=(${imglist[$i]//\// })
  name1=(${name0[1]//\_/ })
  name=${name1[0]}
  
  # Match WCS with output of wavdetect file
  punlearn wcs_match
  wcs_match infile=wcs_corr/${name}_broad.src refsrcfile=wcs_corr/${ref}_broad.src\
    outfile=wcs_corr/${name}.xform clobber=yes
  
  cp -r ${name}/repro ${name}/repro_corr
  evt2file=$(ls ${name}/repro_corr/*repro_evt2.fits)
  asolfile=$(ls ${name}/repro_corr/*asol1.fits)

  echo ">>> repro files are WCS-updating... (ObsID: ${name})"
  punlearn wcs_update
  wcs_update infile=${evt2file} outfile="" transformfile=wcs_corr/${name}.xform clobber=yes
  punlearn wcs_update
  wcs_update infile=${asolfile} outfile=${asolfile}\
    transformfile=wcs_corr/${name}.xform clobber=yes
done




