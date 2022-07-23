condaenvpath=$(conda info | grep "envs directories" | sed 's/       envs directories : //')
envlist=($(ls $condaenvpath))

env_astropy=()
for env in ${envlist[@]}; do
    astropyinfo=$(conda list -n $env | grep astropy)
    if [ "$astropyinfo" != "" ]; then
        env_astropy+=(${env})
    fi
done
oneenv=${env_astropy[@]:0:1}

echo "${condaenvpath}/${oneenv}"
