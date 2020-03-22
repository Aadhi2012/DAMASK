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
Rename scalar, vectorial, and/or tensorial data header labels.

""", version = scriptID)

parser.add_option('-l','--label',
                  dest = 'label',
                  action = 'extend', metavar='<string LIST>',
                  help = 'column(s) to rename')
parser.add_option('-s','--substitute',
                  dest = 'substitute',
                  action = 'extend', metavar='<string LIST>',
                  help = 'new column label(s)')

parser.set_defaults(label = [],
                    substitute = [],
                   )

(options,filenames) = parser.parse_args()
if filenames == []: filenames = [None]

if len(options.label) != len(options.substitute):
    parser.error('number of column labels and substitutes do not match.')

for name in filenames:
    damask.util.report(scriptName,name)

    table = damask.Table.from_ASCII(StringIO(''.join(sys.stdin.read())) if name is None else name)
    for label,substitute in zip(options.label,options.substitute):
        table.rename(label,substitute,scriptID+' '+' '.join(sys.argv[1:]))

    table.to_ASCII(sys.stdout if name is None else name)
