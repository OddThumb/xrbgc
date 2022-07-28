#!/bin/bash

# NO REASON FOR RESTRICTING IMAGE WITH A FOV REGION
#usage="cMergeWav [-h] [-n -r]
#where:
#      -h  show this help text
#      -n  GC name with white space. e.g.) '47 Tuc'
#      -r  Core radius ('r_c') or Half-light radius ('r_h')"
#radius='r_h' # default value
#while getopts ":hn:r:" opt; do 
#    case "$opt" in
#        h)  echo "$usage"
#            exit 0
#            ;;
#        n)  IDorNAME="$OPTARG"
#            ;;
#        r)  radius="$OPTARG"
#            ;;
#        :)  printf "missing argument for -%s\n" "$OPTARG" >&2
#            echo "$usage" >&2
#            exit 1
#            ;;
#        \?) printf "illegal option: -%s\n" "$OPTARG" >&2
#            echo "$usage" >&2
#            exit 1
#            ;;
#    esac
#done


# NO REASON FOR RESTRICTING IMAGE WITH A FOV REGION
## FOV region check
#if [ ${radius} == 'r_c' ]; then
#  echo ">>> Core radius will be used for FOV..."
#  rFovregion "${IDorNAME}" "${radius}"
#elif [ ${radius} == 'r_h' ]; then
#  echo ">>> Half-light radius will be used for FOV..."
#  rFovregion "${IDorNAME}" "${radius}"
#else
#  echo "(Error) Please check the input for FOV region option"
#  return
#fi


# Find event files and make a list to merge them
if [ -f evt2.lis ]; then
  echo ">>> evt2.lis file is found"
else
  /bin/ls */repro/*evt2.fits >> evt2.lis
fi


# merge all observations
punlearn merge_obs
merge_obs @evt2.lis merged_half/ binsize=0.5 psfecf=0.9 psfmerge=expmap


# NO REASON FOR RESTRICTING IMAGE WITH A FOV REGION
#cd merged_half/
#punlearn dmcopy
#dmcopy "broad_thresh.img[sky=region(../fov-${radius}.reg)]" broad_image_fov.fits
#punlearn dmcopy
#dmcopy "broad_thresh.psfmap[sky=region(../fov-${radius}.reg)]" broad_psfmap_fov.fits
#punlearn dmcopy
#dmcopy "broad_thresh.expmap[sky=region(../fov-${radius}.reg)]" broad_expmap_fov.fits


# Run wavdetect
cd merged_half/
#mkdir -v wavdet_fov
mkdir -v wavdet

punlearn wavdetect
# NO REASON FOR RESTRICTING IMAGE WITH A FOV REGION
#wavdetect infile=broad_image_fov.fits \
#    expfile=broad_expmap_fov.fits \
#    psffile=broad_psfmap_fov.fits \
wavdetect infile=broad_thresh.img \
    regfile=wavdet/src.reg \
    outfile=wavdet/source_list.fits \
    scellfile=wavdet/source_cell.fits \
    imagefile=wavdet/image.fits \
    defnbkgfile=wavdet/background.fits \
    expfile=broad_thresh.expmap \
    psffile=broad_thresh.psfmap \
    scales="1 1.414 2 2.828" sigthresh=1e-5 clobber=yes verbose=1 mode=h

cd ../

# Display source list or not?
#read -p "Wanna display source list with image? (y/[N]) > " GO
#GO=${GO:-y}
#case $GO in
#    [Yy]* ) ds9 broad_image_fov.fits -region wavdet_fov/src.reg &;;
#    [Nn]* ) ls;;
#esac

