#!/usr/bin/env python3

import os
import argparse

import numpy as np

import damask

scriptName = os.path.splitext(os.path.basename(__file__))[0]
scriptID   = ' '.join([scriptName,damask.version])

# --------------------------------------------------------------------
#                                MAIN
# --------------------------------------------------------------------
parser = argparse.ArgumentParser()

#ToDo:  We need to decide on a way of handling arguments of variable lentght
#https://stackoverflow.com/questions/15459997/passing-integer-lists-to-python

#parser.add_argument('--version', action='version', version='%(prog)s {}'.format(scriptID))
parser.add_argument('filenames', nargs='+',
                    help='DADF5 files')
parser.add_argument('-d','--dir', dest='dir',default='postProc',metavar='string',
                    help='name of subdirectory relative to the location of the DADF5 file to hold output')
parser.add_argument('--mat', nargs='+',
                    help='labels for materialpoint',dest='mat')
parser.add_argument('--con', nargs='+',
                    help='labels for constituent',dest='con')

options = parser.parse_args()

if options.mat is None: options.mat=[]
if options.con is None: options.con=[]

# --- loop over input files ------------------------------------------------------------------------

for filename in options.filenames:
  results = damask.DADF5(filename)
  
  if not results.structured: continue
  if results.version_major == 0 and results.version_minor >= 5:
    coords = damask.grid_filters.cell_coord0(results.grid,results.size,results.origin) 
  else:
    coords = damask.grid_filters.cell_coord0(results.grid,results.size)
  
  N_digits = int(np.floor(np.log10(int(results.increments[-1][3:]))))+1
  N_digits = 5 # hack to keep test intact
  for i,inc in enumerate(results.iter_visible('increments')):
    print('Output step {}/{}'.format(i+1,len(results.increments)))

    table = damask.Table(np.ones(np.product(results.grid),dtype=int)*int(inc[3:]),{'inc':(1,)})
    table.add('pos',coords.reshape((-1,3)))

    results.set_visible('materialpoints',False)
    results.set_visible('constituents',  True)
    for label in options.con:
      x = results.get_dataset_location(label)
      if len(x) != 0:
        table.add(label,results.read_dataset(x,0,plain=True).reshape((results.grid.prod(),-1)))

    results.set_visible('constituents',  False)
    results.set_visible('materialpoints',True)
    for label in options.mat:
      x = results.get_dataset_location(label)
      if len(x) != 0:
        table.add(label,results.read_dataset(x,0,plain=True).reshape((results.grid.prod(),-1)))

    dirname  = os.path.abspath(os.path.join(os.path.dirname(filename),options.dir))
    if not os.path.isdir(dirname):
      os.mkdir(dirname,0o755)
    file_out = '{}_inc{}.txt'.format(os.path.splitext(os.path.split(filename)[-1])[0],
                                     inc[3:].zfill(N_digits))
    table.to_ASCII(os.path.join(dirname,file_out))
