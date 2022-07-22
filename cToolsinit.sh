#!/bin/zsh
echo "
  =============================

        cTools (beta 0.5)

     > Author: Sang In Kim
     > Date: 30 August 2021

   ciao-version: 4.13
   Ref: Fruscione et al.(2006)
  =============================

>>> ciao-4.13 (conda) is activated!
"
conda activate ciao-4.13

export cTools="/Users/in/cTools"
alias cTmanual="bash $cTools/manual.sh"
alias cSpecExtract="bash $cTools/SpecExtract.sh"
alias cSpecFitting="bash $cTools/SpecFitting.sh"
alias cBandSplit="bash $cTools/BandSplit.sh"
alias cRepro="bash $cTools/Reprocessing.sh"
alias cMergeWav="bash $cTools/MergeWav.sh"
alias rMatch="Rscript $cTools/Match.R"
alias rFluxCollect="Rscript $cTools/FluxCollect.R"
alias cSrcflux="bash $cTools/srcflux.sh"
alias rCalcnH="Rscript $cTools/CalcnH.R"
alias rMakeData="Rscript $cTools/MakeData.R"
alias rFovregion="Rscript $cTools/Fovregion.R"
alias cWCScorrect="bash $cTools/WCScorrect.sh"
alias rClassif="Rscript $cTools/Classif.R"
alias rTable="Rscript $cTools/Table.R"
