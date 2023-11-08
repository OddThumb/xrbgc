# ![xrbgc_logo](xrbgc_logo.png) powered by CIAO

`xrbgc` is an open source wrapper scripts for Chandra Interactive Analysis of Observations (CIAO) [[1](#References)] users who want to get X-ray fluxes and colors of objects, easily. `xrbgc` includes wrapper bash scripts composed of CIAO commands and `R` scripts for processing data.



## Documentation
In this script, all-parts-combined [CATALOG OF PARAMETERS FOR MILKY WAY GLOBULAR CLUSTERS](https://physics.mcmaster.ca/~harris/mwgc.dat) [[3](#References)] database is included as one csv file for incorperating half-light radius, core radius, and foreground reddening of each globular cluster.



## Installation

```bash
# UNZIP
unzip xrbgc-main.zip

# RENAME
mv xrbgc-main xrbgc

# MOVE
mv xrbgc /path_you_want_to_install
cd /path_you_want_to_install/xrbgc

# INSTALL
source install_xrbgc.sh
```



## Requirements

> `ciao` >= 4.15: Chandra Interactive Analysis of Observations ([https://cxc.cfa.harvard.edu/ciao/](https://cxc.cfa.harvard.edu/ciao/))
>
> `R`: The R Project for Statistical Computing ([https://r-project.org](https://r-project.org))
>
> `python` & `astropy`: for only 'fits' in astropy.io

*Note 1: This tool contains "calculating merged flux", "glvary", and "user_script" in `srcflux`*

*Note 2: All libraries for R scripts will be downloaded automatically in each script.*



## Usages

```bash
$ xginit -i true
 ┌──────────────────────────────┐
 │                              │
 │        xrbgc (v1.0.0)        │
 │                              │
 │    > Author: Sang In Kim     │
 │    > Date: 08 Nov 2023       │
 │                              │
 │   Wrapper scripts for CIAO   │
 │                              │
 │   CIAO  version: 4.15.1      │
 │   ciao_contrib : 4.15.1      │
 │   CALDB version: 4.10.2      │
 │                              │
 │  Ref: Fruscione et al.(2006) │
 └──────────────────────────────┘

[ PROCEDURE EXAMPLE ]
├(0) Download data (You can use: $ download_chandra_obsid {obsid})
│    > download_chandra_obsid 78,953,954,955,966
│
├(1) Reprocessing all ObsIDs in current directory
│    > Reprocessing
│    > y
│
├(2) Merge observations and Do 'wavdetect'
│    > MergeWav [-h] -n "47 Tuc" -r "r_h"
│
├┤(3-A) (optional) If sources need to be filtered by 'significance',
│├─┤Filtered source_list will have less number of sources.
││   > FilterSigma [-h] --input "merged/wavdet/source_list.fits" \
││                      --sigma 3 (default) \
││                      --output "source_list_sigma3.0.fits"
││
││   > Match [-h] -c "info/47Tuc_class.csv" \
││                -t 0.5 \
││                -w "source_list_simga3.0.fits" \
││                -a TRUE   (including all unknowns)
│└─
├┤(3-B) (optional) If source type labels are provided, (optional)
│├┤(3-B-a) Please MANUALLY prepare a csv file including columns of,
││         at least: "ra, dec, source_type"
││   e.g.)
││   > /bin/cat 47Tuc_class.csv
││                      name,       ra,        dec, source_type
││   CXOGlb J002407.9-720502, 6.033158, -72.083883,         AGB
││   CXOGlb J002408.5-720535, 6.0356,   -72.093106,         AGB
││   CXOGlb J002411.0-720444, 6.046079, -72.078897,         AGB
││   CXOGlb J002407.1-720452, 6.029879, -72.081322,         AGB
││   CXOGlb J002350.3-720431, 5.959879, -72.0754,           MSP
│└─
│
│├┤(3-B-b)
││   > Match [-h] -c "info/47Tuc_class.csv" \
││                -t 0.5 \
││                -w "source_list.fits" \
││                -a TRUE   (including all unknowns)
││
││   > GetSigma [-h] -w matched_output/source_matched_0.5_allout.fits \
││                   -o matched_output/Signif.csv
│└─
├(5) Run srcflux with "user plugin (default)"
│  > Srcflux [-h] -n "47 Tuc" \
│                 -s "matched_output/source_matched_0.5_allout.fits" \
│                 -b "info/bkg.reg" \
│
├(6) Compile .flux, labels, signifs
│  > CompileFlux [-h] -n "47 Tuc" \
│                     -f "fluxes_xspowerlaw.p1/" \
│                     -m "matched_output/match_and_all_0.5.csv" \
│                     -s "Signif.csv
└>>> Final output: "DataSet_47Tuc.csv"

```





### References
[1] [Fruscione et al. 2006, SPIE Proc. 6270, 62701V, D.R. Silvia & R.E. Doxsey, eds.](https://doi.org/10.1117/12.671760)

[2] [Harris, W.E. 1996, AJ, 112, 1487](http://adsabs.harvard.edu/full/1996AJ....112.1487H)




