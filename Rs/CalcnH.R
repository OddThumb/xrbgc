# Checking "tidyverse" package is installed
package.list <- list('tidyverse')
installed <- unlist(invisible(lapply(package.list, function(pkg) suppressMessages(suppressWarnings(require(pkg, character.only=TRUE, quietly=TRUE))))))
if (!all(installed)) {
  lapply(package.list[!installed], install.packages, quite=TRUE)
}
options(tidyverse.quiet = TRUE)
invisible(suppressMessages(suppressWarnings(require(tidyverse, quietly = TRUE))))

args <- commandArgs(trailingOnly=TRUE)
GCCATdir <- system("echo $xrbgc", intern = TRUE)
IDorNAME <- as.character(args[1])

GCCAT <- read.csv(paste(GCCATdir,"/HarrisCat/Harris_CAT.csv",sep=''))
EBV <- filter(GCCAT, str_detect(ID, regex(IDorNAME, ignore_case=TRUE))|str_detect(Name, regex(IDorNAME, ignore_case=TRUE)))[,"E.B.V."] %>% as.character() %>% as.numeric()
nH <- (EBV*6.86e21)/1e22
cat(nH)

