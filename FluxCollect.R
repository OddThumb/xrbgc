# Directories ----
fluxdirectory <- "flux"
subdirectory  <- "flux_output"
if (!file.exists(fluxdirectory)) {
  stop("(Error) flux/ directory does not exist")
}

# Load libraries ----
package.list <- list("FITSio", "tidyverse", "abind")
installed <- unlist(lapply(package.list, require, character.only=TRUE))
if (!all(installed)) {
  lapply(package.list[!installed], install.packages, repos="https://cran.seoul.go.kr/", quite=TRUE)
}
lapply(package.list, require, character.only=TRUE)


# Create ouput directory ----
dir.create(subdirectory, showWarnings = F)


# Load data and arrange them ----
flux.files <- list.files(path = fluxdirectory, pattern = "out_obi*") # Load "out_obi~~~.flux" data only
input.bands <- sapply(flux.files, function(x) substr(x, 12, 18)) %>% as.factor() %>% levels() # Levels of energy band

data.list <- list()
for (i in seq(length(flux.files))) {
  cat('>>> Arranging flux data... (',i,'/',length(flux.files),')\n', sep='')
  
  # Read energy band
  band <- substr(flux.files[i], 12, 18)

  # Read fits flie
  fits <- readFITS(paste(fluxdirectory,flux.files[i],sep='/'))
  names(fits$col) <- fits$colNames
  table <- bind_cols(fits$col)
  
  # Select columns
  posNflux <- table %>% select(c("RAPOS", "DECPOS", # Coordinates
                                 "NET_MFLUX_APER",  "NET_MFLUX_APER_LO",  "NET_MFLUX_APER_HI",   # Absorbed flux
                                 "NET_UMFLUX_APER", "NET_UMFLUX_APER_LO", "NET_UMFLUX_APER_HI")) # Unabsorbed flux
  
  # Store data into a list with the energy band
  data.list[[band]] <- abind(data.list[[band]], posNflux, along=3)
}


# Functions ----
mean2 <- function(x) {
  x1 <- x[is.finite(x)] # Only for "non NA or NAN ..."
  mean(x1) # Calculate mean
}

err_sqmean <- function(x) {
  x1 <- x[is.finite(x)] # Only for "non NA or NAN ..."
  sqrt(sum(x1^2)) # Calculate "square root of sum of squares"
}


# Loop over bands ----
output.list <- list()
for (i in seq(data.list)) {
  cat('>>> Aggregating flux data for each band... (',i,'/',length(data.list),')\n', sep = '')
  
  band    <- input.bands[i] # Energy band
  cube    <- data.list[[i]] # Data cube
  pos     <- cube[,c("RAPOS", "DECPOS"),1] # Coordinate column
  flux    <- cube[,c("NET_MFLUX_APER","NET_UMFLUX_APER"),] # Flux column
  fluxerr <- cube[,c("NET_MFLUX_APER_LO",  "NET_MFLUX_APER_HI",    # Flux error column
                     "NET_UMFLUX_APER_LO", "NET_UMFLUX_APER_HI"),]

  # Aggregating
  aggregated.flux     <- apply(flux, c(1,2), mean2)
  aggregated.flux.err <- apply(fluxerr, c(1,2), err_sqmean)
  
  # Result
  result <- cbind(pos, aggregated.flux, aggregated.flux.err)
  colnames(result) <- c('ra','dec','mflux','umflux','mflux_ne','mflux_pe','umflux_ne','umflux_pe')
  result <- result[,c('ra','dec','mflux','mflux_ne','mflux_pe','umflux','umflux_ne','umflux_pe')]
  
  # Save as csv for each band
  write.csv(result, file = paste(subdirectory,"/flux_output_",band,".csv",sep=''), row.names = F)
  
  # Store into a list
  output.list[[band]] <- result
}


# Save the list of result as .Rdata ----
save(output.list, file = paste(subdirectory,"/flux_output.Rdata",sep=''))


cat('>>> CSV files are saved in ',subdirectory,'/ for each band,
    and Rdata file including all is also saved! \n', sep='')
