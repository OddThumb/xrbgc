# ![xrbgc_logo](xrbgc_logo.png) powered by CIAO

xrbgc is an open source wrapper scripts for Chandra Interactive Analysis of Observations (CIAO) [[1](#References)] users who want to get X-ray fluxes and colors of objects, easily. xrbgc includes wrapper bash scripts composed of CIAO commands and R scripts for processing data.



## Documentation

By using xrbgc, we have accomplished a work for classifying X-ray sources in different globular clusters [[2](#References)] which requires a lot of recursive data processing with CIAO.

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

> **CIAO** >= 4.14: Chandra Interactive Analysis of Observations (https://cxc.cfa.harvard.edu/ciao/)
>
> **R**: The R Project for Statistical Computing (https://r-project.org)
>
> **astropy**: for only 'fits' in astropy.io

*Note1: For using 'calculating merged flux' feature from srcflux command in CIAO, you need to install CIAO version >= 4.13.*

*Note2: For using 'glvary' feature from srcflux command in CIAO, you need to install CIAO version >= 4.14.*

*Note3: All libraries for R scripts will be downloaded automatically in each script.*



## Usage

```bash
$ xginit
#   
#    =============================
# 
#         xrbgc (beta 0.6.9)
# 
#      > Author: Sang In Kim
#      > Date: 17 July 2022
# 
#    "Wrapper scripts for CIAO"
# 
#    CIAO  version: 4.14
#    ciao_contrib : 4.14.2
#    CALDB version: 4.9.8
# 
#    Ref: Fruscione et al.(2006)
#  ===============================
# 
# 
# For GCML project,
#  (0) Download data
#  (1) Repro
#  (2) MergeWav
#  (or) If multi observation sources are not matched properly,
#      ReprojWav [-h] -r 10059
#  (3) Please MANUALLY prepare a csv file including columns at least these: "ra,dec,source_type"
#  (4) Match [-h] -c "info/47Tuc_class.csv"\
#                 -t 0.5(default)\
#                 -w "merged_half/wavdet/source_list.fits"(default)
#  (5) Srcflux [-h] -n "GC Name"\
#                   -p 0(default)
#  (6) Make [-h] -n "47 Tuc"\
#                -f "fluxes_xspowerlaw.p1/"(default)\
#                -v T(default)

$ gcmlmanual

# For GCML project,
#  (0) Download data
#  (1) Repro
#  (2) MergeWav
#  (or) If multi observation sources are not matched properly,
#      ReprojWav [-h] -r 10059
#  (3) Please MANUALLY prepare a csv file including columns at least these: "ra,dec,source_type"
#  (4) Match [-h] -c "info/47Tuc_class.csv"\
#                 -t 0.5(default)\
#                 -w "merged_half/wavdet/source_list.fits"(default)
#  (5) Srcflux [-h] -n "GC Name"\
#                   -p 0(default)
#  (6) Make [-h] -n "47 Tuc"\
#                -f "fluxes_xspowerlaw.p1/"(default)\
#                -v T(default)
```





### References
[1] [Fruscione et al. 2006, SPIE Proc. 6270, 62701V, D.R. Silvia & R.E. Doxsey, eds.](https://doi.org/10.1117/12.671760)

[2] [K. Oh, S. I. Kim, C. Y. Hui, Shengda Luo, and Alex P. Leung, 2021, Classifying X-ray Sources in Globular Clusters with Ensemble Learning, MNRAS, ...]()

[3] [Harris, W.E. 1996, AJ, 112, 1487](http://adsabs.harvard.edu/full/1996AJ....112.1487H)





### Citing xrbgc

