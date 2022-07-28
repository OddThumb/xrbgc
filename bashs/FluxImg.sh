#!/bin/bash

# =========================================================
#                    (-1) Pre-requisite
# =========================================================
# Custom templates
en_lo=(0.3 1.0 2.0 0.3 0.5 1.5 4.5 0.5)
en_hi=(1.0 2.0 7.0 7.0 1.5 4.5 6.0 6.0)
effen=(0.8 1.5 3.8 1.9 1.0 2.0 5.0 2.0) # effective energy (monochromatic energy)

# CSC (Chandra Source Catalog) bands
CSCband="  | band name | en_lo:en_hi:effen 
  | broad     |  0.5 : 7.0 : 2.3
  | soft      |  0.5 : 1.2 : 0.92
  | medium    |  1.2 : 2.0 : 1.56
  | hard      |  2.0 : 7.0 : 3.8
  | ultrasoft |  0.2 : 0.5 : 0.4
  | wide      |  N/A : N/A : 1.5
    
    * csc  = soft + medium + hard
"

# =========================================================
#                (0) Input Script Arguments
# =========================================================
# Help text
usage="FluxImg [-h] [-b -s]
where:
      -h  Show this help text
      -b  Band name, index, lo:hi:eff or their combination
          e.g.) -b \"0,1,csc,ultrasoft,0.5:1.5:0.8\"
                -b broad (default)
      -s  Binning factor size (default=0.5)

Band info:
  * Custom band templates           * CSC band templates
    |index|  en_lo:en_hi:effen        | band name | en_lo:en_hi:effen
    |  0  |   ${en_lo[0]} : ${en_hi[0]} : ${effen[0]}         | broad     |  0.5 : 7.0 : 2.3
    |  1  |   ${en_lo[1]} : ${en_hi[1]} : ${effen[1]}         | soft      |  0.5 : 1.2 : 0.92
    |  2  |   ${en_lo[2]} : ${en_hi[2]} : ${effen[2]}         | medium    |  1.2 : 2.0 : 1.56
    |  3  |   ${en_lo[3]} : ${en_hi[3]} : ${effen[3]}         | hard      |  2.0 : 7.0 : 3.8
    |  4  |   ${en_lo[4]} : ${en_hi[4]} : ${effen[4]}         | ultrasoft |  0.2 : 0.5 : 0.4
    |  5  |   ${en_lo[5]} : ${en_hi[5]} : ${effen[5]}         | wide      |  N/A : N/A : 1.5
    |  6  |   ${en_lo[6]} : ${en_hi[6]} : ${effen[6]}        
    |  7  |   ${en_lo[7]} : ${en_hi[7]} : ${effen[7]}          * csc  = soft + medium + hard
    "

Bands="broad"
binSize=0.5 # Default argument: binning factor of 0.5
# Get arguments
while getopts ":hb:s:" opt; do
    case $opt in
        h)  echo "$usage"
            exit 0
            ;;
        b)  Bands="$OPTARG"
            ;;
        s)  binSize="$OPTARG"
            ;;
        :)  printf "Missing argument for -%s\n" "$OPTARG" >&2
            echo "$usage" >&2
            exit 1
            ;;
        \?) printf "Illegal option: -%s\n" "$OPTARG" >&2
            echo "$usage" >&2
            exit 1
            ;;
    esac
done

# Function: Concatenating array elements into string with a delimiter
function concat { local IFS="$1"; shift; echo "$*"; }

# Arranging input argument bands and checking them
inputBands=()
arrBands=(${Bands//,/ })
for band in ${arrBands[@]}; do
    case $band in
        [0-7]) 
            band=${en_lo[$band]}:${en_hi[$band]}:${effen[$band]}
            echo "Template band is detected: $band"
            inputBands[${#inputBands[@]}]=$band
            ;;
        broad|soft|medium|hard|ultrasoft|wide|csc)
            echo "CSC band is detected: $band"
            inputBands[${#inputBands[@]}]=$band
            ;;
        *:*:*)
            echo "Manual band is detected: $band"
            inputBands[${#inputBands[@]}]=$band
            ;;
        *)
            echo "(ERROR) Please check this band expression: $band" >&2
            exit 2
            ;;
    esac
done
inputBands=$(concat , ${inputBands[@]})

# Re-check all input bands
echo "Fluximage on these bands will proceed: ${inputBands}"



# =========================================================
#                     (1) Fluximage
# =========================================================
obs_list=$(dirname */repro)
mkdir fluxed
for obs in ${obs_list[@]}; do
    echo "Working in ObsID: $obs"
    mkdir fluxed/$obs
    evt2file=$(/bin/ls $obs/repro/*repro_evt2.fits)
    bpix1file=$(/bin/ls $obs/repro/*repro_bpix1.fits)
    msk1file=$(/bin/ls $obs/repro/*msk1.fits)
    asol1file=$(/bin/ls $obs/repro/*asol1.fits)

    punlearn fluximage
    pset fluximage infile=${evt2file}
    pset fluximage outroot=fluxed/$obs/
    pset fluximage bands=${inputBands}
    pset fluximage binsize=${binSize}
    pset fluximage asolfile=${asol1file}
    pset fluximage badpixfile=${bpix1file}
    pset fluximage maskfile=${msk1file}
    pset fluximage parallel=yes
    fluximage mode=h
done

