# Making Half-light radius region
if [ $# -eq 0 ]; then
  read -p ">>> What is the GC's name?: " IDorNAME
  rFovregion "${IDorNAME}" "r_h"
elif [ $# -eq 1 ]; then
  outputdir=${2}
elif [ $# -eq 2 ]; then
  rFovregion "${1}" "r_h"
  outputdir=${2}
else
  echo "(Error) An argument must be supplied correctly"
  return
fi
outputdir=${outputdir:-"merged"}

/bin/ls */repro_corr/*evt2.fits > evt2.lis
/bin/ls */repro_corr/*repro_bpix1.fits > bpix1.lis
/bin/ls */repro_corr/*msk1.fits > msk1.lis
/bin/ls */repro_corr/*asol1.fits > asol1.lis

evt2list=($(cat evt2.lis))
bpixlsit=($(cat bpix1.lis))
msk1lsit=($(cat msk1.lis))
asollist=($(cat asol1.lis))


loopseq=$(seq 0 $((${#evt2list[*]}-1)))
for i in $loopseq; do
  name0=(${evt2list[$i]//\// })
  name=${name0[0]}

  # Making flux image (broad band [0.5-7.0 keV] at monoenergy at 2.3 kev)
  punlearn fluximage
  fluximage infile=${evt2list[$i]} bands=broad\
    asolfile=${asollist[$i]} badpixfile=${bpixlist[$i]}\
    maskfile=${msk1list[$i]} psfecf=0.9 binsize=0.5\
    outroot=${outputdir}/${name}
done

/bin/ls ${outputdir}/*_broad_flux.img > flx.lis
/bin/ls ${outputdir}/*_broad_thresh.expmap > exp.lis
/bin/ls ${outputdir}/*_broad_thresh.psfmap > psf.lis

fluxes=($(cat flx.lis))
expmaps=($(cat exp.lis))
psfmaps=($(cat psf.lis))
allfiles=(${fluxes[*]} ${expmaps[*]} ${psfmaps[*]})
echo ">>> Clipping all images with a halflight region"
for file in ${allfiles[*]}; do
  echo "  $file"
  punlearn dmcopy
  dmcopy "${file}[sky=region(fov-r_h.reg)]" ${file}_halflight.fits
done

/bin/ls ${outputdir}/*_broad_flux.img_halflight.fits > flx_half.lis
/bin/ls ${outputdir}/*_broad_thresh.expmap_halflight.fits > exp_half.lis
/bin/ls ${outputdir}/*_broad_thresh.psfmap_halflight.fits > psf_half.lis
fluxes=($(cat flx_half.lis))
expmaps=($(cat exp_half.lis))
psfmaps=($(cat psf_half.lis))
fluxes="${fluxes[*]}"
expmaps="${expmaps[*]}"
psfmaps="${psfmaps[*]}"

expinput=${expmaps// /\,}
flxinput="${expinput},${fluxes// /,}"
psfinput="${expinput},${psfmaps// /,}"

flxop=
expop=
psfop=
loopseq=$(seq 0 $((${#evt2list[*]}-1)))
for i in $loopseq;do
  if [ $i == 0 ]; then
    flxop="img$(( 1 + ${#evt2list[*]}))"
    expop=img1
    psfop="img1*img$(( 1 + ${#evt2list[*]}))"
  else
    flxop="${flxop}+img$(( $i + 1 + ${#evt2list[*]}))"
    expop="${expop}+img$(( $i + 1 ))"
    psfop="${psfop}+img$(( $i + 1 ))*img$(( $i + 1 + ${#evt2list[*]} ))"
  fi
done
flxop="imgout=((${flxop})*((${expop})/${#evt2list[*]}))"
psfop="imgout=((${psfop})/(${expop}))"
expop="imgout=${expop}"

echo ">>> Merging thresh image/expmap/psfmap..."
punlearn dmimgcalc
dmimgcalc infile="${flxinput}" infile2=none outfile=${outputdir}/merged_broad_expflux.img operation="${flxop}"
punlearn dmimgcalc
dmimgcalc infile="${expinput}" infile2=none outfile=${outputdir}/merged_broad_thresh.expmap operation="${expop}"
punlearn dmimgcalc
dmimgcalc infile="${psfinput}" infile2=none outfile=${outputdir}/merged_broad_thresh.psfmap operation="${psfop}"


cd ${outputdir}

# Run wavdetect
mkdir -v wavdet_halflight

punlearn wavdetect
wavdetect infile=merged_broad_expflux.img \
  regfile=wavdet_halflight/src.reg \
  outfile=wavdet_halflight/source_list.fits \
  scellfile=wavdet_halflight/source_cell.fits \
  imagefile=wavdet_halflight/image.fits \
  defnbkgfile=wavdet_halflight/background.fits \
  expfile=merged_broad_thresh.expmap \
  psffile=merged_broad_thresh.psfmap \
  scales="1 1.414 2 2.828" sigthresh=1e-5 clobber=yes verbose=1 mode=h


# Display source list or not?
read -p "Wanna display source list with image? (y/[N]) > " GO
GO=${GO:-N}
case $GO in
    [Yy]* ) ds9 merged_broad_expflux.img -region wavdet_halflight/src.reg &;;
    [Nn]* ) ls;;
esac

