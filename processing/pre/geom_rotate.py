#!/usr/bin/env python3

import os
import sys
from io import StringIO
from optparse import OptionParser

from scipy import ndimage
import numpy as np

import damask


scriptName = os.path.splitext(os.path.basename(__file__))[0]
scriptID   = ' '.join([scriptName,damask.version])


#--------------------------------------------------------------------------------------------------
#                                MAIN
#--------------------------------------------------------------------------------------------------

parser = OptionParser(option_class=damask.extendableOption, usage='%prog options [geomfile(s)]', description = """
Rotates original microstructure and embeddeds it into buffer material.

""", version=scriptID)

parser.add_option('-r', '--rotation',
                  dest='rotation',
                  type = 'float', nargs = 4, metavar = ' '.join(['float']*4),
                  help = 'rotation given as axis and angle')
parser.add_option('-e', '--eulers',
                  dest = 'eulers',
                  type = 'float', nargs = 3, metavar = ' '.join(['float']*3),
                  help = 'rotation given as Euler angles')
parser.add_option('-d', '--degrees',
                  dest = 'degrees',
                  action = 'store_true',
                  help = 'Euler angles/axis angle are given in degrees')
parser.add_option('-m', '--matrix',
                  dest = 'matrix',
                  type = 'float', nargs = 9, metavar = ' '.join(['float']*9),
                  help = 'rotation given as matrix')
parser.add_option('-q', '--quaternion',
                  dest = 'quaternion',
                  type = 'float', nargs = 4, metavar = ' '.join(['float']*4),
                  help = 'rotation given as quaternion')
parser.add_option('-f', '--fill',
                  dest = 'fill',
                  type = 'float', metavar = 'int',
                  help = 'background microstructure index, defaults to max microstructure index + 1')

parser.set_defaults(degrees = False)

(options, filenames) = parser.parse_args()
if filenames == []: filenames = [None]

if [options.rotation,options.eulers,options.matrix,options.quaternion].count(None) < 3:
    parser.error('more than one rotation specified.')
if [options.rotation,options.eulers,options.matrix,options.quaternion].count(None) > 3:
    parser.error('no rotation specified.')

if options.quaternion is not None:
    rot = damask.Rotation.from_quaternion(np.array(options.quaternion))                             # we might need P=+1 here, too...
if options.rotation is not None:
    rot = damask.Rotation.from_axis_angle(np.array(options.rotation),degrees=options.degrees,normalise=True,P=+1)
if options.matrix is not None:
    rot = damask.Rotation.from_matrix(np.array(options.Matrix))
if options.eulers is not None:
    rot = damask.Rotation.from_Eulers(np.array(options.eulers),degrees=options.degrees)


for name in filenames:
    damask.util.report(scriptName,name)

    geom = damask.Geom.from_file(StringIO(''.join(sys.stdin.read())) if name is None else name)
    damask.util.croak(geom.rotate(rot,options.fill))
    geom.add_comments(scriptID + ' ' + ' '.join(sys.argv[1:]))
    geom.to_file(sys.stdout if name is None else name,pack=False)
