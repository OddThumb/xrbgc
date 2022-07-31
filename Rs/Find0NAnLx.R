# Input arguments directory ----
if (!suppressMessages(suppressWarnings(require('argparse', character.only=TRUE, quietly=TRUE)))) {
    install.packages('argparse')
}
suppressMessages(suppressWarnings(require(argparse, quietly=TRUE)))
parser <- ArgumentParser()
parser$add_argument("-f", "--file", type="character",
                    help="A path of csv file")
parser$add_argument("-m", "--match", type="character",
                    help="A path of matched_sourcetypes_*.csv file")
args <- parser$parse_args()
file  <- args$file
match <- args$match


# Check input files
if ( is.null(file) ) {
    stop('File is not provided')
} else if ( is.null(match) ) {
    stop('matched_sourcetypes_*.csv file is not provided')
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


# Load data
data  <- data_load(file)
radec <- read.csv(match)


# Define Lx columns and their bands
Lxs <- paste('L_', seq(8), sep='')
bands <- c('0.3-1.0', '1.0-2.0', '2.0-7.0', '0.3-7.0', '0.5-1.5', '1.5-4.5', '4.5-6.0', '0.5-6.0')


# Searching Lx == 0
search.data <- select(data, all_of(Lxs))
indicies <- which( ( search.data == 0 | is.na(search.data) ), arr.ind = T)


# Result
result <- indicies %>% 
    as.data.frame() %>% 
    mutate(band = bands[col]) %>% 
    mutate('ra'  = radec[row,'RA']) %>%
    mutate('dec' = radec[row, 'DEC']) %>%
    rename('index' = row) %>% 
    select(-col) %>% 
    relocate(band, .after = 'dec')

if ( nrow(result) == 0 ) {
    message('There is no any source having 0 Lx')
    
} else {
    print(result)
    
    # write csv for manual flux calculation
    output_name <- paste('ManualList_', gsub(" ", "", unique(select(data, 'GC')), fixed = TRUE), '.csv', sep='')
    write.csv(result,
              file = output_name,
              quote = F)
    message(output_name, ' is saved in current directory')
}


