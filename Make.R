# Input arguments directory ----
if (!suppressMessages(suppressWarnings(require('argparse', character.only=TRUE, quietly=TRUE)))) {
  install.packages('argparse')
}
suppressMessages(suppressWarnings(require(argparse, quietly=TRUE)))
parser <- ArgumentParser()
parser$add_argument("-n", "--name", type="character",
                    help="The name of globular cluster with white space (e.g., '47 Tuc')")
parser$add_argument("-f", "--fluxdir", type="character", default="fluxes_xspowerlaw.p1/", 
                    help = "A directory name that contains '.flux' files to construct data [default %(default)s]")
parser$add_argument("-v","--vary", default=TRUE, type="logical",
                    help="Whether 'glvary' run or not [default %(default)s]")
args <- parser$parse_args()
GCname  <- args$name
fluxdir <- args$fluxdir
vary    <- args$vary
label_column <- "source_type"

#args = commandArgs(trailingOnly=TRUE)
#GCname <- as.character(args[1])
#fluxdir <- as.character(args[2])
#label_column <- as.character(args[3])
#if ( is.na(label_column) ) {
#  label_column <- "source_type"
#}
#if ( is.na(GCname) ) {
#  stop('(Error) At least one argument must be supplied
#        e.g.) $ rMakeData "GC name" "path/to/flux/directory" "source_type (default)"', call.=FALSE)
#}

if (!file.exists(fluxdir)) {
  stop("(Error) fluxes/ directory does not exist")
}


# Check matched_output/ directory ----
matched.file <- Sys.glob("matched_output/matched_sourcetypes_*.csv")
if ( length(matched.file) == 0 ) {
  stop("(Error) matched_output/matched_sourcetypes_*.csv file does not exist")
}


# Load libraries ----
options(tidyverse.quiet = TRUE)
package.list <- list("FITSio", "tidyverse", "reshape2", "rlist", "celestial")
installed <- unlist(lapply(package.list, function(pkg) invisible(suppressMessages(suppressWarnings(require(pkg, character.only=TRUE, quietly=TRUE))))))
if (!all(installed)) {
  lapply(package.list[!installed], install.packages, repos="https://cran.seoul.go.kr/")
}
invisible(sapply(package.list, function(pkg) suppressMessages(suppressWarnings(require(pkg, character.only=TRUE, quietly=TRUE)))))


# ========================================= Function bin =========================================
# Angular distance computing function
Angdist <- function(a, b) {
  a_ra  <- as.numeric(a['ra'])*(pi/180)
  a_dec <- as.numeric(a['dec'])*(pi/180)
  b_ra  <- as.numeric(b['ra'])*(pi/180)
  b_dec <- as.numeric(b['dec'])*(pi/180)

  theta <- acos( sin(a_dec)*sin(b_dec) + cos(a_dec)*cos(b_dec)*cos(a_ra - b_ra) )
  names(theta) <- NULL
  return(as.numeric(theta))
}


# Radii to core radii ratio
rcr <- function(pos, r_c) {
    # r_c in arcmin
    Angdist(a=pos, b=c('ra'=RA_cen, 'dec'=DEC_cen))* ( 180 / pi ) * 60  / r_c   # in degree
           # * ( 180 / pi ) * 60                           # in arcmin
           # / r_c )                                  # in ratio = arcmin/arcmin
}

# Radii to half-light radii ratio
rhr <- function(pos, r_h) {
    # r_h in arcmin
    Angdist(a=pos, b=c('ra'=RA_cen, 'dec'=DEC_cen)) * ( 180 / pi ) * 60 / r_h # in degree
            #* ( 180 / pi ) * 60                           # in arcmin
            #/ r_h                                   # in ratio = arcmin/arcmin
}


# Physical distance in the unit of pc
Phydist <- function(pos, R) {
    onePCinAU <- 648000/pi
    # R_sun in unit of kpc
    Angdist(a=pos, b=c('ra'=RA_cen, 'dec'=DEC_cen)  # in degree
            * ( 180 / pi ) * 60 * 60                    # in arcsec
            * ( 1e3 * R_sun )                           # in AU
            / onePCinAU )                            # in pc
}


# Arrange flux data from srcflux result
ArrangeFluxData <- function(file) {
  # Read energy band
  band <- strsplit(file, "\\_|.flux")[[1]][grepl("-", strsplit(file, "\\_|.flux")[[1]])]

  # Read fits file
  fits <- readFITS( paste(fluxdir, file, sep='/') )
  names(fits$col) <- fits$colNames
  table <- list.cbind(fits$col) %>% as.data.frame() %>% distinct(COMPONENT, .keep_all=TRUE)

  if ( any(grepl("MERGED",colnames(table))) ) {
    fluxcolumns <<- "MERGED_NET_UMFLUX_APER" #c("MERGED_NET_MFLUX_APER", "MERGED_NET_UMFLUX_APER")
    fluxerrcolumns <<- c("MERGED_NET_UMFLUX_APER_LO", "MERGED_NET_UMFLUX_APER_HI") #c("MERGED_NET_MFLUX_APER_LO",  "MERGED_NET_MFLUX_APER_HI", "MERGED_NET_UMFLUX_APER_LO", "MERGED_NET_UMFLUX_APER_HI")
  } else {
    fluxcolumns <<- "NET_UMFLUX_APER" #c("NET_MFLUX_APER", "NET_UMFLUX_APER")
    fluxerrcolumns <<- c("NET_UMFLUX_APER_LO", "NET_UMFLUX_APER_HI") #c("NET_MFLUX_APER_LO",  "NET_MFLUX_APER_HI", "NET_UMFLUX_APER_LO", "NET_UMFLUX_APER_HI")
  }

  # Select columns
  position_flux <- table %>% select(c("RAPOS", "DECPOS", # Coordinates
                                 all_of(fluxcolumns),       # flux
                                 all_of(fluxerrcolumns)))   # flux error
  comment(position_flux) <- band

  # Store data into a list with the energy band
  position_flux
}


# Conversion from flux to luminosity
Flux2Lx <- function(data, flux.list, fluxcolumns, fluxerrcolumns, r_c, r_h, R_sun) {
  i <<- i+1

  # band info
  band    <- names(flux.list)[i] # Energy band order 
  message("|> No.", i, " : ", band, " keV")

  # Split data
  pos     <- data[,c("RAPOS", "DECPOS")] # Coordinate column
  colnames(pos) <- c('ra','dec')
  flux    <- data[,fluxcolumns,    drop = FALSE]    # Flux column
  fluxerr <- data[,fluxerrcolumns, drop = FALSE] # Flux error column
  flux    <- do.call( cbind, flux    %>% lapply( function(x) as.numeric(as.character(x)) ) ) %>% as.data.frame()
  fluxerr <- do.call( cbind, fluxerr %>% lapply( function(x) as.numeric(as.character(x)) ) ) %>% as.data.frame()

  # Radii to core radii ratio
  ANG     <<- data.frame( 'AngDist' = apply(pos, 1, function(pos, cen) Angdist(a=pos,b=cen)*(180/pi)*3600, cen=c('ra'=RA_cen, 'dec'=DEC_cen)))
  RCR     <<- data.frame( 'rcr'     = apply(pos, 1, rcr,     r_c=r_c))
  RHR     <<- data.frame( 'rhr'     = apply(pos, 1, rhr,     r_h=r_h))
  PhyDist <<- data.frame( 'PhyDist' = apply(pos, 1, Phydist, R=R_sun))

  # Luminosity
  onePCinCM <- 3.086e+18
  Lx     <- flux    * 4*pi * ( 1e3*R_sun * onePCinCM )^2 # R_sun in kpc
  Lx_err <- fluxerr * 4*pi * ( 1e3*R_sun * onePCinCM )^2 # R_sun in kpc
  colnames(Lx)     <-   paste('L', i, sep = '_') #c(paste('L',i,sep='_'), paste('uL',i,sep='_'))
  colnames(Lx_err) <- c(paste('L', i, 'lo', sep = '_'),
                        paste('L', i, 'hi', sep = '_')) #c(paste('L',i,'lo',sep='_'), paste('L',i,'hi',sep='_'), paste('uL',i,'lo',sep='_'), paste('uL',i,'hi',sep='_'))

  # Binding together
  Lxs <- cbind(Lx, Lx_err)
  Lx_cols <- c(paste('L', i, sep = '_'),
               paste('L', i, 'lo', sep = '_'),
               paste('L', i, 'hi', sep = '_')) #c(paste('L',i,sep='_'),paste('L',i,'lo',sep='_'), paste('L',i,'hi',sep='_'),paste('uL',i,sep='_'),paste('uL',i,'lo',sep='_'), paste('uL',i,'hi',sep='_'))
  Lxs <- Lxs[,Lx_cols]

  return(Lxs)
}


## Remove rows for NaN luminosity in ANY band
#Remove_NaN_Lx <- function(Lxs) {
#  # Lx column names
#  Lx_colnames <- c('L_1', 'L_2', 'L_3', 'L_4', 'L_5', 'L_6', 'L_7', 'L_8')
#  #c('L_1','uL_1','L_2','uL_2','L_3','uL_3','L_4','uL_4','L_5','uL_5', 'L_6','uL_6','L_7','uL_7','L_8','uL_8')
#
#  # Which source will be survived/removed?
#  survived <- apply( X = Lxs[,Lx_colnames], MARGIN = 1, FUN = function(x) !any(is.na(x)) )
#  removed  <- which( !survived )
#
#  # Notice which one will be removed
#  if ( sum(removed) > 0 ) {
#    message("\n* ", paste(removed, collapse = ','), "-th sources have NaN luminosity value in ANY band, so they are removed", sep = '')
#  }
#
#  # Sort out survived sources
#  Lxs <- Lxs[survived,]
#
#  return(list('data' = Lxs, 'survived' = survived))
#}


## Replace Lx which has 0-value with min([Lx])/2
#Replace_Zero_Lx <- function(Lxs) {
#  # Lx column names
#  Lx_colnames <- c('L_1','uL_1','L_2','uL_2','L_3','uL_3','L_4','uL_4','L_5','uL_5',
#                   'L_6','uL_6','L_7','uL_7','L_8','uL_8')
#
#  # Searching for 0-value
#  Replace_Zero_col <- function(x, bandname) {
#    b <<- b+1
#
#    # Zero value index
#    zero_idx <- which(x==0)
#
#    # Notice
#    if ( length(zero_idx) != 0 ) {
#      message("|>> In ",bandname[b], ", ", length(zero_idx), " source(s) (idx: ", paste(zero_idx, collapse=','), ") will be replaced with half-mininum value", sep='')
#    }
#
#    halfmin <- min(x[-zero_idx])/2
#    x[zero_idx] <- halfmin
#    return(x)
#  }
#
#  # Apply replacing fucntion column-wise
#  b <- 0
#  Lxs[,Lx_colnames] <- apply( X=Lxs[,Lx_colnames], MARGIN=2, Replace_Zero_col, bandname=Lx_colnames)
#
#  return(Lxs)
#}
#
## Replace Lx_err which has NaN with median
#Replace_NaNZero_Err <- function(Lxs) {
#  # Lx error column names
#  Lx_err_colnames <- c('L_1_lo','L_1_hi','uL_1_lo','uL_1_hi','L_2_lo','L_2_hi','uL_2_lo','uL_2_hi',
#                       'L_3_lo','L_3_hi','uL_3_lo','uL_3_hi','L_4_lo','L_4_hi','uL_4_lo','uL_4_hi',
#                       'L_5_lo','L_5_hi','uL_5_lo','uL_5_hi','L_6_lo','L_6_hi','uL_6_lo','uL_6_hi',
#                       'L_7_lo','L_7_hi','uL_7_lo','uL_7_hi','L_8_lo','L_8_hi','uL_8_lo','uL_8_hi')
#
#  # Searching for 0-value
#  Replace_NaN_col <- function(x, bandname) {
#    b <<- b+1
#
#    # NA value index
#    NAZERO_idx <- which(is.na(x) | x==0 )
#
#    # Notice
#    if ( length(NAZERO_idx) != 0 ) {
#      message("|>> In ",bandname[b], ", ", length(NAZERO_idx), " source(s) (idx: ", paste(NAZERO_idx, collapse=','), ") will be replaced with median value", sep='')
#    }
#
#    mederr <- median(x[-NAZERO_idx])
#    x[NAZERO_idx] <- mederr
#    return(x)
#  }
#
#  # Apply replacing fucntion column-wise
#  b <- 0
#  Lxs[,Lx_err_colnames] <- apply( X=Lxs[,Lx_err_colnames], MARGIN=2, Replace_NaN_col, bandname=Lx_err_colnames)
#
#  return(Lxs)
#}


get.glvary.col <- function(fluxdir, col.name) {
    #########################################################
    # col.name: SRC_VAR_ODDS / SRC_VAR_PROB / SRC_VAR_INDEX #
    #########################################################
    
    # Get file names: "{model_name}_obi###_{band}.flux"
    flux.obis <- grep(list.files(path = fluxdir), pattern="obi*", invert=FALSE, value=TRUE)
    if ( length(flux.obis) == 0 ) { # This means there is only one observation, so thus no obi* file.
      flux.obis <- grep(list.files(path = fluxdir), pattern="obi*", invert=TRUE, value=TRUE)
      
      # Store data
      obis <- lapply(flux.obis, function(file) {
        fits <- readFITS(paste(fluxdir, file, sep='/'))
        names(fits$col) <- fits$colNames
        list.cbind(fits$col) %>% as.data.frame() %>% distinct(COMPONENT, .keep_all=TRUE)
      })
      names(obis) <- flux.obis
      
      # Store meta info: obi, band for each file
      metas <- lapply( flux.obis, function(file) {
        band <- strsplit( strsplit( file, split = '_' )[[1]][2], split = '.flux' )[[1]][1]
        list('band' = band)
      } )
      names(metas) <- flux.obis
      metas.df <- melt(metas) %>% dcast(L1 ~ L2)
      colnames(metas.df) <- c('name', 'band')
      
      # Re-construct data into the listed data frame
      obi.list <- list()
      for (i in seq(nrow(metas.df))) {
        name <- metas.df[i,'name']
        band <- metas.df[i,'band']
        obi.list[[band]] <- obis[[name]][,col.name]
      }
      source_by_obi_per_band <- obi.list %>% 
        lapply(as.numeric) %>%
        list.cbind() %>% 
        as.data.frame()
      
    } else {
      # Store data
      obis <- lapply(flux.obis, function(file) {
        fits <- readFITS(paste(fluxdir, file, sep='/'))
        names(fits$col) <- fits$colNames
        list.cbind(fits$col) %>% as.data.frame() %>% distinct(COMPONENT, .keep_all=TRUE)
      })
      names(obis) <- flux.obis
      
      # Store meta info: obi, band for each file
      metas <- lapply( flux.obis, function(file) {
        obi  <- strsplit( file, split = '_' )[[1]][2]
        band <- strsplit( strsplit( file, split = '_' )[[1]][3], split = '.flux' )[[1]][1]
        list('obi' = obi, 'band' = band)
      } )
      names(metas) <- flux.obis
      metas.df <- melt(metas) %>% dcast(L1 ~ L2)
      colnames(metas.df) <- c('name', 'band', 'obi')
      
      # Re-construct data into the listed data frame
      obi.list <- list()
      for (i in seq(nrow(metas.df))) {
        name <- metas.df[i,'name']
        band <- metas.df[i,'band']
        obi  <- metas.df[i,'obi']
        obi.list[[band]][[obi]] <- obis[[name]][,col.name]
      }
      source_by_obi_per_band <- obi.list %>% 
        lapply( bind_cols ) %>% 
        lapply( function(band) apply(band, 2, as.numeric) %>% as.data.frame() ) %>%
        lapply(rowMeans) %>% # Taking mean value over multi observations # or lapply(function(band) apply(band, 1, median)) %>% # median
        bind_cols()
    }
    
    return(source_by_obi_per_band)
}


# Make data set for ML algorithm
MakeData <- function(fluxdir, flux.list, fluxcolumns, fluxerrcolumns, r_c, r_h, R_sun, labels, vary = T) {
    # Luminosity
    i <<- 0
    Lxs <- bind_cols(lapply(flux.list, Flux2Lx,
                            flux.list=flux.list,
                            fluxcolumns=fluxcolumns,
                            fluxerrcolumns=fluxerrcolumns,
                            r_c=r_c, r_h=r_h, R_sun=R_sun))
    
    ## Remove rows for NaN luminosity in ANY band
    #result   <- Remove_NaN_Lx(Lxs)
    #Lxs      <- result$data
    #survived <- result$survived
    
    # Replace Lx which has 0-value with min([Lx])/2
    #cat("\n")
    #Lxs <- Replace_Zero_Lx(Lxs)
    
    # Replace Lx_err which has NaN with median
    #cat("\n")
    #Lxs <- Replace_NaNZero_Err(Lxs)
    
    # Add color columns
    message("\n> Total 3 colors were created:
|> color1 = log10( L_1 / L_5 ) = log10(  Wide-Soft   /  Narrow-Soft )
|> color2 = log10( L_8 / L_2 ) = log10( Narrow-Total /  Wide-Medium )
|> color3 = log10( L_4 / L_7 ) = log10(  Wide-Total  /  Narrow-Hard )")
    #|> color1 = log10( L_1 / L_3 ), |> color2 = log10( L_4 / L_5 ), |> color3 = log10( L_2 / L_8 )")
 #* same manner for unabsorbed color (ucolor1; ucolor2; ucolor3)")
    Lxs <- Lxs %>%
      mutate( color1 = log10( L_1 / L_5 ) ) %>% 
      mutate( color2 = log10( L_8 / L_2 ) ) %>%
      mutate( color3 = log10( L_4 / L_7 ) )
    #  mutate(color1  = log10( L_1 / L_3 )) %>%
    #  mutate(ucolor1 = log10(uL_1 / uL_3)) %>%
    #  mutate(color2  = log10( L_4 / L_5 )) %>%
    #  mutate(ucolor2 = log10(uL_4 / uL_5)) %>%
    #  mutate(color3  = log10( L_2 / L_8 )) %>%
    #  mutate(ucolor3 = log10(uL_2 / uL_8))
    
    #### Zero-value luminosity problem has been solved by Replace_Zero_Lx
    # log1p_norm for luminosities
    #message("\n|>> Log10(x+1) for luminosites")
    #LxNLxerr <- grep("L", colnames(Lxs),value = TRUE)
    #Lxs[,LxNLxerr] <- apply( X=Lxs[,LxNLxerr], MARGIN=2, FUN=function(x) log10(x+1))
    
    # Combine with RCR
    DataSet <- cbind('source_type' = labels,
                     'AngDist'     = ANG,
                     'rcr'         = RCR,
                     'rhr'         = RHR,
                     'PhyDist'     = PhyDist,
                     Lxs)  # Lxs is already filtered out with 'survived'
    #DataSet <- cbind('source_type' = labels[survived,],
    #                 'AngDist'     = ANG[survived,],
    #                 'rcr'         = RCR[survived,],
    #                 'rhr'         = RHR[survived,],
    #                 'PhyDist'     = PhyDist[survived,],
    #                 Lxs)  # Lxs is already filtered out with 'survived'
    if (vary) {
        PROB <- get.glvary.col(fluxdir, col.name = 'SRC_VAR_PROB')  # We take "probability of variability"
        VARs <- PROB %>%
            select( c('0.3-1.0', '1.0-2.0', '2.0-7.0', '0.3-7.0',
                      '0.5-1.5', '1.5-4.5', '4.5-6.0', '0.5-6.0') ) %>% 
            `colnames<-`( paste('var', seq(8), sep = '_') )
        
        DataSet <- cbind(DataSet,
                         VARs)
        #DataSet <- cbind(DataSet,
        #                 VARs[survived,])
    }
    
    return(DataSet)
}


# Alert for missing parameters from Harris Catalog (2010)
missingParam <- function(GCname, param) {
  if ( is.na(get(param)) ) {
    stop("(Error) ",param, "is missing in Harris Catalog (2010) for ", GCname, "...")
  } else {
    message("|> ",param," = ",round(get(param),2)," is found",sep='')
  }
}


main <- function(GCname, fluxdir, vary, label_column) {
  # Searching parameters in Harris catalog (2010)
  GCCAT_dir <- system("echo $xrbgc", intern=TRUE)
  GCCAT <- read.csv(paste(GCCAT_dir,"/Harris_CAT.csv",sep=''))
  
  # Logical condition that matching given GCname and one in Harris catalog (2010)
  condition <- str_detect(GCCAT$ID, regex(GCname, ignore_case=TRUE))|str_detect(GCCAT$Name, regex(GCname, ignore_case=TRUE))
  if ( any(condition) ) {
    message("\n> ", GCname, " is found in Harris catalog (2010)")
  } else {
    stop("(Error) There is no ",GCname," in Harris catalog (2010)")
  }
  
  # Position in degree
  RA_cen  <<- filter(GCCAT, condition)[,"RA"] %>% as.character() %>% hms2deg()
  DEC_cen <<- filter(GCCAT, condition)[,"DEC"] %>% as.character() %>% dms2deg()
  
  # r_c & r_h in arcmin
  r_c <<- filter(GCCAT, condition)[,"r_c"] %>% as.character() %>% as.numeric()
  r_h <<- filter(GCCAT, condition)[,"r_h"] %>% as.character() %>% as.numeric()
  
  # R_sun in kpc
  R_sun <<- filter(GCCAT, condition)[,"R_Sun"] %>% as.character() %>% as.numeric()
  
  
  # Parameter checking ----
  message("> Parameters from Harris catalog...")
  parameter_from_Harris <- c("RA_cen", "DEC_cen", "r_c", "r_h", "R_sun")
  for (param in parameter_from_Harris) {
    missingParam(GCname, param)
  }
  
  
  # Load label information ----
  labels <- read.csv(matched.file)[,label_column, drop=FALSE]
  
  
  # Load data and arrange them ----
  message('\n> Arranging flux data \n> Band info')
  flux.files <- grep(list.files(path = fluxdir), pattern="obi*", invert=TRUE, value=TRUE) # Load merged flux data only
  flux.list <- lapply(flux.files, ArrangeFluxData)
  names(flux.list) <- lapply(flux.list, comment) %>% unlist()
  
  # Change the order of elements
  flux.list <- flux.list[c('0.3-1.0', '1.0-2.0', '2.0-7.0', '0.3-7.0', '0.5-1.5', '1.5-4.5', '4.5-6.0', '0.5-6.0')]
  
  
  # Making dataset ----
  DataSet <<- MakeData(fluxdir, flux.list, fluxcolumns, fluxerrcolumns, r_c, r_h, R_sun, labels, vary=vary)
  write.csv(DataSet, file = paste('DataSet_', gsub(" ","",GCname), '.csv', sep=''), row.names = F)
}
# ================================================================================================


# Run main function
main(GCname, fluxdir, vary, label_column)


# DONE ----
message("\n> ", paste('DataSet_',gsub(" ","",GCname),'.csv',sep=''), " is saved in: ", getwd(), sep='')
message("\n *** IMPORTANT: DO NOT CHANGE DataSet file name as input data for classification!")
#system('mkdir output_srcflux')
#system('mv {fluxes_*,srcflux_*,roi,listfiles} output_srcflux/')
