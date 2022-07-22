#!/bin/bash

# Hydrogen column density from the extinction reddening, E(B-V)

if [ $# -eq 0 ]; then
  read -p ">>> What is the GC's name?: " IDorNAME
  nH=$(Rscript $cTools/CalcnH.R "${IDorNAME}")

  if [ "$nH" == "NA" ];then
    echo "(Warning) An extinction value for $IDorNAME does not exist in Harris GC Catalog (2010)..."
    read -p "        Please input nH (in unit of 1e22) (default: No): " Hmm
    Hmm=${Hmm:-"No"}

    if [ $Hmm==[Nn]* ];then
      return
    else
      echo ">>> Input nH=$Hmm"
      nH=$Hmm
    fi

  else
    echo ">>> nH value is calculated with the extinction from Harris GC catalog (2010):
      [ nH = $nH ]"
  fi
elif [ $# -eq 1 ]; then
  nH=$(Rscript $cTools/CalcnH.R "${1}")

  if [ "$nH" == "NA" ];then
    echo "(Warning) An extinction value for ${1} does not exist in Harris GC Catalog (2010)..."
    read -p "        Please input nH (in unit of 1e22) (default: No): " Hmm
    Hmm=${Hmm:-"No"}

    if [ $Hmm==[Nn]* ];then
      return
    else
      echo ">>> Input nH=$Hmm"
      nH=$Hmm
    fi

  else
    echo ">>> nH value is calculated with the extinction from Harris GC catalog (2010):
      [ nH = $nH ]"
  fi
else
  echo "(Error) An argument must be supplied correctly"
  return
fi


# Generates source and background regions from source list
mkdir -v roi
punlearn roi
roi \
  infile=$(ls matched_output/source_matched_*.fits) \
  outsrc=roi/W_%03d.fits \
  group=indi target=target \
  compute_conf- clob+ mode=h


# Extract source and background regions from ./roi/*fits
for r in roi/*.fits
do
  echo "Creating source & background regions... ($r)"
  regphystocel $r ${r}.srcreg clob+ verb=0
  regphystocel "${r}[bkgreg]" ${r}.bkgreg clob+ verb=0
done


# List files for multiple observation and multiple regions
if [ -f evt2.lis ]; then
  echo "evt2.lis file already exists"
else
  /bin/ls */repro/*evt2.fits >> evt2.lis
fi
if [ -f bpix1.lis ]; then
  echo "bpix1.lis file already exists"
else
  /bin/ls */repro/*repro_bpix1.fits >> bpix1.lis
fi
if [ -f asol1.lis ]; then
  echo "asol1.lis file already exists"
else
  /bin/ls */repro/*asol1.fits >> asol1.lis
fi
if [ -f msk1.lis ]; then
  echo "msk1.lis file already exists"
else
  /bin/ls */repro/*msk1.fits >> msk1.lis
fi
/bin/ls roi/*.srcreg >> srcreg.lis
/bin/ls roi/*.bkgreg >> bkgreg.lis

# Band info
en_lo=(0.3 1.0 2.0 0.3 0.5 1.5 4.5 0.5 0.3 1.5)
en_hi=(1.0 2.0 7.0 7.0 1.5 4.5 6.0 6.0 1.5 7.0)
effen=(0.8 1.5 3.8 1.9 1.0 2.0 5.0 2.0 0.9 3.7) # effective energy (monochromatic energy)

# Run srcflux with roi-regions
punlearn srcflux
srcflux \
  infile=@evt2.lis \
  pos=$(ls matched_output/source_matched_*.fits) \
  srcreg=@srcreg.lis bkgreg=@bkgreg.lis \
  asolfile=@asol1.lis bpixfile=@bpix1.lis mskfile=@msk1.lis\
  model="powlaw1d.p1" paramvals="p1.gamma=1.7;p1.ampl=1e-5"\
  absmodel="xsphabs.abs1" absparams="abs1.nH=$nH"\
  bands="${en_lo[0]}:${en_hi[0]}:${effen[0]},
        ${en_lo[1]}:${en_hi[1]}:${effen[1]},
        ${en_lo[2]}:${en_hi[2]}:${effen[2]},
        ${en_lo[3]}:${en_hi[3]}:${effen[3]},
        ${en_lo[4]}:${en_hi[4]}:${effen[4]},
        ${en_lo[5]}:${en_hi[5]}:${effen[5]},
        ${en_lo[6]}:${en_hi[6]}:${effen[6]},
        ${en_lo[7]}:${en_hi[7]}:${effen[7]},
        ${en_lo[8]}:${en_hi[8]}:${effen[8]},
        ${en_lo[9]}:${en_hi[9]}:${effen[9]}" \
  outroot=sf_output/out \
  bkgresp=no clobber=yes conf=0.90 psfmethod=arfcorr \
  parallel=yes mode=h clob+

# Move .lis files into filelist directory
mkdir -v listfiles
mv *.lis listfiles/

# Copy *.flux files only into ./fluxes/
mkdir -v fluxes
cp sf_output/*.flux fluxes/
