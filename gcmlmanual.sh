echo '
For GCML project,
 (0) Download data
 (1) Repro
 (2) MergeWav
 (or) If multi observation sources are not matched properly,
     FluxImg
     WCScorr [-h] -f fluxed(defualt)
                  -r 10059
 (3) Please MANUALLY prepare a csv file including columns at least these: "ra,dec,source_type"
 (4) Match [-h] -c "info/47Tuc_class.csv"\
                -t 0.5(default)\
                -w "merged_half/wavdet/source_list.fits"(default)
 (5) Srcflux [-h] -n "GC Name"\
                  -p 0(default)
 (6) Make [-h] -n "47 Tuc"\
               -f "fluxes_xspowerlaw.p1/"(default)\
               -v T(default)
'
