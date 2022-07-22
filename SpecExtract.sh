#!/bin/bash

#############################################################
#                                                           #
#  SpecExtract.sh (Ver 1.2)                                 #
#  ------------------------------------------------------   #
#  Spectrum extraction right after "chandra_repro" !        #    
#                                                           #
#  * Pre-requisites: ./regions/                             #
#                    ./regions/(source region files),       #
#                              (background region file)     #
#  * Run this outside ObsID directory                       #
#  ------------------------------------------------------   #
#                                                           #
#############################################################


# Initailze HEASOFT and CIAO
heainit              # HEASOFT 
ciao -o &>/dev/null  # CIAO

echo "
>>> HEASOFT and CIAO are initialized!"


#=========================== Setting and Checking =================================
# Start from outside of ObsID directory
rootdir=$(pwd)


# Check an argument OR input dir name
if [ $# -eq 0 ]; then
    read -p ">>> What is 'indir' to extract spectrum? (e.g. ObsID, all) " obsdir
    if [ $obsdir == 'all' ]; then
        lis0=($(find . -name secondary))
        obslis=()
        for li in ${lis0[*]}; do
            li2=(${li//\// })
            li3=${li2[1]}
            echo $li3
            obslis+=($li3)
        done
        
        for dir in ${obslis[*]}; do
            if [ ! -d $dir ]; then
                echo "(error) No such directory exists: $dir/"
                return
            fi
        done
    else
        if [ ! -d $obsdir ]; then
            echo "(error) No such directory exists: $obsdir/"
            return
        fi
    fi
else
    obsdir="$1" # For a given first argument
    if [ $obsdir == 'all' ]; then
        lis0=($(find . -name secondary))
        obslis=()
        for li in ${lis0[*]}; do
            li2=(${li//\// })
            li3=${li2[1]}
            echo $li3
            obslis+=($li3)
        done

        for dir in ${obslis[*]}; do
            if [ ! -d $dir ]; then
                echo "(error) No such directory exists: $dir/"
                return
            fi
        done
    else
        if [ ! -d $obsdir ]; then
            echo "(error) No such directory exists: $obsdir/"
            return
        fi
    fi
fi


# Check regions directory in rootdir
if [ ! -d "regions" ]; then
    echo "(error) No regions directory in $rootdir/"
    return
else
    # Check a file name of the background region (default: bkg.reg)
    read -p ">>> Background region name (default: bkg.reg): " bkg_reg
    bkg_reg=${bkg_reg:-bkg.reg}
    
    if [ ! -f "$rootdir/regions/$bkg_reg" ]; then
        echo "(error) No such file exists in directory ($rootdir/regions/): $bkg_reg"
        return
    fi

    echo ">>> Following regions are found in $rootdir/regions/"
    region_list=($(ls ./regions | grep -v "$bkg_reg"))
    echo "  |For sources:  ${region_list[*]}"
    echo "  |and for a background:  $bkg_reg"
fi


if [ $obsdir == 'all' ]; then
    total_iter=$(python -c "print(${#obslis[*]}*${#region_list[*]})")
    iter=1
    for dir in ${obslis[*]}; do
        # Check repro/ directory in rootdir/dir/

        cd $dir                                     
        if [ ! -d "repro" ]; then
            echo "(error) No such directory in $rootdir/$dir/: (repro/)"
            cd $rootdir
            return
        fi
        
        
        # Create spec/ directory in rootdir/dir/
        mkdir -v spec
        
        
        # Assign input files from repro/
        if ls ./repro/*evt2* 1> /dev/null 2>&1 ; then
            evtfile="$rootdir/$dir/repro/$(ls ./repro/ | grep 'evt2')"
        else
            echo "(error) No event file exists in directory ($rootdir/$dir/repro/)"
            cd $rootdir
            return
        fi
        if ls ./repro/*repro_bpix1* 1> /dev/null 2>&1 ; then
            bpxfile="$rootdir/$dir/repro/$(ls ./repro/ | grep 'repro_bpix1')"
        else
            echo "(error) No bad pixel file exists in directory ($rootdir/$dir/repro/)"
            cd $rootdir
            return
        fi
        if ls ./repro/*asol1.fits 1> /dev/null 2>&1 ; then 
            aspfile="$rootdir/$dir/repro/$(ls ./repro/ | grep 'asol1.fits')"
        else
            echo "(error) No asol file exists in directory ($rootdir/$dir/repro/)"
            cd $rootdir
            return
        fi
        if ls ./repro/*msk1* 1> /dev/null 2>&1 ; then
            mskfile="$rootdir/$dir/repro/$(ls ./repro/ | grep 'msk1')"
        else
            echo "(error) No mask file exists in directory ($rootdir/$dir/repro/)"
            cd $rootdir
            return
        fi    
        echo ">>> Following files are found in directory ($rootdir/$dir/repro/)
     |event file: $evtfile
     |bad pixel : $bpxfile
     |asol file : $aspfile
     |mask file : $mskfile"
        #==================================================================================
        
        
        #================ Run specextract (CIAO) for the region list ======================
        echo ">>> Running specextract (CIAO)... for ${region_list[*]}"
        
        for src_reg in ${region_list[*]}; do
            outname=(${src_reg//./ })
            mkdir $rootdir/$dir/spec/${outname[0]}
        
            dmcopy "$evtfile[sky=region($rootdir/regions/${src_reg})]" $rootdir/$dir/spec/${outname[0]}/source_${outname[0]}.fits verbose=0
            
            punlearn ardlib
            acis_set_ardlib $bpxfile verbose=0
            
            printf " Spectrum Extracting... ( $iter / $total_iter )"
            punlearn specextract
            specextract infile="$evtfile[sky=region($rootdir/regions/${src_reg})]"\
                        outroot="$rootdir/$dir/spec/${outname[0]}/${outname[0]}"\
                        bkgfile="$evtfile[sky=region($rootdir/regions/${bkg_reg})]"\
                        asp="$aspfile"\
                        mskfile="$mskfile"\
                        badpixfile="$bpxfile"\
                        weight=no correct=no\
                        grouptype=NONE binspec=NONE\
                        verbose=0 clobber=yes

            iter=$(($iter + 1))
        cd $rootdir

        done
    done
        #==================================================================================
else
    # Check repro/ directory in rootdir/obsdir/
    cd $obsdir                                     
    if [ ! -d "repro" ]; then
        echo "(error) No such directory in $rootdir/$obsdir/: (repro/)"
        cd $rootdir
        return
    fi
    
    
    # Create spec/ directory in rootdir/obsdir/
    mkdir -v spec
    
    
    # Assign input files from repro/
    if ls ./repro/*evt2* 1> /dev/null 2>&1 ; then
        evtfile="$rootdir/$obsdir/repro/$(ls ./repro/ | grep 'evt2')"
    else
        echo "(error) No event file exists in directory ($rootdir/$obsdir/repro/)"
        cd $rootdir
        return
    fi
    if ls ./repro/*repro_bpix1* 1> /dev/null 2>&1 ; then
        bpxfile="$rootdir/$obsdir/repro/$(ls ./repro/ | grep 'repro_bpix1')"
    else
        echo "(error) No bad pixel file exists in directory ($rootdir/$obsdir/repro/)"
        cd $rootdir
        return
    fi
    if ls ./repro/*asol1.fits 1> /dev/null 2>&1 ; then 
        aspfile="$rootdir/$obsdir/repro/$(ls ./repro/ | grep 'asol1.fits')"
    else
        echo "(error) No asol file exists in directory ($rootdir/$obsdir/repro/)"
        cd $rootdir
        return
    fi
    if ls ./repro/*msk1* 1> /dev/null 2>&1 ; then
        mskfile="$rootdir/$obsdir/repro/$(ls ./repro/ | grep 'msk1')"
    else
        echo "(error) No mask file exists in directory ($rootdir/$obsdir/repro/)"
        cd $rootdir
        return
    fi    
    echo ">>> Following files are found in directory ($rootdir/$obsdir/repro/)
     |event file: $evtfile
     |bad pixel : $bpxfile
     |asol file : $aspfile
     |mask file : $mskfile"
    #==================================================================================
    
    
    #================ Run specextract (CIAO) for the region list ======================
    echo ">>> Running specextract (CIAO)... for ${region_list[*]}"
    
    for src_reg in ${region_list[*]}; do
        outname=(${src_reg//./ })
        mkdir $rootdir/$obsdir/spec/${outname[0]}
    
        dmcopy "$evtfile[sky=region($rootdir/regions/${src_reg})]" $rootdir/$obsdir/spec/${outname[0]}/source_${outname[0]}.fits verbose=0
        
        punlearn ardlib
        acis_set_ardlib $bpxfile verbose=0
    
        punlearn specextract
        specextract infile="$evtfile[sky=region($rootdir/regions/${src_reg})]"\
                    outroot="$rootdir/$obsdir/spec/${outname[0]}/${outname[0]}"\
                    bkgfile="$evtfile[sky=region($rootdir/regions/${bkg_reg})]"\
                    asp="$aspfile"\
                    mskfile="$mskfile"\
                    badpixfile="$bpxfile"\
                    weight=no correct=no\
                    grouptype=NONE binspec=NONE\
                    verbose=0 clobber=yes
    
    done
    #==================================================================================
fi
 
echo "
>>> For ${region_list[*]},
    Source spectrum is extracted!"

read -p "Wanna go back to $rootdir? (default:y) > " GO
GO=${GO:-y}
case $GO in
    [Yy]* ) cd $rootdir; pwd; ls;;
    [Nn]* ) pwd; ls;;
esac
