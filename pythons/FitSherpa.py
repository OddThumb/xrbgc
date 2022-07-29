import argparse
import os, glob, re, subprocess
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from subprocess import Popen, PIPE
from fnmatch import translate
from sherpa.astro.ui import *


# Arguments setting
parser = argparse.ArgumentParser(description='spectral fitting with sherpa')
parser.add_argument('-n', '--GCname', help='GC name with white space')
parser.add_argument('-m', '--model', default='xspowerlaw.pl',
                    help='''spectral fitting model
    power-law: "xspowerlaw.pl"
    blackbody: "xsbbodyrad.bb"
    apec:      "xsapec.ap"''')
parser.add_argument('-p', '--param', default='pl.PhoIndex=1.7;pl.norm=1e-5',
                    help='''spectral fitting model
    power-law: "pl.PhoIndex=1.7;pl.norm=1e-5"
    blackbody: "bb.kT=3;bb.norm=1"
    apec:      "ap.kT=1;ap.norm=1"''')
parser.add_argument('-b', '--band', default="0.5-6.0",
                    help='energy band to calculate flux. e.g.) "0.5-6.0" (default)')
args = parser.parse_args()
GCname = args.GCname
model  = args.model
param  = args.param
band   = args.band


# Get nH value
CalcnH_run = Popen("Rscript ${xrbgc}/Rs/CalcnH.R \'"+GCname+"\'", shell=True, stdout=PIPE)
CalcnH_return, _ = CalcnH_run.communicate()
absnh = CalcnH_return.decode("utf-8")


# Decode energy band
en_lo = float(band.split('-')[0])
en_hi = float(band.split('-')[1])


# Set confidence interval of 90% and energy unit
set_conf_opt('sigma', 1.6)
set_analysis('energy')


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
        load_pha(j, pi)

        # Set energy range
        notice_id(j, 0.3, 7.0)

        # masking group
        d = get_data(j)
        mask = d.mask

        # Grouping
        group_bins(j, 25, tabStops=~mask)

        # Subtract background
        #subtract(j) # comment this line for cstat or wstat

        # Set absorption parameter
        set_source(j, xsphabs.abs1 * eval(model))
        abs1.nH = absnh
        freeze(abs1.nH)

        # Set model parameters
        for par in param.split(';'):
            exec(par)
        
        # Change statistic method to "wstat", "cstat", "chi2xspecvar"
        set_stat('cstat')
    
    # Fit model
    fit(exec('indices'))
    fitres = get_fit_results()
    
    # Fitted plot
    plt.figure(figsize=(9,6))
    set_xlog()
    set_ylog()
    plot_fit_resid(xlog=True, ylog=True) # plot_fit_delchi
    plt.savefig("Region_"+reglist[i]+"_"+band+"_fitfig.ps",format="eps") 
    plt.close()

    # Computing flux
    print("\nCalculating fluxes for region "+reglist[i])
    component = model.split('.')[1]
    flux, uflux, _ = sample_flux(modelcomponent=eval(component), lo=en_lo, hi=en_hi,
                                 num=1000, numcores=8, confidence=90)
    flux_df.iloc[i] = [flux[0],  flux[0]-flux[2],   flux[1]-flux[0],   # 0: flux, 1: upper bound, 2: lower bound
                       uflux[0], uflux[0]-uflux[2], uflux[1]-uflux[0]]

    show_all(outfile="Region_"+reglist[i]+"_"+band+"_fitres.txt", clobber=True)
    
    clean()


# Save flux data frame to csv file
prefix = os.path.dirname( os.getcwd() ).split('/')[-1]
flux_df.to_csv(prefix+'_flux_'+band+'.csv')
