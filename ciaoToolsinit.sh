#!/bin/zsh
echo "
  =============================

        cTools (beta 0.4)

     > Author: Sang In Kim
     > Date: 30 August 2021

   ciao-version: 4.13
   Ref: Fruscione et al.(2006)
  =============================

>>> ciao-4.13 (conda) is activated!
"
conda activate ciao-4.13

export cTools="/Users/in/cTools"
alias cBandSplit="bash $cTools/Sh_scripts/BandSplit.sh"
alias cRepro="bash $cTools/Sh_scripts/Reprocessing.sh"
alias cMergeWav="bash $cTools/Sh_scripts/MergeWav.sh"
alias cSrcflux="bash $cTools/Sh_scripts/cSrcflux.sh"
alias cWCScorrect="bash $cTools/Sh_scripts/WCScorrect.sh"
alias rCalcnH="Rscript $cTools/R_scripts/CalcnH.R"
alias rClassif="Rscript $cTools/R_scripts/Classif.R"
alias rFovregion="Rscript $cTools/R_scripts/Fovregion.R"
alias rMakeData="Rscript $cTools/R_scripts/MakeData.R"
alias rMatch="Rscript $cTools/R_scripts/Match.R"
alias rTable="Rscript $cTools/R_scripts/Table.R"
