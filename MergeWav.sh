#!/bin/bash

# Find event files and make a list to merge them
if [ -f evt2.lis ]; then
  echo ">>> evt2.lis file is found"
else
  /bin/ls */repro/*evt2.fits >> evt2.lis
fi


# Making Half-light radius region
if [ $# -eq 0 ]; then
  read -p ">>> What is the GC's name?: " IDorNAME
  read -p ">>> What is the fov radius? (e.g. r_c, r_h): " radius
  Rscript $cTools/Fovregion.R "${IDorNAME}" "${radius}"
elif [ $# -eq 1 ]; then
  read -p ">>> What is the fov radius? (e.g. r_c, r_h): " radius
  Rscript $cTools/Fovregion.R "${1}" "${radius}"
else
  echo "(Error) An argument must be supplied correctly"
  return
fi


# FOV region check
if [ ${radius} == 'r_c' ]; then
  echo ">>> Core radius will be used for FOV..."
elif [ ${radius} == 'r_h' ]; then
  echo ">>> Half-light radius will be used for FOV..."
else
  echo "(Error) Please check the input for FOV region option"
fi


# merge all observations
punlearn merge_obs
merge_obs @evt2.lis merged_half/ binsize=0.5 psfecf=0.9 psfmerge=expmap


# Dmcopy extensive image file with half-light radii FOV region
cd merged_half/

punlearn dmcopy
dmcopy "broad_thresh.img[sky=region(../fov-${radius}.reg)]" broad_image_fov.fits
punlearn dmcopy
dmcopy "broad_thresh.psfmap[sky=region(../fov-${radius}.reg)]" broad_psfmap_fov.fits
punlearn dmcopy
dmcopy "broad_thresh.expmap[sky=region(../fov-${radius}.reg)]" broad_expmap_fov.fits


# Run wavdetect
mkdir -v wavdet_fov

punlearn wavdetect
wavdetect infile=broad_image_fov.fits \
  regfile=wavdet_fov/src.reg \
  outfile=wavdet_fov/source_list.fits \
  scellfile=wavdet_fov/source_cell.fits \
  imagefile=wavdet_fov/image.fits \
  defnbkgfile=wavdet_fov/background.fits \
  expfile=broad_expmap_fov.fits \
  psffile=broad_psfmap_fov.fits \
  scales="1 1.414 2 2.828" sigthresh=1e-5 clobber=yes verbose=1 mode=h


# Display source list or not?
read -p "Wanna display source list with image? (y/[N]) > " GO
GO=${GO:-y}
case $GO in
    [Yy]* ) ds9 broad_image_fov.fits -region wavdet_fov/src.reg &;;
    [Nn]* ) ls;;
esac

