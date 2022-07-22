echo "
  =============================

        xrbgc (beta 0.67)

     > Author: Sang In Kim
     > Date: 17 July 2022
 
   \"Wrapper scripts for CIAO\"

   CIAO  version: 4.14
   ciao_contrib : 4.14.2
   CALDB version: 4.9.8

   Ref: Fruscione et al.(2006)
 ===============================
"
export xrbgc="/Users/in/xrbgc"
source $xrbgc/gcmlmanual.sh

conda activate ciao

alias gcmlmanual="source $xrbgc/gcmlmanual.sh"
alias SpecExtract="source $xrbgc/SpecExtract.sh"
alias SpecFitting="source $xrbgc/SpecFitting.sh"
alias BandSplit="source $xrbgc/BandSplit.sh"
alias Repro="source $xrbgc/Reprocessing.sh"
alias FluxImg="source $xrbgc/FluxImg.sh"
alias MergeWav="source $xrbgc/MergeWav.sh"
alias WCScorr="source $xrbgc/WCScorr.sh"
alias Match="Rscript $xrbgc/Match.R"
alias Srcflux="source $xrbgc/srcflux.sh"
alias CalcnH="Rscript $xrbgc/CalcnH.R"
alias Make="Rscript $xrbgc/Make.R"
alias FovRegion="Rscript $xrbgc/FovRegion.R"
alias WCScorrect="source $xrbgc/WCScorrect.sh"
alias Table="Rscript $xrbgc/Table.R"
