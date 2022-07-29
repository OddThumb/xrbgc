# Input arguments directory ----
if (!suppressMessages(suppressWarnings(require('argparse', character.only=TRUE, quietly=TRUE)))) {
    install.packages('argparse')
}
suppressMessages(suppressWarnings(require(argparse, quietly=TRUE)))
parser <- ArgumentParser()
parser$add_argument("-n", "--GCname", type="character",
                    help="GC name with white space")
parser$add_argument("-f", "--file", type="character",
                    help="A path of csv file")
parser$add_argument("-m", "--manlist", type="character",
                    help="A path of ManualList_*.csv file")
args <- parser$parse_args()
GCname  <- args$GCname
file    <- args$file
manlist <- args$manlist


# Check input files
if ( is.null(GCname) ) {
    stop('GC name need to be given for R_Sun value in Harris CAT (2010)')
} else if ( is.null(file) ) {
    stop('File is not provided')
} else if ( is.null(manlist) ) {
    stop('ManualList_*.csv file is not provided')
}


# Load libraries ----
options(warn=0)
options(tidyverse.quiet = TRUE)
package.list <- list("tidyverse")
installed <- unlist(lapply(package.list, function(pkg) invisible(suppressMessages(suppressWarnings(require(pkg, character.only=TRUE, quietly=TRUE))))))
if (!all(installed)) {
    lapply(package.list[!installed], install.packages, repos="https://cran.seoul.go.kr/")
}


# Functions ----
check_installed <- function(packages, install=TRUE) {
    installed <- unlist(lapply(packages, require, character.only=TRUE))
    if (!all(installed) & install) {
        lapply(package.list[!installed], install.packages, repos="https://cran.seoul.go.kr/", quite=TRUE)
    }
    lapply(package.list, require, character.only=TRUE)
}

data_load <- function(file, label_column='source_type') {
    package.list <- c('stringr')
    check_installed(package.list)
    sapply(package.list, function(pkg) invisible(suppressMessages(suppressWarnings(require(pkg, character.only=TRUE)))))
    
    if ( tools::file_ext(file)=="csv" ) {
        # Naming
        name0 <- strsplit(file, "\\_|\\.")[[1]]
        name0 <- name0[length(name0)-1]
        letters <- gsub(x = name0, pattern = "[[:digit:]]+", replacement = "")
        numbers <-  gsub(x = name0, pattern = "[^[:digit:]]+", replacement = "")
        letters_loc <- str_locate(name0, letters)
        numbers_loc <- str_locate(name0, numbers)
        name <- ifelse(numbers_loc[1] < letters_loc[1], paste(numbers,letters,sep=' '), paste(letters,numbers,sep=' '))
        
        DATA <- read.csv(file) %>% mutate(GC=name)
        fac.levels <- sort(unique(DATA[,label_column]))
        DATA[,label_column] <- factor(DATA[,label_column], levels=fac.levels)
        attr(DATA, 'GC') <- name
        
        return(DATA)
    } else {
        message("\n!!! Input ",file," file is not a csv file, assuming a list of files...")
        data.list.file <- read.table(file)$V1
        DATA.LIST <- list()
        
        for (l in data.list.file) {
            name0 <- strsplit(file, "\\_|\\.")[[1]]
            name0 <- name0[length(name0)-1]
            letters <- gsub(x = name0, pattern = "[[:digit:]]+", replacement = "")
            numbers <- gsub(x = name0, pattern = "[^[:digit:]]+", replacement = "")
            letters_loc <- str_locate(name0, letters)
            numbers_loc <- str_locate(name0, numbers)
            name <- ifelse(numbers_loc[1] < letters_loc[1], paste(numbers,letters,sep=' '), paste(letters,numbers,sep=' '))
            DATA <- read.csv(l) %>% mutate(GC=name)
            attr(DATA, 'GC') <- name
            DATA.LIST[[name]] <- DATA
        }
        
        return(DATA.LIST)
    }
}

getValHarris <- function(GCname, col) {
    GCCAT <- read.csv(paste("~/xrbgc/HarrisCAT/Harris_CAT.csv",sep=''))
    
    # Logical condition that matching given GCname and one in Harris catalog (2010)
    condition <- str_detect(GCCAT$ID, regex(GCname, ignore_case=TRUE))|str_detect(GCCAT$Name, regex(GCname, ignore_case=TRUE))
    if ( !any(condition) ) {
        stop("(Error) There is no ",GCname," in Harris catalog (2010)")
    }
    
    # value
    val  <- filter(GCCAT, condition)[,col] %>% as.character() %>% as.numeric()
    
    return(val)
}

flux2Lx <- function(flux, GCname) {
    onePCinCM <- 3.086e+18
    R_Sun <- getValHarris(GCname, 'R_Sun')
    L <- flux * 4*pi * ( 1e3*R_Sun * onePCinCM )^2 # R_sun in kpc
    return(L)
}


# Load data
data   <- data_load(file)
mantab <- read.csv(manlist) %>% `colnames<-`(c('X','index','ra','dec','band'))


# Pairing between Lx column number and the corresponding band
bandinfo <- c('0.3-1.0'=1,'1.0-2.0'=2,'2.0-7.0'=3,'0.3-7.0'=4,
              '0.5-1.5'=5,'1.5-4.5'=6,'4.5-6.0'=7,'0.5-6.0'=8)


# Replacing
L_b.df <- data.frame()
data.copy <- data
for ( i in seq(nrow(mantab)) ) {
    # Info from ManualList_*.csv
    row.id <- mantab[i,'index']
    band   <- mantab[i,'band']
    
    # Message
    message("For ", row.id, '-th source with band ', band, ', lumonosity value is changed')
    
    # Flux Data ({GCname}_flux_{band}.csv)
    flux <- read.csv(paste('spec/',gsub(" ", "",GCname),'_flux_',band,'.csv',sep=''))
    
    # Calculate luminosity
    L_b    <- flux2Lx(flux %>% filter(X == paste('src',row.id,sep='')) %>% select('uF_X'), GCname)[[1]]
    L_b_lo <- flux2Lx(flux %>% filter(X == paste('src',row.id,sep='')) %>% select('uF_X_lo'), GCname)[[1]]
    L_b_hi <- flux2Lx(flux %>% filter(X == paste('src',row.id,sep='')) %>% select('uF_X_hi'), GCname)[[1]]
    
    # Save as side table
    L_b.df <- bind_rows(L_b.df, c('source_type' = as.character(data.copy[row.id,'source_type']),
                                  'L_b'=L_b, 'L_b_lo'=L_b_lo, 'L_b_hi'=L_b_hi,
                                  'index2'=row.id))
    
    # Replacing
    data.copy[row.id, paste('L_', bandinfo[[band]], sep='')]        <- L_b
    data.copy[row.id, paste('L_', bandinfo[[band]], '_lo', sep='')] <- L_b_lo
    data.copy[row.id, paste('L_', bandinfo[[band]], '_hi', sep='')] <- L_b_hi
}
message('Total ', i, ' luminosity values have been replaced' )


# Update manual table
mantab.new <- bind_cols(mantab, L_b.df) %>% select(-c('X'))


# Re-calculate colors
data.repl <- data.copy %>%
    mutate( color1 = log10( L_1 / L_5 ) ) %>% 
    mutate( color2 = log10( L_8 / L_2 ) ) %>%
    mutate( color3 = log10( L_4 / L_7 ) )


# write csv for manual flux calculation
ManTab_name  <- paste('ManualTable_', gsub(" ", "", unique(select(data, 'GC')), fixed = TRUE), '.csv', sep='')
DataSet_name <- paste('DataSet_', gsub(" ", "", unique(select(data, 'GC')), fixed = TRUE), '_Repl.csv', sep='')
write.csv(mantab.new,
          file = ManTab_name,
          quote = F, row.names = F)
write.csv(data.repl,
          file = DataSet_name,
          quote = F, row.names = F)
message(ManTab_name, ', ', DataSet_name, ' is saved in current directory')




