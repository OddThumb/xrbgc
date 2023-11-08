import os
import numpy as np
import matplotlib
import matplotlib.pylab as plt
from sherpa.astro.ui import *

from collections import namedtuple
ReturnValue = namedtuple('ReturnValue', 'name value units description')

matplotlib.use("agg")

def srcflux_obsid_plugin(infile, outroot, band, elo, ehi, src_num, myparams):
    """
    Sample srcflux plugin: fitting spectrum for each individual obsid

    This sample plugin uses sherpa to fit a spectral model, and
    return an estimate of the flux w/ errors calculated with
    the sample_flux routine.

    We wrap the actual fitting code below in a try/except block
    here so that we can always return nan's in the case of any error.
    """
    elo=elo/1000. # in unit of keV
    ehi=ehi/1000. # in unit of keV

    try:
        return doit_specfit(infile, outroot, band, elo, ehi, src_num, myparams)
    except Exception as wrong:
        print(str(wrong))
        print(f"Problem fitting {outroot} spectrum. Skipping it.")

        return [ReturnValue("grp_counts", np.nan, "", "Group count"),
                ReturnValue("nH", np.nan, "cm**22", "Fitted Absorption value"),
                ReturnValue("PhoIndex", np.nan, "", "Photon index"),
                ReturnValue("norm", np.nan, "", "Spectrum Normalization"),
                ReturnValue("reduced_statistic", np.nan, "", "Reduced Fit Statistic"),
                ReturnValue("fit_statistic", np.nan, "", "Fit Statistic"),
                ReturnValue("dof", np.nan, "", "Degrees of Freedom"),
                ReturnValue("sample_flux", np.nan, "", f"{elo:.1f}-{ehi:.1f} keV Sample Flux"),
                ReturnValue("sample_flux_lo", np.nan, "", f"{elo:.1f}-{ehi:.1f} Sample Flux Uncertainty Low"),
                ReturnValue("sample_flux_hi", np.nan, "", f"{elo:.1f}-{ehi:.1f} Sample Flux Uncertainty High"),
                ]


def srcflux_merge_plugin(infile, outroot, band, elo, ehi, src_num, myparams):
    """
    Sample srcflux plugin: fitting spectrum for the combine spectra.

    In this example it is the same plugin as the per-observation plugin,
    but it does not have to be.
    """

    return srcflux_obsid_plugin(infile, outroot, band, elo, ehi, src_num, myparams)


def doit_specfit(infile, outroot, band, elo, ehi, src_num, myparams):
    """
    Perform the spectral fit: an absorbed model with
    |  abs1.nH.freeze()
    |  model.param.freeze()
    Here, model.param depends on input of srcflux script.

    e.g.)
    If       'xspowerlaw.p1' is the model you want to fit,
        p1.PhoIndex.freeze()
    else if  'xsbbodyrad.b1',
        b1.kT.freeze()
    else     'xsapec.a1',
        a1.kT.freeze()
    """
    
    from sherpa.utils.logging import SherpaVerbosity

    # Find the spectrum file (per-obi vs. merged file names)
    if os.path.exists(outroot+".pi"):
        pi_file = outroot+".pi"
    elif os.path.exists(outroot+"_src.pi"):
        pi_file = outroot+"_src.pi"
    else:
        raise IOError(f"Unable to locate source spectrum for this source number: {src_num}")
		

    # Suppress some of the sherpa chatter
    with SherpaVerbosity('WARN'):
        # Load spectrum
        load_data(pi_file)

        # Check counts and grouping
        counts = calc_data_sum(lo=elo, hi=ehi)

        group_counts(1)
        ignore_bad()

        # Pre-process
        ignore(None,elo)
        ignore(ehi,None)

        # Setting
        set_source(eval(myparams.absmodel)*eval(myparams.model)) #set_source(xsphabs.abs1*xspowerlaw.p1)
        set_stat('cstat')

        # Call params
        exec(myparams.paramvals)
        exec(myparams.absparams)

        # Freeze params
        # abs1.nH.freeze() #  FIX nH
        exec(".".join([myparams.absparams.split("=")[0], "freeze()"])) #FIX nH
        # p1.PhoIndex.freeze()  #  FIX Gamma
        exec(".".join([myparams.paramvals.split(";")[0].split("=")[0], "freeze()"])) #FIX Gamma

        # Fit
        fit()
        fit_info = get_fit_results()

        # Sampling Flux with conf
        _, cflux, _ = sample_flux(lo=elo, hi=ehi,
                                  num=100,
                                  numcores=-1, 
                                  confidence=float(myparams.conf)*100, 
                                  modelcomponent=p1)
        f0, fhi, flo = cflux

        try:
            plot_fit_resid(xlog=True, ylog=True)
            plt.savefig(outroot+"_"+f"{elo:.1f}"+"-"+f"{ehi:.1f}"+".png")
        except Exception as plot_error:
            pass
 

    return [ReturnValue("grp_counts", counts, "", "Group count"),
            ReturnValue("nH", abs1.nH.val, "cm**-22", "Fitted Absorption value"),
            ReturnValue("PhoIndex", p1.PhoIndex.val, "", "Photon index"),
            ReturnValue("norm", p1.norm.val, "", "Spectrum Normalization"),
            ReturnValue("reduced_statistic", fit_info.rstat, "", "Reduced Fit Statistic"),
            ReturnValue("fit_statistic", fit_info.statval, "", "Fit Statistic"),
            ReturnValue("dof", fit_info.dof, "", "Degrees of Freedom"),
            ReturnValue("sample_flux", f0, "", f"{elo:.1f}-{ehi:.1f} keV Sample Flux"),
            ReturnValue("sample_flux_lo", flo, "", f"{elo:.1f}-{ehi:.1f} Sample Flux Uncertainty Low"),
            ReturnValue("sample_flux_hi", fhi, "", f"{elo:.1f}-{ehi:.1f} Sample Flux Uncertainty High"),
            ]
