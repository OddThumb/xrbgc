#!/bin/bash

# Searching conda environments
condaenvpath=$(conda info | grep "envs directories" | sed 's/       envs directories : //')
envlist=($(ls $condaenvpath))

# Check whether conda is installed
if [ "${#envlist[@]}" -eq "0" ]; then
    echo "ERROR1"
else

    # Searching astropy in all environment
    env_astropy=()
    for env in ${envlist[@]}; do
        astropyinfo=$(conda list -n $env | grep astropy)
        if [ "$astropyinfo" != "" ]; then
            env_astropy+=(${env})
        fi
    done
    
    # Check wheter astropy is installed
    if [ "${#env_astropy[@]}" -eq 0 ]; then
        echo "ERROR2"
    else 
        oneenv=${env_astropy[@]:0:1}
        echo "${condaenvpath}/${oneenv}"
    fi
fi
