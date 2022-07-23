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
label_column <- "source_type"


# Load libraries ----
options(tidyverse.quiet = TRUE)
package.list <- list("tidyverse")
installed <- unlist(lapply(package.list, function(pkg) invisible(suppressMessages(suppressWarnings(require(pkg, character.only=TRUE, quietly=TRUE))))))
if (!all(installed)) {
    lapply(package.list[!installed], install.packages, repos="https://cran.seoul.go.kr/")
}


# data load function
data_load <- function(file, label_column='source_type') {
    package.list <- c('tools', 'stringr')
    check_installed(package.list)
    sapply(package.list, require, character.only=TRUE)
    
    if ( file_ext(file)=="csv" ) {
        # Naming
        name0 <- strsplit(file, "\\_|\\.")[[1]][2]
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
            name0 <- strsplit(l, "\\_|\\.")[[1]][2]
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
indicies <- which(select(data %>% filter(source_type %in% c('CV','MSP')), Lxs) == 0, arr.ind = T)


# Result
result <- indicies %>% 
    as.data.frame() %>% 
    mutate(band = bands[col]) %>% 
    mutate(`ra (deg)`  = radec[row,'RA']) %>%
    mutate(`dec (deg)` = radec[row, 'DEC']) %>%
    rename('index' = row) %>% 
    select(-col) %>% 
    relocate(band, .after = `dec (deg)`)
print(result)


# write csv for manual flux calculation
write.csv(result,
          file = paste(gsub(" ", "", attr(data, 'GC'), fixed = TRUE), '_manualList.csv', sep=''),
          quote = F)


