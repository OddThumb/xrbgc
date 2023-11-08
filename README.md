# ![xrbgc_logo](xrbgc_logo.png) powered by CIAO

`xrbgc` is an open source wrapper scripts for Chandra Interactive Analysis of Observations (CIAO) [[1](#References)] users who want to get X-ray luminosities of objects, easily. `xrbgc` includes wrapper bash scripts composed of CIAO commands and `R` scripts for processing data.
The author have used this tool for analyzing the globular cluster (GC) data observed by Chandra.


## Documentation
In this script, all-parts-combined [CATALOG OF PARAMETERS FOR MILKY WAY GLOBULAR CLUSTERS](https://physics.mcmaster.ca/~harris/mwgc.dat) [[2](#References)] (If I missed any copyrights, please let me know) database is included as one csv file for incorperating following values:

- **the half-light radius (`r_h`)**
- **the core radius (`r_c`)**
- **the distance from solar system (`R_sun`)**
- and **the color excess (`EBV`)**

of each globular cluster.



## Installation

```bash
# UNZIP
unzip xrbgc-main.zip

# RENAME
mv xrbgc-main xrbgc

# CHANGE DIRECTORY
mv xrbgc /path_you_want_to_install
cd /path_you_want_to_install/xrbgc

# INSTALL
bash install_xrbgc.sh
```



## Requirements

> `ciao` >= 4.15: Chandra Interactive Analysis of Observations ([https://cxc.cfa.harvard.edu/ciao/](https://cxc.cfa.harvard.edu/ciao/))
>
> `R`: The R Project for Statistical Computing ([https://r-project.org](https://r-project.org))
>
> `python` & `astropy`: for only 'fits' in astropy.io



## Features

1. `Reprocessing` (in `bash`)
	* Automated `chandra_repro` process over existing all ObsIDs in current directory.

2. `MergeWav` = `merge_obs` + `wavdetect` (in `ciao`)
	* Sub-arcsecond merging.
	* Narrow-down `wavdetect` region with a circular region with the radius of `r_h` or `r_c` (from [[2](#References)])

3. `Match` (in `R`)
	* Source matching and asigning class name with angular distance threshold (`-t`; 0.5" is default) and with given csv file which includes "ra,dec,class".

4. `GetSigma` or `FilterSigma` (in `R`)
	* `SRC_SIGNIFICANCE` column from `source_list.fits` (from `wavdetect`) can be extraced by `GetSigma`,
	* or `source_list.fits` can be filtered by `FilterSigma` with given `--sigma` threshold.

5. `srcflux` (in `ciao`)
	* Compute the **luminosity** with `R_sun` ([[2](#References)]) from **merged events**.
	* `min`, `max`, and `median` value of the probability of variability from `glvary`.
	* As a default, run `user_script`: Following parameters will be frozen while `user_script` spectral fitting (by `Sherpa`):
		* `xsphabs.abs1.nH`
		* `xspowerlaw.p1.PhoIndex` or `xsbbodyrad.b1.kT` or `xsapec.a1.kT`


*Note: All libraries for `R` scripts will be detected and downloaded automatically in each script.*



## Usages

```bash
$ xginit -i true -e true
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
├─(0) Download data (You can use: $ download_chandra_obsid {obsid})
│    > download_chandra_obsid 78,953,954,955,966
│
├─(1) Reprocessing all ObsIDs in current directory
│    > Reprocessing
│    > y
│
├─(2) Merge observations and Do 'wavdetect'
│    > MergeWav [-h] -n "47 Tuc" -r "r_h"
│
├┬(3) if source type labels are provided, (optional)
││    Please MANUALLY prepare a csv file including columns of, at least: "ra, dec, source_type"
││    e.g.)
││    > /bin/cat 47Tuc_class.csv
││           ra,        dec, source_type
││     6.033158, -72.083883,         AGB
││     6.0356,   -72.093106,         AGB
││     6.046079, -72.078897,         AGB
││     6.029879, -72.081322,         AGB
││     5.959879, -72.0754,           MSP
││
│(Choose route A or B)
││
│├┬─(3-A) if sources need to be filtered by 'significance',
│││       (Filtered source_list_sigma3.0.fits will have less number of sources)
│││   > FilterSigma [-h] --input merged/wavdet/source_list.fits \
│││                      --sigma 3 (default) \
│││                      --output source_list_sigma3.0.fits (default)
│││
│││   > Match [-h] -c info/47Tuc_class.csv \
│││                -t 0.5 (default) \
│││                -w merged/wavdet/source_list_simga3.0.fits \
│││                -a TRUE   (including all unknowns)
││└────────────────────────────────────────────────────────────────────────────
││
│└┬─(3-B) else if you want to filter significance later,
│ │   > Match [-h] -c info/47Tuc_class.csv \
│ │                -t 0.5 \
│ │                -w merged/wavdet/source_list.fits \
│ │                -a TRUE   (including all unknowns)
│ │ 
│ │   > GetSigma [-h] -w matched_output/source_matched_0.5_allout.fits \
│ │                   -o matched_output/Signif.csv
│ │ 
│ └────────────────────────────────────────────────────────────────────────────
│
├─(4) Run srcflux with "user plugin (default)"
│     Default model is "xspowerlaw.p1" with "p1.PhoIndex=1.7" and "p1.norm=1e-5"
│  > Srcflux [-h] -n "47 Tuc" \
│                 -s matched_output/source_matched_0.5_allout.fits \
│                 -b bkg.reg
│                    │ You need to make a background region file by your self.
│                    │ Because GC envrionment is very crowded, you can't rely
│                    │ on the 'roi' command.
│                    │ One "bkg.reg" will be used for all sources.
│                    └──────────────────────────────────────────────────────────
│
├─(5) Compile .flux, labels, signifs
│  > mv 231108_1553 (the output directory will be named with datetime)
│  > CompileFlux [-h] -n "47 Tuc" \
│                     -f fluxes_xspowerlaw.p1/ \
│                     -m ../matched_output/match_and_all_0.5.csv \
│                     -s ../matched_output/Signif.csv (only if you chose 3-B)
│
└─>>> Final output: "DataSet_47Tuc.csv"

For details of each step, type a flag of "-h".
If you want to read "[ PROCEDURE EXAMPLE ]" again in the future, type:
 $ xgmanual
```





### References
[1] [Fruscione et al. 2006, SPIE Proc. 6270, 62701V, D.R. Silvia & R.E. Doxsey, eds.](https://doi.org/10.1117/12.671760)

[2] [Harris, W.E. 1996, AJ, 112, 1487](http://adsabs.harvard.edu/full/1996AJ....112.1487H)




