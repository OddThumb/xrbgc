#!/bin/bash

# =========================================================
#                    (-1) Pre-requisite
# =========================================================
# Select spectral model
models=('xspowerlaw.p1' \
        'xsbbodyrad.b1' \
        'xsapec.a1')
params=("p1.PhoIndex=1.7;p1.norm=1e-5" \
        "b1.kT=3;b1.norm=1"\
        "a1.kT=1;a1.norm=1")

# Band info
en_lo=(0.3 1.0 2.0 0.3 0.5 1.5 4.5 0.5)
en_hi=(1.0 2.0 7.0 7.0 1.5 4.5 6.0 6.0)
effen=(0.8 1.5 3.8 1.9 1.0 2.0 5.0 2.0) # effective energy (monochromatic energy)


# =========================================================
#                (0) Input Script Arguments
# =========================================================
# Help text
usage="Srcflux [-h] [-n -p]
where:
      -h  show this help text
      -n  GC name with white space. e.g.) '47 Tuc'
      -p  Parameter index
          |index|  model
          |  0  | ${models[0]} (default)
          |  1  | ${models[1]}
          |  2  | ${models[2]}"
paramidx=0 # default: xspowerlaw.p1; p1.PhoIndex=1.7; p1.norm=1e-5
while getopts ":hn:p:r:" opt; do
    case $opt in
        h)  echo "$usage"
            exit 0
            ;;
        n)  IDorNAME="$OPTARG"
            ;;
        p)  paramidx="$OPTARG"
            ;;
        :)  printf "missing argument for -%s\n" "$OPTARG" >&2
            echo "$usage" >&2
            exit 1
            ;;
        \?) printf "illegal option: -%s\n" "$OPTARG" >&2
            echo "$usage" >&2
            exit 1
            ;;
    esac
done


# =========================================================
#            (1) Printing out Chosen Arguments
# =========================================================
# Checking spectral parameters 
case $paramidx in
    [0-2]) echo "
>>> Selected model and its parameters for chosen model is:"
    echo "   *model: ${models[$paramidx]}
   *param: ${params[$modelidx]}"
selected_model=${models[$paramidx]}
selected_param=${params[$paramidx]}
    ;;
    *) echo "(ERROR) Parameter index (-p) between 0-2
 [ Spectral models ]
   index   model
     0  : ${models[0]}
     1  : ${models[1]}
     2  : ${models[2]}" >&2
    exit 2
esac


# =========================================================
#  (2) Get Hydrogen Column Density from Harris Cat (2010)
# =========================================================
# Get nH from Harris GC Catalog
nH=$(rCalcnH "${IDorNAME}")

if [ "$nH" == "NA" ];then
  echo "(Error) An extinction value for $IDorNAME does not exist in Harris GC Catalog (2010)..." >&2
  exit 2
else
  echo ">>> Input nH=$nH"
fi


# =========================================================
#                   (3) Input Observations
# =========================================================
# List files for multiple observation
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


# =========================================================
#                    (4) Making Regions 
# =========================================================
# Generates source and background regions from source list
mkdir -v roi
punlearn roi
roi \
  infile=$(ls matched_output/source_matched_*.fits) \
  outsrc=roi/W_%03d.fits \
  group=indi target=target \
  compute_conf- clob+ mode=h

#if [ -d roi ]; then
if [ -f info/bkg.reg ]; then
#  echo "roi directory is found"
  printf "\nBackground region (info/bkg.reg) is found\n"
  
  # Extract source and background regions from ./roi/*fits
  for r in roi/*.fits
  do
    echo "Creating source regions... ($r)"
    regphystocel $r ${r}.srcreg clob+ verb=0
  done

  # For srcflux input regions
  if [ -f srcreg.lis ]; then
    echo "srcreg.lis file already exists"
  else
    /bin/ls roi/*.srcreg >> srcreg.lis
  fi
  
  # Listing same background region with same number as the number of source regions 
  nlines=$(($(wc -l < matched_output/matched_sourcetypes_0.5.csv)-1))
  for i in `seq 1 ${nlines}`; do
    echo "info/bkg.reg" >> bkgreg.lis
  done
  
else
  echo "info/bkg.reg is not given, annulus background regions will be used"
  
  # Extract source and background regions from ./roi/*fits
  for r in roi/*.fits
  do
    echo "Creating source & background regions... ($r)"
    regphystocel $r ${r}.srcreg clob+ verb=0
    regphystocel "${r}[bkgreg]" ${r}.bkgreg clob+ verb=0
  done

  # For srcflux input regions
  if [ -f srcreg.lis ]; then
    echo "srcreg.lis file already exists"
  else
    /bin/ls roi/*.srcreg >> srcreg.lis
  fi
  if [ -f bkgreg.lis ]; then
    echo "bkgreg.lis file already exists"
  else
    /bin/ls roi/*.bkgreg >> bkgreg.lis
  fi
  
fi


# =========================================================
#                      (5) Run srcflux
# =========================================================
# Run srcflux
punlearn srcflux
srcflux \
  infile=@evt2.lis \
  pos=$(ls matched_output/source_matched_*.fits) \
  srcreg=@srcreg.lis bkgreg=@bkgreg.lis \
  asolfile=@asol1.lis bpixfile=@bpix1.lis mskfile=@msk1.lis \
  absmodel="xsphabs.abs1" \
  absparams="abs1.nH=$nH" \
  model="${selected_model}" \
  paramvals="${selected_param}" \
  bands="${en_lo[0]}:${en_hi[0]}:${effen[0]},
         ${en_lo[1]}:${en_hi[1]}:${effen[1]},
         ${en_lo[2]}:${en_hi[2]}:${effen[2]},
         ${en_lo[3]}:${en_hi[3]}:${effen[3]},
         ${en_lo[4]}:${en_hi[4]}:${effen[4]},
         ${en_lo[5]}:${en_hi[5]}:${effen[5]},
         ${en_lo[6]}:${en_hi[6]}:${effen[6]},
         ${en_lo[7]}:${en_hi[7]}:${effen[7]}" \
  outroot=srcflux_${selected_model}/${selected_model} \
  bkgresp=no clobber=yes conf=0.90 psfmethod=arfcorr \
  parallel=yes mode=h clob+


# =========================================================
#                   (6) Organizing Outputs
# =========================================================
# Orginaizing directory
# Move .lis files into filelist directory
mkdir -v listfiles
mv *.lis listfiles/

# Copy *.flux files only into ./fluxes/
mkdir -v fluxes_${selected_model}
cp srcflux_${selected_model}/*.flux fluxes_${selected_model}

###################### End of Script ######################
