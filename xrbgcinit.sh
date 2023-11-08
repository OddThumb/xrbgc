#!/bin/bash

# Help text
usage="xginit [-h] [-i -e]
where:
      -h  Show this help text
      -i  Initialize (remove) directory: ~/cxcds_param4
          (Default: false)
      -e  Show expamles of workflow (xgmanual)
          (Default: false)"

# Default values
init_rm=false
example=false

# Get arguments
while getopts ":hi:e:" opt; do
    case $opt in
        h)  echo "$usage"
            exit 0
            ;;
        i)  init_rm="$OPTARG"
            ;;
        e)  example="$OPTARG"
            ;;
        :)  printf "missing argument for -%s\n" "$OPTARG" >&2
            echo "$usage" >&2
            exit 1
            ;;
        \?) printf "illegal option: -%s\n" "$OPTARG" >&2
            echo "$usage" >&2
            exit 1
            ;;
    esac
done


# Initialize (remove) cxcds_param4 directory or not
if $init_rm; then
	rm -rf ~/cxcds_param4
fi

# Activate ciao
conda activate $xrbgc_ciao
export PATH="$xrbgc:$xrbgc/bashs:$xrbgc/Rs:$xrbgc/Pythons:$PATH"

# CIAO version info
echo "Reading installed ciao config..."
ciao_ver=$(${xrbgc_ciao}/bin/ciaover | grep -E '(^|\s)ciao($|\s)')
ciao_ver=(${ciao_ver})
ciao_contrib_ver=$(${xrbgc_ciao}/bin/ciaover | grep "ciao-contrib")
ciao_contrib_ver=(${ciao_contrib_ver})
caldb_ver=$(${xrbgc_ciao}/bin/ciaover | grep "caldb_main")
caldb_ver=(${caldb_ver})

echo "
 ┌──────────────────────────────┐

          xrbgc (v1.0.0)         
                                  
      > Author: Sang In Kim       
      > Date: 08 Nov 2023          
                                   
     Wrapper scripts for CIAO         
                                      
     CIAO  version: ${ciao_ver[1]} 
     ciao_contrib : ${ciao_contrib_ver[1]} 
     CALDB version: ${caldb_ver[1]} 
                                 
    Ref: Fruscione et al.(2006)  
 └──────────────────────────────┘
"

# Show examples of workflow (xgmanual)
if $example; then
	source $xrbgc/xgmanual
fi
