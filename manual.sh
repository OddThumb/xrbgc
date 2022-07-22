#!/bin/bash

echo '
 (0) Data download
 (1) cRepro
 (2) cMergeWav
  ↳(2-1) if multiple observations does not match with coordinates,
          cWCScorrect
 (3) (MANUAL) Prepare "ra,dec,source_type" csv file
 (4) rMatch (conda env name) (path/to/the/csv/file) (path/to/source_list.fits)
 (5) cSrcflux "GC Name"
 (6) rMakeData "GC Name"
'
