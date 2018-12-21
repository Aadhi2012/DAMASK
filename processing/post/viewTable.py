#!/usr/bin/env python3
# -*- coding: UTF-8 no BOM -*-

import os
from optparse import OptionParser
import damask

scriptName = os.path.splitext(os.path.basename(__file__))[0]
scriptID   = ' '.join([scriptName,damask.version])

# --------------------------------------------------------------------
#                                MAIN
# --------------------------------------------------------------------

parser = OptionParser(usage='%prog [options] [file[s]]', description = """
Show components of given ASCIItable(s).

""", version = scriptID)


parser.add_option('-a','--head',
                  dest   = 'head',
                  action = 'store_true',
                  help   = 'output complete header (info + labels)')
parser.add_option('-i','--info',
                  dest   = 'info',
                  action = 'store_true',
                  help   = 'output info lines')
parser.add_option('-l','--labels',
                  dest   = 'labels',
                  action = 'store_true',
                  help   = 'output labels')
parser.add_option('-d','--data',
                  dest   = 'data',
                  action = 'store_true',
                  help   = 'output data')
parser.add_option('-t','--table',
                  dest   = 'table',
                  action = 'store_true',
                  help   = 'output heading line for proper ASCIItable format')
parser.add_option('--nolabels',
                  dest   = 'labeled',
                  action = 'store_false',
                  help   = 'table has no labels')
parser.set_defaults(table  = False,
                    head   = False,
                    info   = False,
                    labels = False,
                    data   = False,
                    labeled = True,
                   )

(options,filenames) = parser.parse_args()

# --- loop over input files -------------------------------------------------------------------------

if filenames == []: filenames = [None]

for name in filenames:
  try:
    table = damask.ASCIItable(name = name,
                              buffered = False, labeled = options.labeled, readonly = True)
  except: continue
  damask.util.report(scriptName,name)

# ------------------------------------------ output head ---------------------------------------  

  table.head_read()
  if not (options.head or options.info):                         table.info_clear()
  if not (options.head or (options.labels and options.labeled)): table.labels_clear()

  table.head_write(header = options.table)

# ------------------------------------------ output data ---------------------------------------  

  outputAlive = options.data
  while outputAlive and table.data_read():                                                          # read next data line of ASCII table
    outputAlive = table.data_write()                                                                # output line

  table.close()
