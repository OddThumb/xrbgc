#!/bin/bash

# =========================================================
#                (0) Input Script Arguments
# =========================================================
# Help text
usage="ReprojWav [-h] [-r]
where:
      -h  show this help text
      -r  Reference ObsID"

while getopts ":hr:" opt; do
    case $opt in
        h)  echo "$usage"
            exit 0
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
#               (0) Run FluxImg with default
# =========================================================
source ${xrbgc}/bashs/FluxImg.sh
flux_dir='fluxed'


# =========================================================
#             (1) Wavdetect for source matching
# =========================================================
# Create wavdet_dir
wavdet_dir=$flux_dir/wavdet
mkdir ${wavdet_dir}

# Iterate wavdet over obs_list
obs_list=()
dir_list=$(dirname $flux_dir/*/*.fov)
for dir in ${dir_list[@]}; do
    dirarr=(${dir//\// })
    obs=${dirarr[1]}
    obs_list[${#obs_list[@]}]=${obs}
    printf "wavdetect...ing on ObsID: ${obs}\n"

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
    printf "wcs_match...ing on ObsID: ${wcs} with ${ref} as reference\n"

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

#    # Update evt file
#    dmcopy ${wcs}/repro/*_repro_evt2.fits ${wcsmatch_dir}/${wcs}_corr_evt2.fits
#    punlearn wcs_update
#    pset wcs_update infile=${wcsmatch_dir}/${wcs}_corr_evt2.fits
#    pset wcs_update outfile=
#    pset wcs_update transformfile=${wcsmatch_dir}/${wcs}_out.xform
#    wcs_update mode=h
#
#    # Update header
#    dmhedit ${wcsmatch_dir}/${wcs}_corr_evt2.fits file= op=add key=ASOLFILE value=$(realpath ${wcsmatch_dir}/${wcs}_corr_asol1.fits)

    # reproject_events
    punlearn reproject_events
    pset reproject_events infile=$(/bin/ls ${wcs}/repro/*repro_evt2.fits)
    pset reproject_events outfile=${wcs}/repro/${wcs}_reproj_evt2.fits
    pset reproject_events aspect=${wcsmatch_dir}/${wcs}_corr_asol1.fits
    reproject_events mode=h
done



# =========================================================
#              (3) merge_obs & wavdetect again
# =========================================================
# Listing wcs corrected event files
/bin/ls ${ref}/repro/*repro_evt2.fits >> reproj.lis
/bin/ls */repro/*reproj_evt2.fits >> reproj.lis

# merge_obs
punlearn merge_obs
merge_obs @reproj.lis merged_half/ binsize=0.5 psfecf=0.9 psfmerge=expmap

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




