#!/bin/bash

# =========================================================
#                (0) Input Script Arguments
# =========================================================
# Help text
usage="WCScorr [-h] [-f -r]
where:
      -h  show this help text
      -f  Flux image directory (default: fluxed)
      -r  Reference ObsID"

flux_dir='fluxed'
while getopts ":hf:r:" opt; do
    case $opt in
        h)  echo "$usage"
            exit 0
            ;;
        f)  flux_dir="$OPTARG"
            ;;
        r)  ref="$OPTARG"
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


# =========================================================
#             (1) Wavdetect for source matching
# =========================================================
# Create wavdet_dir
wavdet_dir=$flux_dir/wavdet
mkdir wavdet_dir

# Iterate wavdet over obs_list
obs_list=()
dir_list=$(dirname $flux_dir/*/*.fov)
for dir in ${dir_list[@]}; do
    dirarr=(${dir//\// })
    obs=${dirarr[1]}
    obs_list[${#obs_list[@]}]=${obs}
    printf "wavdetect...ing in ObsID: ${obs}\n"

    # Making PSF map
    punlearn mkpsfmap
    mkpsfmap ${dir}/broad_thresh.img ${dir}/broad_thresh.psfmap energy=2.3 ecf=0.9 mode=h clob+

    # Run wavdetect
    punlearn wavdetect
    pset wavdetect infile=${dir}/broad_thresh.img
    pset wavdetect psffile=${dir}/broad_thresh.img
    pset wavdetect expfile=${dir}/broad_thresh.expmap
    pset wavdetect scales="1 2 4 6 8 12 16 24 32"
    pset wavdetect outfile=${wavdet_dir}/${obs}_broad.src
    pset wavdetect scell=${wavdet_dir}/${obs}_broad.cell
    pset wavdetect imagefile=${wavdet_dir}/${obs}_broad.recon
    pset wavdetect defnbkg=${wavdet_dir}/${obs}_broad.nbkg
    pset wavdetect interdir=${wavdet_dir}
    wavdetect mode=h clobber=yes
done


# =========================================================
#                (2) wcs_match & wcs_update
# =========================================================
# Only reference obsid is excluded
wcs_list=${obs_list[@]/${ref}}

# Create wcsmatch_dir
wcsmatch_dir=$flux_dir/wcsmatch
mkdir ${wcsmatch_dir}

# Iterate wcs_match & wcs_update over wcs_list
for wcs in ${wcs_list[@]}; do
    # Generate transformation file by wcs matching 
    punlearn wcs_match
    pset wcs_match infile=${wavdet_dir}/${wcs}_broad.src
    pset wcs_match refsrcfile=${wavdet_dir}/${ref}_broad.src
    pset wcs_match outfile=${wcsmatch_dir}/${wcs}_out.xform
    pset wcs_match wcsfile=${flux_dir}/${wcs}/broad_thresh.img
    pset wcs_match method=trans
    wcs_match mode=h

    # Update asol file
    punlearn wcs_update
    pset wcs_update infile=${wcs}/repro/*_asol1.fits
    pset wcs_update outfile=${wcsmatch_dir}/${wcs}_corr_asol1.fits
    pset wcs_update transformfile=${wcsmatch_dir}/${wcs}_out.xform
    pset wcs_update wcsfile=${flux_dir}/${wcs}/broad_thresh.img
    wcs_update mode=h

    # Update evt file
    dmcopy ${wcs}/repro/*_repro_evt2.fits ${wcsmatch_dir}/${wcs}_corr_evt2.fits
    punlearn wcs_update
    pset wcs_update infile=${wcsmatch_dir}/${wcs}_corr_evt2.fits
    pset wcs_update outfile=
    pset wcs_update transformfile=${wcsmatch_dir}/${wcs}_out.xform
    wcs_update mode=h

    # Update header
    dmhedit ${wcsmatch_dir}/${wcs}_corr_evt2.fits file= op=add key=ASOLFILE value=${wcsmatch_dir}/${wcs}_corr_asol1.fits
done


# =========================================================
#              (3) merge_obs & wavdetect again
# =========================================================
# Listing wcs corrected event files
/bin/ls ${wcsmatch_dir}/*_corr_evt2.fits >> corr_evt2.lis

# merge_obs
punlearn merge_obs
merge_obs @corr_evt2.lis merged_half/ binsize=0.5 psfecf=0.9 psfmerge=expmap

# wavdetect
mkdir merged_half/wavdet
punlearn wavdetect
wavdetect infile=merged_half/broad_thresh.img \
    regfile=merged_half/wavdet/src.reg \
    outfile=merged_half/wavdet/source_list.fits \
    scellfile=merged_half/wavdet/source_cell.fits \
    imagefile=merged_half/wavdet/image.fits \
    defnbkgfile=merged_half/wavdet/background.fits \
    expfile=merged_half/broad_thresh.expmap \
    psffile=merged_half/broad_thresh.psfmap \
    scales="1 1.414 2 2.828" sigthresh=1e-5 clobber=yes verbose=1 mode=h





