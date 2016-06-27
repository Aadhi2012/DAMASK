#!/usr/bin/env python2
# -*- coding: UTF-8 no BOM -*-

import os,sys
from optparse import OptionParser
import damask

scriptName = os.path.splitext(os.path.basename(__file__))[0]
scriptID   = ' '.join([scriptName,damask.version])

# --------------------------------------------------------------------
#                                MAIN
# --------------------------------------------------------------------

parser = OptionParser(option_class=damask.extendableOption, usage='%prog options [file[s]]', description = """
Append data of ASCIItable(s).

""", version = scriptID)

parser.add_option('-a', '--add','--table',
                  dest = 'table',
                  action = 'extend', metavar = '<string LIST>',
                  help = 'tables to add')

(options,filenames) = parser.parse_args()

# --- loop over input files -------------------------------------------------------------------------

if filenames == []: filenames = [None]

for name in filenames:
  try:    table = damask.ASCIItable(name = name,
                                    buffered = False)
  except: continue

  damask.util.report(scriptName,name)

  tables = []
  for addTable in options.table:
    try:    tables.append(damask.ASCIItable(name = addTable,
                                            buffered = False,
                                            readonly = True)
                         )
    except: continue

# ------------------------------------------ read headers ------------------------------------------

  table.head_read()
  for addTable in tables: addTable.head_read()

# ------------------------------------------ assemble header --------------------------------------

  table.info_append(scriptID + '\t' + ' '.join(sys.argv[1:]))

  for addTable in tables: table.labels_append(addTable.labels(raw = True))                          # extend ASCII header with new labels

  table.head_write()

# ------------------------------------------ process data ------------------------------------------

  outputAlive = True
  while outputAlive and table.data_read():
    for addTable in tables:
      outputAlive = addTable.data_read()                                                            # read next table's data
      if not outputAlive: break
      table.data_append(addTable.data)                                                              # append to master table
    if outputAlive:
      outputAlive = table.data_write()                                                              # output processed line

# ------------------------------------------ output finalization -----------------------------------  

  table.close()                                                                                     # close ASCII tables
  for addTable in tables:
    addTable.close()
