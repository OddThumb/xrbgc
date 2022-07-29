echo "
  =============================

        xrbgc (beta 0.7.0)

     > Author: Sang In Kim
     > Date: 17 July 2022
 
   \"Wrapper scripts for CIAO\"

   CIAO  version: 4.14
   ciao_contrib : 4.14.2
   CALDB version: 4.9.8

   Ref: Fruscione et al.(2006)
 ===============================
"
source $xrbgc/gcmlmanual.sh

rm -r ~/cxcds_param4
conda activate ciao

alias gcmlmanual="source $xrbgc/gcmlmanual.sh"
alias SpecExtract="source $xrbgc/bashs/SpecExtract.sh"
alias FitSherpa="python $xrbgc/pythons/FitSherpa.py"
alias BandSplit="source $xrbgc/bashs/BandSplit.sh"
alias Repro="source $xrbgc/bashs/Reprocessing.sh"
alias FluxImg="source $xrbgc/bashs/FluxImg.sh"
alias MergeWav="source $xrbgc/bashs/MergeWav.sh"
alias ReprojWav="source $xrbgc/bashs/ReprojWav.sh"
alias Match="Rscript $xrbgc/Rs/Match.R"
alias Srcflux="source $xrbgc/bashs/Srcflux.sh"
alias CalcnH="Rscript $xrbgc/Rs/CalcnH.R"
alias FovRegion="Rscript $xrbgc/Rs/FovRegion.R"
alias Make="Rscript $xrbgc/Rs/Make.R"
alias Table="Rscript $xrbgc/Rs/Table.R"
alias Find0Lx="Rscript $xrbgc/Rs/Find0Lx.R"
alias ReplaceLx="Rscript $xrbgc/Rs/ReplaceLx.R"
