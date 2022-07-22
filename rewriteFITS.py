def re_writeFITs(data, index, subdirectory, angular_threshold):
    import numpy as np
    from astropy.io import fits
    hdul = fits.open(data)
    if isinstance(index, list):
        index=np.array(index)
        newdata = hdul[1].data[index-1]
    else:
        newdata = hdul[1].data[index-1:index]
    hdu = fits.BinTableHDU(newdata)
    outputname = subdirectory+"/source_matched_"+str(angular_threshold)+".fits"
    hdu.writeto(outputname)
