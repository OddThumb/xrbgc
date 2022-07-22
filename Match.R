# Input arguments directory ----
args = commandArgs(trailingOnly=TRUE)
angular.threshold <- as.numeric(args[1])
condaenvname <- as.character(args[2])
coordspath   <- as.character(args[3])
srcfitspath  <- "merged_half/wavdet_fov/source_list.fits"
subdirectory <- "matched_output"
if (length(args) < 3) {
  stop("(Error) All argument must be supplied
        e.g.) $ rMatch (angular_threshold (arcsec)) (conda_env_name) (path/to/coordinates)
        e.g.) $ rMatch 0.5 py3 path/to/coord", call.=FALSE)
}


# Load libraries ----
package.list <- list("FITSio","tidyverse","reticulate","celestial")
installed <- unlist(lapply(package.list, require, character.only=TRUE))
if (!all(installed)) {
  lapply(package.list[!installed], install.packages, repos="https://cran.seoul.go.kr/", quite=TRUE)
}
lapply(package.list, require, character.only=TRUE)
use_condaenv(condaenv = condaenvname, required = T)
fits <- import("astropy.io.fits", convert = F)


# Create ouput directory ----
dir.create(subdirectory)


# Load catalogue data ----
cat_coords <- read.csv(coordspath)
if (grepl(":",as.character(cat_coords$ra[1]))) {
  cat_coords$ra  <- as.character(cat_coords$ra)  %>% hms2deg()
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
message('>>> Angular distance < ', angular.threshold, '" will be matched...', sep='')
src_list.match_ind <- which(wav_coords2$Ang.D < angular.threshold)
wav_coords3 <- wav_coords2[src_list.match_ind,]


if ( length(src_list.match_ind)==0 ) {
     stop("(Error) There is no matched source within", angular_threshold, "arcsecond threshold")
}


# Source types of matched sources ----
srctype <- bind_cols(RA=wav_coords3$ra, DEC=wav_coords3$dec, source_type=cat_coords[wav_coords3$index, 'source_type'])
write.csv(srctype, paste(subdirectory,"/matched_sourcetypes_",angular.threshold,".csv",sep=''), quote = F, row.names = F)


# Write new source fits file ----
cToolsDir <- system("echo $cTools", intern=T)
source_python(paste(cToolsDir,"/rewriteFITS.py",sep=''))
re_writeFITs(srcfitspath, src_list.match_ind, subdirectory, angular.threshold)
cat('>>> Matched source list fits file is saved in ', subdirectory,"/\n", sep='')
