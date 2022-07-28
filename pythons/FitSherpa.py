import argparse
import glob, re
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from fnmatch import translate
from sherpa.astro.ui import *


# Arguments setting
parser = argparse.ArgumentParser(description='spectral fitting with sherpa')
parser.add_argument('-a', '--absnh', type=float, help='absorption of neutral hydrogen column density (nh)')
parser.add_argument('-m', '--model', default='xspowerlaw.pl',
                    help='''spectral fitting model
    power-law: "xspowerlaw.pl"
    blackbody: "xsbbodyrad.bb"
    apec:      "xsapec.ap"''')
parser.add_argument('-p', '--param', default='pl.phoindex=1.7;pl.norm=1e-5',
                    help='''spectral fitting model
    power-law: "pl.phoindex=1.7;pl.norm=1e-5"
    blackbody: "bb.kt=3;bb.norm=1"
    apec:      "ap.kt=1;ap.norm=1"''')
parser.add_argument('-b', '--band', default="0.5-6.0",
                    help='energy band to calculate flux. e.g.) "0.5-6.0" (default)')
args = parser.parse_args()
absnh = args.absnh
model = args.model
param = args.param
band = args.band


# Decode energy band
en_lo = float(band.split('-')[0])
en_hi = float(band.split('-')[1])


# Set confidence interval of 90%
set_conf_opt('sigma', 1.6)


# glob source spectrum file (*.pi)
pilist = glob.glob("Obs*_*[!bkg].pi")


# get region index numbers 
reglist = np.unique( list( map( lambda x: x.split('/')[-1].split('_')[-1].split('.')[0], pilist ) ) )


# Create empty data frame to store flux values
flux_df = pd.DataFrame(columns = ['F_X',  'F_X_lo',   'F_X_hi',
                                  'uF_X', 'uF_X_lo' , 'uF_X_hi'],
                       index   = reglist)


# Arranging pi files per region index
pi_per_reg = []
for reg in range( len( reglist ) ):
    r = re.compile( translate( 'Obs*_'+reglist[reg]+'.pi' ) )
    pi_per_reg.append( list( filter( r.match, pilist ) ) )


# Fit and Compute flux
for i, pi1reg in enumerate(pi_per_reg):
    
    # Iterate over pi files in one region
    indices=[]
    for j, pi in enumerate(pi1reg):
        print("\nLoad data with id: "+str(j))
        indices.append(j)
        
        # load a pha file from one region
        load_pha(j,pi)

        # Set energy range
        set_analysis('energy')
        notice_id(j, en_lo, en_hi)
        subtract(j)

        # Set absorption parameter
        set_source(j, xsphabs.abs1 * eval(model))
        abs1.nH = absnh
        freeze(abs1.nH)

        # Set model parameters
        for par in param.split(';'):
            exec(par)
        
        # Change statistic method to "cstat" "chi2xspecvar"
        set_stat('chi2xspecvar')
    
    # Fit model
    fit(exec('indices'))
    fitres = get_fit_results()
    
    # Fitted plot
    plt.figure(figsize=(10,8))
    plot_fit_delchi(xlog=True, ylog=True)
    plt.savefig("Region"+reglist[i]+"_figfig.ps",format="eps") 

    # Computing flux
    print("\nCalculating fluxes for region "+reglist[i])
    flux, uflux, _ = sample_flux(modelcomponent=pl, lo=en_lo, hi=en_hi,
                                    num=1000, numcores=8, confidence=90)
    flux_df.iloc[0] = [flux[0],  flux[0]  - flux[2],  flux[1]  - flux[0],
                       uflux[0], uflux[0] - uflux[2], uflux[1] - uflux[0]]

    show_all(outfile="Region"+reglist[i]+"_fitres.txt", clobber=True)


# Save flux data frame to csv file
prefix = os.path.dirname( os.getcwd() ).split('/')[-1]
flux_df.to_csv(prefix+'_flux.csv')
