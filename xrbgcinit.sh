echo "
  =============================

        xrbgc (beta 0.6.8)

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
alias SpecExtract="source $xrbgc/bashs/SpecExtract.sh"
alias SpecFitting="source $xrbgc/bashs/SpecFitting.sh"
alias BandSplit="source $xrbgc/bashs/BandSplit.sh"
alias Repro="source $xrbgc/bashs/Reprocessing.sh"
alias FluxImg="source $xrbgc/bashs/FluxImg.sh"
alias MergeWav="source $xrbgc/bashs/MergeWav.sh"
alias ReprojWav="source $xrbgc/bashs/ReprojWav.sh"
alias Match="Rscript $xrbgc/Rs/Match.R"
alias Srcflux="source $xrbgc/bashs/srcflux.sh"
alias CalcnH="Rscript $xrbgc/Rs/CalcnH.R"
alias Make="Rscript $xrbgc/Rs/Make.R"
alias FovRegion="Rscript $xrbgc/Rs/FovRegion.R"
alias WCScorrect="source $xrbgc/bashs/WCScorrect.sh"
alias Table="Rscript $xrbgc/Rs/Table.R"
