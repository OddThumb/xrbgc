# Input arguments directory ----
args = commandArgs(trailingOnly=TRUE)
GCname <- as.character(args[1])
label_column <- as.character(args[2])
if ( is.na(GCname) ) {
  stop('(Error) At least one argument must be supplied
        e.g.) $ rMakeData "GC name" "source_type (default)"', call.=FALSE)
}
if ( is.na(label_column) ) {
  label_column <- "source_type"
}

# Check fluxes/ directory ----
fluxdirectory <- 'fluxes'
if (!file.exists(fluxdirectory)) {
  stop("(Error) fluxes/ directory does not exist")
}

# Check matched_output/ directory ----
matched.file <- Sys.glob("matched_output/matched_sourcetypes_*.csv")
if ( length(matched.file) == 0 ) {
  stop("(Error) matched_output/matched_sourcetypes_*.csv file does not exist")
}


# Load libraries ----
package.list <- list("FITSio", "tidyverse", "rlist", "celestial")
installed <- lapply(package.list, require, character.only=TRUE)
if (!all(installed)) {
  lapply(package.list[!installed], install.packages, repos="https://cran.seoul.go.kr/")
}
lapply(package.list, function(x) library(x, character.only=TRUE))

# ========================================= Function bin =========================================
# Angular distance function
Angdist <- function(a, b) {
  a_ra  <- as.numeric(a['ra'])*(pi/180)
  a_dec <- as.numeric(a['dec'])*(pi/180)
  b_ra  <- as.numeric(b['ra'])*(pi/180)
  b_dec <- as.numeric(b['dec'])*(pi/180)
  
  theta <- acos( sin(a_dec)*sin(b_dec) + cos(a_dec)*cos(b_dec)*cos(a_ra - b_ra) )
  names(theta) <- NULL
  return(as.numeric(theta))
}

# Arrange flux data from srcflux result
ArrangeFluxData <- function(file) {
  # Read energy band
  band <- strsplit(file, "\\_|.flux")[[1]][grepl("-", strsplit(file, "\\_|.flux")[[1]])]
  
  # Read fits flie
  fits <- readFITS( paste(fluxdirectory, file, sep='/') )
  names(fits$col) <- fits$colNames
  table <- list.cbind(fits$col) %>% as.data.frame() %>% distinct(COMPONENT, .keep_all=TRUE)
  
  if ( any(grepl("MERGED",colnames(table))) ) {
    fluxcolumns <<- c("MERGED_NET_MFLUX_APER", "MERGED_NET_UMFLUX_APER")
    fluxerrcolumns <<- c("MERGED_NET_MFLUX_APER_LO",  "MERGED_NET_MFLUX_APER_HI", "MERGED_NET_UMFLUX_APER_LO", "MERGED_NET_UMFLUX_APER_HI")
  } else {
    fluxcolumns <<- c("NET_MFLUX_APER", "NET_UMFLUX_APER")
    fluxerrcolumns <<- c("NET_MFLUX_APER_LO",  "NET_MFLUX_APER_HI", "NET_UMFLUX_APER_LO", "NET_UMFLUX_APER_HI")
  }

  # Select columns
  posNflux <- table %>% select(c("RAPOS", "DECPOS", # Coordinates
                                 all_of(fluxcolumns),       # flux
                                 all_of(fluxerrcolumns)))   # flux error
  comment(posNflux) <- band
  
  # Store data into a list with the energy band
  posNflux
}

# Conversion from flux to luminosity
Flux2Lx <- function(data) {
  i <<- i+1
  
  # band info
  band    <- names(flux.list)[i] # Energy band
  message(">>> Band info: No.", i, " : ", band, " keV")
  
  # Split data
  pos     <- data[,c("RAPOS", "DECPOS")] # Coordinate column
  colnames(pos) <- c('ra','dec')
  flux    <- data[,fluxcolumns,drop=FALSE]    # Flux column
  fluxerr <- data[,fluxerrcolumns,drop=FALSE] # Flux error column
  flux    <- do.call(cbind, flux %>% lapply(function(x) as.numeric(as.character(x)))) %>% as.data.frame()
  fluxerr <- do.call(cbind, fluxerr %>% lapply(function(x) as.numeric(as.character(x)))) %>% as.data.frame()
  
  # Radii to core radii ratio
  RCR <<- data.frame(
    'rcr'=apply(pos, 1, function(x) Angdist(x, c('ra'=RA_cen, 'dec'=DEC_cen))*(180/pi)*60/r_c)
  )
  
  # Luminosity
  onePCinCM <- 3.086e+21
  Lx <- flux*4*pi*(R_sun*onePCinCM)^2
  Lx_err <- fluxerr*4*pi*(R_sun*onePCinCM)^2
  colnames(Lx) <- c(paste('L',i,sep='_'), paste('uL',i,sep='_'))
  colnames(Lx_err) <- c(paste('L',i,'lo',sep='_'), paste('L',i,'hi',sep='_'),
                        paste('uL',i,'lo',sep='_'), paste('uL',i,'hi',sep='_'))
  
  # Binding together
  Lxs <- cbind(Lx, Lx_err)
  Lx_cols <- c(paste('L',i,sep='_'),paste('L',i,'lo',sep='_'), paste('L',i,'hi',sep='_'),paste('uL',i,sep='_'),paste('uL',i,'lo',sep='_'), paste('uL',i,'hi',sep='_'))
  Lxs <- Lxs[,Lx_cols]
  
  return(Lxs)
}

# Remove rows for NaN luminosity in ANY band
Remove_NaN_Lx <- function(Lxs) {
  # Lx column names
  Lx_colnames <- c('L_1','uL_1','L_2','uL_2','L_3','uL_3','L_4','uL_4','L_5','uL_5',
                   'L_6','uL_6','L_7','uL_7','L_8','uL_8')
  
  # Which source will be survived/removed?
  survived <- apply( X=Lxs[,Lx_colnames], MARGIN=1, FUN=function(x) !any(is.na(x)) )
  removed  <- which(!survived)
  
  # Notice which one will be removed
  if ( sum(removed) > 0 ) {
    message(">>> ", paste(removed,collapse=','), "-th source have NaN luminosity value in ANY band, then will be removed", sep='')
  }

  # Sort out survived sources
  Lxs <- Lxs[survived,]
  
  return(list('data'=Lxs, 'survived'=survived))
}

# Replace Lx which has 0-value with min([Lx])/2
Replace_Zero_Lx <- function(Lxs) {
  # Lx column names
  Lx_colnames <- c('L_1','uL_1','L_2','uL_2','L_3','uL_3','L_4','uL_4','L_5','uL_5',
                   'L_6','uL_6','L_7','uL_7','L_8','uL_8')
  
  # Searching for 0-value
  Replace_Zero_col <- function(x, bandname) {
    b <<- b+1
    
    # Zero value index
    zero_idx <- which(x==0)
    
    # Notice
    if ( length(zero_idx) != 0 ) {
      message(">>> In ",bandname[b], ", ", length(zero_idx), " source(s) (idx: ", paste(zero_idx, collapse=','), ") will be replaced with half-mininum value", sep='')
    }
    
    halfmin <- min(x[-zero_idx])/2
    x[zero_idx] <- halfmin
    return(x)
  }
  
  # Apply replacing fucntion column-wise
  b <- 0
  Lxs[,Lx_colnames] <- apply( X=Lxs[,Lx_colnames], MARGIN=2, Replace_Zero_col, bandname=Lx_colnames)
  
  return(Lxs)
}

# Replace Lx_err which has NaN with median
Replace_NaNZero_Err <- function(Lxs) {
  # Lx error column names
  Lx_err_colnames <- c('L_1_lo','L_1_hi','uL_1_lo','uL_1_hi','L_2_lo','L_2_hi','uL_2_lo','uL_2_hi',
                       'L_3_lo','L_3_hi','uL_3_lo','uL_3_hi','L_4_lo','L_4_hi','uL_4_lo','uL_4_hi',
                       'L_5_lo','L_5_hi','uL_5_lo','uL_5_hi','L_6_lo','L_6_hi','uL_6_lo','uL_6_hi',
                       'L_7_lo','L_7_hi','uL_7_lo','uL_7_hi','L_8_lo','L_8_hi','uL_8_lo','uL_8_hi')
  
  # Searching for 0-value
  Replace_NaN_col <- function(x, bandname) {
    b <<- b+1
    
    # NA value index
    NAZERO_idx <- which(is.na(x) | x==0 )
    
    # Notice
    if ( length(NAZERO_idx) != 0 ) {
      message(">>> In ",bandname[b], ", ", length(NAZERO_idx), " source(s) (idx: ", paste(NAZERO_idx, collapse=','), ") will be replaced with median value", sep='')
    }
    
    mederr <- median(x[-NAZERO_idx])
    x[NAZERO_idx] <- mederr
    return(x)
  }
  
  # Apply replacing fucntion column-wise
  b <- 0
  Lxs[,Lx_err_colnames] <- apply( X=Lxs[,Lx_err_colnames], MARGIN=2, Replace_NaN_col, bandname=Lx_err_colnames)
  
  return(Lxs)
}

# Make dataset for ML algorithm
MakeData <- function(flux.list, labels) {
  # Luminosities
  i <<- 0
  Lxs <- bind_cols(lapply(flux.list, Flux2Lx))
  
  # Remove rows for NaN luminosity in ANY band
  cat("\n")
  result   <- Remove_NaN_Lx(Lxs)
  Lxs      <- result$data
  survived <- result$survived
  
  # Replace Lx which has 0-value with min([Lx])/2
  cat("\n")
  Lxs <- Replace_Zero_Lx(Lxs)
  
  # Replace Lx_err which has NaN with median
  cat("\n")
  Lxs <- Replace_NaNZero_Err(Lxs)
  
  # Add color columns
  message("\n>>> Total 6 colors were created:
      > color1 = log10( L_1 / L_3 ),
      > color2 = log10( L_4 / L_5 ),
      > color3 = log10( L_2 / L_8 ),
      * same manner for unabsorbed color (ucolor1; ucolor2; ucolor3)")
  Lxs <- Lxs %>% 
    mutate(color1  = log10( L_1 / L_3 )) %>% 
    mutate(ucolor1 = log10(uL_1 / uL_3)) %>% 
    mutate(color2  = log10( L_4 / L_5 )) %>% 
    mutate(ucolor2 = log10(uL_4 / uL_5)) %>% 
    mutate(color3  = log10( L_2 / L_8 )) %>% 
    mutate(ucolor3 = log10(uL_2 / uL_8))
  
  # log1p_norm for luminosities
  message("\n>>> Log10(x+1) for luminosites")
  LxNLxerr <- grep("L", colnames(Lxs),value = TRUE)
  Lxs[,LxNLxerr] <- apply( X=Lxs[,LxNLxerr], MARGIN=2, FUN=function(x) log10(x+1))
  
  # Combine with RCR
  DataSet <- cbind('source_type'=labels[survived,], 'rcr'=RCR[survived,], Lxs)
  
  return(DataSet)
}

# Alert for missing parameters from Harris Catalog (2010)
missingParam <- function(param) {
  if (is.na(get(param))) {
    stop("(Error) ",param, "is missing in Harris Catalog (2010) for ", GCname, "...")
  } else {
    message(">>> ",param," = ",get(param)," is found",sep='')
  }
}
# ================================================================================================


# Center RA (deg), center Dec (deg), core radii (arcmin), and distance from Sun (kpc) for a given GC name ----
GCCAT_dir <- system("echo $cTools", intern=TRUE)
GCCAT <- read.csv(paste(GCCAT_dir,"/Harrison_CAT.csv",sep=''))
if ( any(str_detect(GCCAT$ID, regex(GCname, ignore_case=TRUE))|str_detect(GCCAT$Name, regex(GCname, ignore_case=TRUE))) ) {
	message("\n>>> ", GCname, " is found in Harris catalog (2010)")
} else {
	stop("(Error) There is no ",GCname," in Harris catalog (2010)")
}
RA_cen <- filter(GCCAT, str_detect(ID, regex(GCname, ignore_case=TRUE))|str_detect(Name, regex(GCname, ignore_case=TRUE)))[,"RA"] %>% as.character() %>% hms2deg()
DEC_cen <- filter(GCCAT, str_detect(ID, regex(GCname, ignore_case=TRUE))|str_detect(Name, regex(GCname, ignore_case=TRUE)))[,"DEC"] %>% as.character() %>% dms2deg()
r_c <- filter(GCCAT, str_detect(ID, regex(GCname, ignore_case=TRUE))|str_detect(Name, regex(GCname, ignore_case=TRUE)))[,"r_c"] %>% as.character() %>% as.numeric()
R_sun <- filter(GCCAT, str_detect(ID, regex(GCname, ignore_case=TRUE))|str_detect(Name, regex(GCname, ignore_case=TRUE)))[,"R_Sun"] %>% as.character() %>% as.numeric()


# Parameter checking ----
parameter_from_Harris <- c("RA_cen","DEC_cen","r_c","R_sun")
for (param in parameter_from_Harris) {
  missingParam(param)
}


# Load label information ----
labels <- read.csv(matched.file)[,label_column, drop=FALSE]


# Load data and arrange them ----
flux.files <- grep(list.files(path = fluxdirectory), pattern="out_obi*", invert=TRUE, value=TRUE) # Load merged flux data only
message('\n>>> Arranging flux data')
flux.list <- lapply(flux.files, ArrangeFluxData)
names(flux.list) <- lapply(flux.list, comment) %>% unlist()


# Making dataset ----
DataSet <- MakeData(flux.list, labels)
write.csv(DataSet, file = paste('DataSet_',gsub(" ","",GCname),'.csv',sep=''), row.names = F)


# Save band number corresponding to energy band ----
bandinfo <- data.frame('no'=sprintf("%02d",seq(length(flux.list))),
                       'band'=names(flux.list))
write.table(bandinfo, file = 'BandInfo.tsv', sep = '\t', quote = F, row.names = F)


# DONE ----
message("\n>>> Files: ", paste('DataSet_',gsub(" ","",GCname),'.csv',sep=''), ", BandInfo.tsv are saved in: \n     ",
    getwd(), "\n", sep='')
message("\n *** IMPORTANT: Do NOT change Dataset file name as input data for classification!")
