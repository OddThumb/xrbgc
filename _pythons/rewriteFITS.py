def re_writeFITs(data, index, filename, addcol=None, coldtype=None, colname=None):
    import numpy as np
    from astropy.io import fits
    hdul = fits.open(data)

    if isinstance(index, list):
        index=np.array(index)
        newdata = hdul[1].data[index-1] # Because these indicies from R, it should be subtracted by 1
    else:
        newdata = hdul[1].data[index-1:index]
    hdu = fits.BinTableHDU(newdata)
   
    if addcol != None:
        if colname == None:
            colname = "unnamed"
        if coldtype == None:
            coldtype == np.dtype(object)
        newcol  = fits.Column(name=colname, format=coldtype, array=addcol)
        newcols = newdata.columns + newcol
        hdu = fits.BinTableHDU.from_columns(newcols)
    
    outputname = filename
    hdu.writeto(outputname, overwrite=True)
