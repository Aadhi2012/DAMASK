#!/usr/bin/env python
# -*- coding: UTF-8 no BOM -*-

import os,sys,string,math,operator
import numpy as np
from collections import defaultdict
from optparse import OptionParser
import damask

scriptID   = string.replace('$Id$','\n','\\n')
scriptName = os.path.splitext(scriptID.split()[1])[0]

def divFFT(geomdim,field):
 grid = np.array(np.shape(field)[0:3])
 N = grid.prod()                                                                                    # field size
 n = np.array(np.shape(field)[3:]).prod()                                                           # data size
 wgt = 1.0/N

 field_fourier = np.fft.fftpack.rfftn(field,axes=(0,1,2))
 div_fourier   = np.zeros(field_fourier.shape[0:len(np.shape(field))-1],'c16')                      # size depents on whether tensor or vector

# differentiation in Fourier space
 k_s=np.zeros([3],'i')
 TWOPIIMG = (0.0+2.0j*math.pi)
 for i in xrange(grid[0]):
   k_s[0] = i
   if(i > grid[0]/2 ): k_s[0] = k_s[0] - grid[0]
   for j in xrange(grid[1]):
     k_s[1] = j
     if(j > grid[1]/2 ): k_s[1] = k_s[1] - grid[1]
     for k in xrange(grid[2]/2+1):
       k_s[2] = k
       if(k > grid[2]/2 ): k_s[2] = k_s[2] - grid[2]
       xi=np.array([k_s[2]/geomdim[2]+0.0j,k_s[1]/geomdim[1]+0.j,k_s[0]/geomdim[0]+0.j],'c16')
       if n == 9:                                                                                   # tensor, 3x3 -> 3
         for l in xrange(3):
           div_fourier[i,j,k,l] = sum(field_fourier[i,j,k,l,0:3]*xi) *TWOPIIMG
       elif n == 3:                                                                                 # vector, 3 -> 1
         div_fourier[i,j,k] = sum(field_fourier[i,j,k,0:3]*xi) *TWOPIIMG

 return np.fft.fftpack.irfftn(div_fourier,axes=(0,1,2)).reshape([N,n/3])


# --------------------------------------------------------------------
#                                MAIN
# --------------------------------------------------------------------

parser = OptionParser(option_class=damask.extendableOption, usage='%prog options [file[s]]', description = """
Add column(s) containing divergence of requested column(s).
Operates on periodic ordered three-dimensional data sets.
Deals with both vector- and tensor-valued fields.

""", version = scriptID)

parser.add_option('-c','--coordinates',
                  dest = 'coords',
                  type = 'string', metavar = 'string',
                  help = 'column heading for coordinates [%default]')
parser.add_option('-v','--vector',
                  dest = 'vector',
                  action = 'extend', metavar = '<string LIST>',
                  help = 'heading of columns containing vector field values')
parser.add_option('-t','--tensor',
                  dest = 'tensor',
                  action = 'extend', metavar = '<string LIST>',
                  help = 'heading of columns containing tensor field values')

parser.set_defaults(coords = 'ipinitialcoord',
                   )

(options,filenames) = parser.parse_args()

if options.vector == None and options.tensor == None:
  parser.error('no data column specified.')

# --- loop over input files -------------------------------------------------------------------------

if filenames == []: filenames = [None]

for name in filenames:
  try:
    table = damask.ASCIItable(name = name,buffered = False)
  except:
    continue
  table.croak('\033[1m'+scriptName+'\033[0m'+(': '+name if name else ''))

# ------------------------------------------ read header ------------------------------------------

  table.head_read()

# ------------------------------------------ sanity checks ----------------------------------------

  items = {
            'tensor': {'dim': 9, 'shape': [3,3], 'labels':options.tensor, 'active':[], 'column': []},
            'vector': {'dim': 3, 'shape': [3],   'labels':options.vector, 'active':[], 'column': []},
          }
  errors  = []
  remarks = []
  column = {}
  
  if table.label_dimension(options.coords) != 3: errors.append('coordinates {} are not a vector.'.format(options.coords))
  else: coordCol = table.label_index(options.coords)

  for type, data in items.iteritems():
    for what in (data['labels'] if data['labels'] is not None else []):
      dim = table.label_dimension(what)
      if dim != data['dim']: remarks.append('column {} is not a {}.'.format(what,type))
      else:
        items[type]['active'].append(what)
        items[type]['column'].append(table.label_index(what))

  if remarks != []: table.croak(remarks)
  if errors  != []:
    table.croak(errors)
    table.close(dismiss = True)
    continue

# ------------------------------------------ assemble header --------------------------------------

  table.info_append(scriptID + '\t' + ' '.join(sys.argv[1:]))
  for type, data in items.iteritems():
    for label in data['active']:
      table.labels_append(['divFFT({})'.format(label) if type == 'vector' else
                           '{}_divFFT({})'.format(i+1,label) for i in xrange(data['dim']//3)])        # extend ASCII header with new labels
  table.head_write()

# --------------- figure out size and grid ---------------------------------------------------------

  table.data_readArray()

  coords = [{},{},{}]
  for i in xrange(len(table.data)):  
    for j in xrange(3):
      coords[j][str(table.data[i,coordCol+j])] = True
  grid = np.array(map(len,coords),'i')
  size = grid/np.maximum(np.ones(3,'d'),grid-1.0)* \
            np.array([max(map(float,coords[0].keys()))-min(map(float,coords[0].keys())),\
                      max(map(float,coords[1].keys()))-min(map(float,coords[1].keys())),\
                      max(map(float,coords[2].keys()))-min(map(float,coords[2].keys())),\
                      ],'d')                                                                        # size from bounding box, corrected for cell-centeredness

  size = np.where(grid > 1, size, min(size[grid > 1]/grid[grid > 1]))                               # spacing for grid==1 equal to smallest among other spacings

# ------------------------------------------ process value field -----------------------------------

  stack = [table.data]
  for type, data in items.iteritems():
    for i,label in enumerate(data['active']):
      stack.append(divFFT(size[::-1],                                                              # we need to reverse order here, because x is fastest,ie rightmost, but leftmost in our x,y,z notation
                          table.data[:,data['column'][i]:data['column'][i]+data['dim']].\
                          reshape([grid[2],grid[1],grid[0]]+data['shape'])))

# ------------------------------------------ output result -----------------------------------------

  if len(stack) > 1: table.data = np.hstack(tuple(stack))
  table.data_writeArray('%.12g')

# ------------------------------------------ output finalization -----------------------------------

  table.close()                                                                                     # close input ASCII table (works for stdin)
