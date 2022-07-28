# Input arguments directory ----
if (!suppressMessages(suppressWarnings(require('argparse', character.only=TRUE, quietly=TRUE)))) {
  install.packages('argparse')
}
suppressMessages(suppressWarnings(require(argparse, quietly=TRUE)))
parser <- ArgumentParser()
parser$add_argument("-t", "--thresh", type="double", default=0.5,
                    help="Angular threshold to match sources with given labeled coordinates [default %(default)s]")
parser$add_argument("-c", "--coords", type="character", 
                    help = "Path of labeled coordinates csv file")
parser$add_argument("-w", "--wavsrc", type="character", default="merged_half/wavdet/source_list.fits",
                    help = "Path of source_list.fits from wavdetect [default %(default)s]")
args <- parser$parse_args()
angular.threshold <- args$thresh
coordspath        <- args$coords
srcfitspath       <- args$wavsrc
subdirectory <- "matched_output"

#args = commandArgs(trailingOnly=TRUE)
#angular.threshold <- as.numeric(args[1])
#coordspath   <- as.character(args[2])
#srcfitspath  <- "merged_half/wavdet_fov/source_list.fits"
#subdirectory <- "matched_output"
#if (length(args) < 2) {
#  stop("(Error) All argument must be supplied
#        e.g.) $ rMatch (angular_threshold (arcsec)) (path/to/coordinates)
#        e.g.) $ rMatch 0.5 path/to/coord", call.=FALSE)
#}


# Load libraries ----
package.list <- list("FITSio","tidyverse",'dplyr', "reticulate","celestial")
installed <- unlist(lapply(package.list, function(pkg) invisible(suppressMessages(suppressWarnings(require(pkg, character.only=TRUE, quietly=TRUE))))))
if (!all(installed)) {
  lapply(package.list[!installed], install.packages, repos="https://cran.seoul.go.kr/", dependencies=T, quite=TRUE)
}
options(tidyverse.quiet = TRUE)
invisible(sapply(package.list, function(pkg) suppressMessages(suppressWarnings(require(pkg, character.only=TRUE, quietly=TRUE)))))


# Load conda envrionment ----
condaenv <- system('source ${xrbgc}/bashs/FindConda.sh', intern=T)
if ( condaenv == 'ERROR1' ) {
    stop('ERROR) conda not found')
} else if ( condaenv == 'ERROR2' ) {
    stop('ERROR) astropy not found in any conda environment')
} else {
    use_condaenv(condaenv = condaenv, required = T)
    fits <- import("astropy.io.fits", convert = F)
}


# Create ouput directory ----
dir.create(subdirectory)


# Load catalogue data ----
cat_coords <- read.csv(coordspath)
if (grepl(":",as.character(cat_coords$ra[1]))) {
    cat_coords$ra  <- as.character(cat_coords$ra)  %>% hms2deg()
}
if (grepl(":",as.character(cat_coords$dec[1]))) {
    cat_coords$dec <- as.character(cat_coords$dec) %>% dms2deg()
}

# source list fits file from wavdetect (CIAO) ----
src_list <- readFITS(srcfitspath)
ra.colnum  <- which(src_list$colNames == "RA")
dec.colnum <- which(src_list$colNames == "DEC")
wav_coords <- bind_cols('ra'=src_list$col[[ra.colnum]],
                        'dec'=src_list$col[[dec.colnum]])


# Angular distance function ----
Angdist <- function(a, b) {
  a_ra  <- as.numeric(a['ra'])*(pi/180)
  a_dec <- as.numeric(a['dec'])*(pi/180)
  b_ra  <- as.numeric(b['ra'])*(pi/180)
  b_dec <- as.numeric(b['dec'])*(pi/180)

  theta <- acos( sin(a_dec)*sin(b_dec) + cos(a_dec)*cos(b_dec)*cos(a_ra - b_ra) )
  names(theta) <- NULL
  return(as.numeric(theta))
}


# Matching coordinates ----
index <- apply( wav_coords, 1, function(x) apply( cat_coords, 1, function(y) Angdist(x, y) ) %>% which.min() )
Ang.D <- apply( wav_coords, 1, function(x) apply( cat_coords, 1, function(y) Angdist(x, y) ) %>% min() ) * (180/pi) * 3600
wav_coords2 <- cbind(wav_coords, index, Ang.D)


# Filter sources in FITS file with angular threshold ----
message('>>> Angular distances < ', angular.threshold, '" are matched...', sep='')
src_list.match_ind <- which(wav_coords2$Ang.D < angular.threshold)
wav_coords3 <- wav_coords2[src_list.match_ind,]


if ( length(src_list.match_ind)==0 ) {
     stop("(Error) There is no matched source within ", angular.threshold, " arcsecond threshold")
}


# Source types of matched sources ----
srctype <- bind_cols(RA=wav_coords3$ra, DEC=wav_coords3$dec, source_type=cat_coords[wav_coords3$index, 'source_type'])
write.csv(srctype, paste(subdirectory,"/matched_sourcetypes_",angular.threshold,".csv",sep=''), quote = F, row.names = F)


# Write new source fits file ----
XRBGC_Dir <- system("echo $xrbgc", intern=T)
source_python(paste(XRBGC_Dir,"/pythons/rewriteFITS.py",sep=''))
re_writeFITs(srcfitspath, src_list.match_ind, subdirectory, angular.threshold)
cat('>>> Matched source list fits file is saved in ', subdirectory,"/\n", sep='')
