#!/usr/bin/env python3

import os
import sys
from io import StringIO
from optparse import OptionParser

import damask


scriptName = os.path.splitext(os.path.basename(__file__))[0]
scriptID   = ' '.join([scriptName,damask.version])


# --------------------------------------------------------------------
#                                MAIN
# --------------------------------------------------------------------

parser = OptionParser(option_class=damask.extendableOption, usage='%prog options [ASCIItable(s)]', description = """
Uniformly shift column values by given offset.

""", version = scriptID)

parser.add_option('-l','--label',
                  dest = 'labels',
                  action = 'extend', metavar = '<string LIST>',
                  help  ='column(s) to shift')
parser.add_option('-o','--offset',
                  dest = 'offset',
                  action = 'extend', metavar='<float LIST>',
                  help = 'offset(s) per column')

parser.set_defaults(label  = [],
                    offset = [])

(options,filenames) = parser.parse_args()
if filenames == []: filenames = [None]

if len(options.labels) != len(options.offset):
    parser.error('number of column labels and offsets do not match.')

for name in filenames:
    damask.util.report(scriptName,name)

    table = damask.Table.from_ASCII(StringIO(''.join(sys.stdin.read())) if name is None else name)
    for label,offset in zip(options.labels,options.offset):
        table.set(label,table.get(label)+float(offset),scriptID+' '+' '.join(sys.argv[1:]))

    table.to_ASCII(sys.stdout if name is None else name)
