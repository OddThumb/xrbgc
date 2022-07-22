# Checking "tidyverse" package is installed
package.list <- list('tidyverse')
installed <- unlist(lapply(package.list, require, character.only=TRUE))
if (!all(installed)) {
  lapply(package.list[!installed], install.packages, repos="https://cran.seoul.go.kr/", quite=TRUE)
}
library("tidyverse")

args <- commandArgs(trailingOnly=TRUE)
GCCATdir <- system("echo $cTools", intern = TRUE)
IDorNAME <- as.character(args[1])

GCCAT <- read.csv(paste(GCCATdir,"/Harrison_CAT.csv",sep=''))
EBV <- filter(GCCAT, str_detect(ID, regex(IDorNAME, ignore_case=TRUE))|str_detect(Name, regex(IDorNAME, ignore_case=TRUE)))[,"E.B.V."] %>% as.character() %>% as.numeric()
nH <- (EBV*6.86e21)/1e22
cat(nH)

