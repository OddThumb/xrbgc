#############################################################
#  *** Revised from the code written by Kwan Lok Li ***     #
#                                                           #
#  SpecFitting.sh (Ver 1.3)                                 #
#  ------------------------------------------------------   #
#  Spectrum fitting with absorbed power-law model for       #
#    all source list in region/ directory                   #
#                                                           #
#  * Pre-requisites: ./regions/                             #
#                    ./regions/(source region files),       #
#                              (background region file)     #
#  * Run this outside ObsID directory                       #
#                                                           #
#  * Input: "ObsID number (directory name)" or "all",       #
#                                                           #
#  * Output: Estimated flux with given parameters           #
#            (regionName_elo_ehi_pow.result: flux           #
#             regionName_elo_ehi_pow.ps: spectrum           #
#                                                           #
#            where regionName: source region name,          #
#                  elo: lower limit of energy band,         #
#                  ehi: upper limit of energy band)         #
#  ------------------------------------------------------   #
#                                                           #
#############################################################

# Initailze HEASOFT and CIAO
heainit              # HEASOFT
ciao -o &>/dev/null  # CIAO

echo "
>>> HEASOFT and CIAO are initialized!"


#============================ Fitting function in XSPEC ===========================
function xfit_flux
{ #xfit_flux start
cmd='query yes
set fileid [open '$id'_'${enrange[0]}'_'${enrange[1]}'_pow.result w]
statistic cstat
setplot energy
data '$id'_bin1.pi
ignore bad
ignore **-'${enrange[0]}','${enrange[1]}'-**

set nh [expr '${nh}' / 1e22]
set pl [expr '${pl}']

model phabs(pow) & $nh,-1 & $pl, -1 & 1e-5 &
scan [tcloutr dof] "%d" nbin

if { $nbin > 5 } {
	fit 10000

	editmod phabs*cflux(pow) & '${enrange[0]}',-1 & '${enrange[1]}',-1 & -12 & /*

	fr 6
	fit 10000


	scan [tcloutr stat] "%f" cstat
	scan [tcloutr dof] "%d" dof

	set npars [tcloutr modpar]
	for { set i 1 } { $i <= $npars } { incr i } {

		tclout param $i
		scan $xspec_tclout "%f %f" par par2

		if { $dof > 0 && $par2 != -1 } {
			err 1.0 $i
			tclout error $i
			scan $xspec_tclout "%f %f" errmin errmax
			tclout param $i
			scan $xspec_tclout "%f %f" par par2
			set parloerr [expr $par - $errmin]
			set parhierr [expr $errmax - $par]

		} elseif { $par2 == -1 } {
		} else {
		}
	}

flux '${enrange[0]}' '${enrange[1]}' err 1000 90
tclout flux
scan [tcloutr flux] "%f %f %f" flux fluxlo fluxhi

# Parameter for cflux
err 4
tclout error 4
scan $xspec_tclout "%f %f" errmin errmax
tclout param 4
scan $xspec_tclout "%f %f" logunflux par2

scan [tcloutr stat] "%f" cstat
scan [tcloutr dof] "%d" dof

set unfluxloerr [expr pow(10,$logunflux) - pow(10,$errmin)]
set unfluxhierr [expr pow(10,$errmax) - pow(10,$logunflux)]
set unflux [expr pow(10,$logunflux)]
puts $fileid [format " %s %0.3e -%0.3e +%0.3e" '$id' $unflux $unfluxloerr $unfluxhierr]
setplot rebin 3 20
cpd '$id'_'${enrange[0]}'_'${enrange[1]}'_pow.ps/ps
setplot co time off
setplot co LA T '$id'_'${enrange[0]}'_'${enrange[1]}'_pow
plot ldata ratio
}

close $fileid
quit'
echo -e "$cmd" > xspec_flux.cmd
xspec - xspec_flux.cmd
} # End of xfit_flux

function xfit_absflux
{ #xfit_absflux start
cmd='query yes
set fileid [open '$id'_'${enrange[0]}'_'${enrange[1]}'_phabs_pow.result w]
statistic cstat
setplot energy
data '$id'_bin1.pi
ignore bad
ignore **-'${enrange[0]}','${enrange[1]}'-**

set nh [expr '${nh}' / 1e22]
set pl [expr '${pl}']

model phabs(pow) & $nh,-1 & $pl, -1 & 1e-5 &
scan [tcloutr dof] "%d" nbin

if { $nbin > 5 } {
  fit 10000

  editmod cflux(phabs(pow)) & '${enrange[0]}',-1 & '${enrange[1]}',-1 & -12 & /*

  fr 6
  fit 10000
  fit 10000


  scan [tcloutr stat] "%f" cstat
  scan [tcloutr dof] "%d" dof

  set npars [tcloutr modpar]
  for { set i 1 } { $i <= $npars } { incr i } {

    tclout param $i
    scan $xspec_tclout "%f %f" par par2

    if { $dof > 0 && $par2 != -1 } {
      err 1.0 $i
      tclout error $i
      scan $xspec_tclout "%f %f" errmin errmax
      tclout param $i
      scan $xspec_tclout "%f %f" par par2
      set parloerr [expr $par - $errmin]
      set parhierr [expr $errmax - $par]

    } elseif { $par2 == -1 } {
    } else {
    }
  }

flux '${enrange[0]}' '${enrange[1]}' err 1000 90
tclout flux
scan [tcloutr flux] "%f %f %f" flux fluxlo fluxhi

# Parameter for cflux
err 3
tclout error 3
scan $xspec_tclout "%f %f" errmin errmax
tclout param 3
scan $xspec_tclout "%f %f" logunflux par2

scan [tcloutr stat] "%f" cstat
scan [tcloutr dof] "%d" dof

set unfluxloerr [expr pow(10,$logunflux) - pow(10,$errmin)]
set unfluxhierr [expr pow(10,$errmax) - pow(10,$logunflux)]
set unflux [expr pow(10,$logunflux)]
puts $fileid [format " %s %0.3e -%0.3e +%0.3e" '$id' $unflux $unfluxloerr $unfluxhierr]
setplot rebin 3 20
cpd '$id'_'${enrange[0]}'_'${enrange[1]}'_phabs_pow.ps/ps
setplot co time off
setplot co LA T '$id'_'${enrange[0]}'_'${enrange[1]}'_phabs_pow
plot ldata ratio
}

close $fileid
quit'
echo -e "$cmd" > xspec_absflux.cmd
xspec - xspec_absflux.cmd
} # End of xfit_absflux
#==================================================================================

#=========================== Setting and Checking =================================
# Start from outside of ObsID directory
rootdir=$(pwd)

# Check an argument OR input dir name
if [ $# -eq 0 ]; then
    read -p ">>> What is 'indir' to extract spectrum? (e.g. ObsID, all): " obsdir
else
    obsdir=$1 # For a given first argument
fi

if [ $obsdir == 'all' ]; then
    lis0=($(find . -name secondary))
    obslis=()
    for li in ${lis0[*]}; do
        li2=(${li//\// })
        li3=${li2[1]}
        obslis+=($li3)
    done

    for dir in ${obslis[*]}; do
        # Check dir/ directory exists
        if [ ! -d $dir ]; then
            echo "(error) No such directory exists: $dir/"
            return
        fi

        # Check spec/ directory exists
        if [ ! -d $dir/spec ]; then
            echo "(error) No such directory exists: $obsdir/spec/"
            echo "        First, you need to run 'SpecExtract.sh'"
            return
        fi

        # 

    done
else
    # Check obsdir/ directory exists
    if [ ! -d $obsdir ]; then
        echo "(error) No such directory exists: $obsdir/"
        return
    fi

    # Check spec/ directory exists
    if [ ! -d $obsdir/spec ]; then
        echo "(error) No such directory exists: $obsdir/spec/"
        echo "        First, you need to run 'SpecExtract.sh'"
        return
    fi
fi
#==================================================================================


#============================= Spectral Fitting ===================================
# Set energy range
read -p ">>> Input energy range in keV (0.5-6.0: default)
     e.g. band1/band2/band3: each band need to be split by '/',
          energies (in keV) need to be split by '-': " inputBands
inputBands=${inputBands:-'0.5-6.0'}

# Check band format
checkBands=(${inputBands//\// })
read -p ">>> There are ${#checkBands[*]} input band(s):   ${checkBands[*]}
    Keep going? (y) > " GO
GO=${GO:-y}
case $GO in
    [Yy]* ) echo '';;
    [Nn]* ) return;;
esac 


# Set nh and pl
read -p ">>> Input nH value (e.g. 1e21): " nh
read -p ">>> Input power-law index (e.g. 1.7, default): " pl
pl=${pl:-1.7}


if [ $obsdir == 'all' ]; then
    # Loop over bands
    for band in ${checkBands[*]}; do
        enrange=(${band//-/ })
        
        # Loop over ObsIDs
        for dir in ${obslis[*]}; do
            # Go to spec/
            cd $dir/spec/
            
            # Source spectrum list
            speclist=$(command ls)
            
            # Loop over spectral fitting for source list
            for id in ${speclist[*]}; do
                cd ${id}

                if [[ ( $(ls *.pi | wc -l) -eq 2 ) && ( $(ls *.arf | wc -l) -eq 2 ) && ( $(ls *.rmf | wc -l) -eq 2 ) ]]; then
                    echo -e "group min 1\nexit" | grppha ${id}.pi \!${id}_bin1.pi
                
                    # Calling the Script
                    xfit_flux
                    xfit_absflux

                    # Save result together
                    echo ${enrange[0]} ${enrange[1]} ${dir} $(cat ${id}_${enrange[0]}_${enrange[1]}_pow.result) >> $rootdir/Result_flux
                    echo ${enrange[0]} ${enrange[1]} ${dir} $(cat ${id}_${enrange[0]}_${enrange[1]}_phabs_pow.result) >> $rootdir/Result_absflux
                else
                    echo "For $dir/$id, not enough spectrum files (pi/arf/rmf)"
                    echo "${enrange[0]} ${enrange[1]} ${dir} ${id}" >> $rootdir/NotEnoughSpec
                fi
                
                cd ..
            done
        done
    done
else
    # Loop over bands
    for band in ${checkBands[*]}; do
        enrange=(${band//-/ })

        # Go to spec/ directory
        cd $obsdir/spec/
        
        # Source spectrum list
        speclist=$(command ls)
        
        # Loop over spectral fitting for source list
        for id in ${speclist[*]}; do
            cd ${id}

            if [[ ( $(ls *.pi | wc -l) -eq 2 ) && ( $(ls *.arf | wc -l) -eq 2 ) && ( $(ls *.rmf | wc -l) -eq 2 ) ]]; then
                echo -e "group min 1\nexit" | grppha ${id}.pi \!${id}_bin1.pi
            
                # Calling the Script
                xfit_flux
                xfit_absflux

                # Save result together
                echo ${enrange[0]} ${enrange[1]} ${obsdir} $(cat ${id}_${enrange[0]}_${enrange[1]}_pow.result) >> $rootdir/Result_flux
                echo ${enrange[0]} ${enrange[1]} ${obsdir} $(cat ${id}_${enrange[0]}_${enrange[1]}_phabs_pow.result) >> $rootdir/Result_absflux
            else
                echo "For $obsdir/$id, not enough spectrum files (pi/arf/rmf)"
                echo "${enrange[0]} ${enrange[1]} ${obsdir} ${id}" >> $rootdir/NotEnoughSpec
            fi

            cd ..
        done
    done
fi
#==================================================================================

echo ">>> Check 'Result_flux & Result_absflux & NotEnoughSpec'!!!"

# Go back to rootdir/ directory
cd $rootdir
