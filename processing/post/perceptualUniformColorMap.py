#!/usr/bin/env python

import math, string, sys, os
from damask import Color,Colormap
from optparse import OptionParser, Option

# -----------------------------
class extendableOption(Option):
# -----------------------------
# used for definition of new option parser action 'extend', which enables to take multiple option arguments
# taken from online tutorial http://docs.python.org/library/optparse.html
  
  ACTIONS = Option.ACTIONS + ("extend",)
  STORE_ACTIONS = Option.STORE_ACTIONS + ("extend",)
  TYPED_ACTIONS = Option.TYPED_ACTIONS + ("extend",)
  ALWAYS_TYPED_ACTIONS = Option.ALWAYS_TYPED_ACTIONS + ("extend",)

  def take_action(self, action, dest, opt, value, values, parser):
    if action == "extend":
      lvalue = value.split(",")
      values.ensure_value(dest, []).extend(lvalue)
    else:
      Option.take_action(self, action, dest, opt, value, values, parser)



# --------------------------------------------------------------------
                               # MAIN
# --------------------------------------------------------------------

parser = OptionParser(option_class=extendableOption, usage='%prog options [file[s]]', description = """
Add column(s) containing Cauchy stress based on given column(s) of
deformation gradient and first Piola--Kirchhoff stress.

""" + string.replace('$Id$','\n','\\n')
)

parser.add_option('-l','--left', dest='left', type='float', nargs=3, \
                  help='left color %default')
parser.add_option('-r','--right', dest='right', type='float', nargs=3, \
                  help='right color %default')
parser.add_option('-c','--colormodel', dest='colormodel', \
                  help='colormodel of left and right "RGB","HSL","XYZ","CIELAB","MSH" [%default]')
parser.add_option('-f','--format', dest='format', action='extend', \
                  help='output file format "paraview","gmsh","raw","GOM",[paraview, autodetect if output file extension is given]')
parser.add_option('-s','--steps', dest='steps', type='int', nargs = 1, \
                  help='no of interpolation steps [%default]')
parser.add_option('-t','--trim', dest='trim', type='float', nargs = 2, \
                  help='trim the colormap w.r.t the given values %default')

parser.set_defaults(colormodel = 'RGB')
parser.set_defaults(format = [''])
parser.set_defaults(steps = 10)
parser.set_defaults(trim = [-1.0,1.0])
parser.set_defaults(left = [1.0,1.0,1.0])
parser.set_defaults(right = [0.0,0.0,0.0])
(options,filenames) = parser.parse_args()

outtypes   = ['paraview','gmsh','raw','GOM']
extensions = ['.xml','.msh','.txt','.legend']
if options.trim[0]< -1.0 or \
   options.trim[1] > 1.0 or \
   options.trim[0]>= options.trim[1]:
   print 'invalid trim range'
   options.trim = [-1.0,1.0]

# ------------------------------------------ setup file handles ---------------------------------------  

files = []
if filenames == [] and options.format == ['']:
  files.append({'outtype':'paraview','output':sys.stdout,'name':'colormap'})

if (len(options.format) == (len(filenames)+1)) and (len(options.format) > 1):
  for i in xrange(1,len(options.format)):
    [basename,myExtension] = os.path.splitext(os.path.basename(filenames[i-1]))
    if options.format[i] in outtypes:
      myExtension = extensions[outtypes.index(options.format[i])]
      myType = outtypes[extensions.index(myExtension)]
    elif myExtension in extensions:
      myType = outtypes[extensions.index(myExtension)]
    else:
      myType = 'paraview'
      myExtension = extensions[outtypes.index(myType)]      
    files.append({'name':basename, 'output':open(basename+myExtension,'w'), 'outtype': myType})

if (len(options.format) > (len(filenames)+1)): 
  if (len(filenames) == 1) :
    [basename,myExtension] = os.path.splitext(os.path.basename(filenames[0]))
    for i in xrange(1,len(options.format)):
      if options.format[i] in outtypes:
        myExtension = extensions[outtypes.index(options.format[i])]
        myType = outtypes[extensions.index(myExtension)]
      else:
        myType = 'paraview'
        myExtension = extensions[outtypes.index(myType)]
      files.append({'name':basename, 'output':open(basename+myExtension,'w'), 'outtype': myType})
  elif len(filenames) == 0:
    for i in xrange(1,len(options.format)):
      if options.format[i] in outtypes:
        myExtension = extensions[outtypes.index(options.format[i])]
        myType = outtypes[extensions.index(myExtension)]
        basename = myType
      else:
        myType = 'paraview'
        myExtension = extensions[outtypes.index(myType)]
        basename = myType    
      files.append({'name':basename, 'output':open(basename+myExtension,'w'), 'outtype': myType})
  elif len(filenames) > 1:
    for i in xrange(len(filenames)):
      [basename,myExtension] = os.path.splitext(os.path.basename(filenames[i]))
      if options.format[i+1] in outtypes:
        myExtension = extensions[outtypes.index(options.format[i+1])]
        myType = outtypes[extensions.index(myExtension)]
      elif myExtension in extensions:
        myType = outtypes[extensions.index(myExtension)]
      else:
        myType = 'paraview'
        myExtension = extensions[outtypes.index(myType)]
      files.append({'name':basename, 'output':open(basename+myExtension,'w'), 'outtype': myType})
    for i in xrange(len(filenames)+1,len(options.format)):
      if options.format[i] in outtypes:
        myExtension = extensions[outtypes.index(options.format[i])]
        myType = outtypes[extensions.index(myExtension)]
        basename = myType
      else:
        myType = 'paraview'
        myExtension = extensions[outtypes.index(myType)]
        basename = myType
      files.append({'name':basename, 'output':open(basename+myExtension,'w'), 'outtype': myType})

if (len(options.format) < (len(filenames)+1)) and (options.format!=['']):
  for i in xrange(1,len(options.format)):
    [basename,myExtension] = os.path.splitext(os.path.basename(filenames[i-1]))
    if options.format[i] in outtypes:
      myExtension = extensions[outtypes.index(options.format[i])]
      myType = outtypes[extensions.index(myExtension)]
    elif (options.format[i] not in outtypes) and (myExtension in extensions):
      myType = outtypes[extensions.index(myExtension)]
    else:
      myType = 'paraview'
      myExtension = extensions[outtypes.index(myType)]
    files.append({'name':basename, 'output':open(basename+myExtension,'w'), 'outtype': myType})      # files.append({'name':basename, 'output':open(basename+myExtension,'w'), 'outtype': myType})
  for i in xrange((len(options.format)-1),len(filenames)):
    [basename,myExtension] = os.path.splitext(os.path.basename(filenames[i]))
    if myExtension.lower() in extensions:
      myType = outtypes[extensions.index(myExtension)]
    else:
      myType = 'paraview'
      myExtension = extensions[outtypes.index(myType)]
    files.append({'name':basename, 'output':open(basename+myExtension,'w'), 'outtype': myType})
    
elif (len(filenames)> 0) and (options.format == ['']):
 for [i,name] in enumerate(filenames):
  [basename,myExtension] = os.path.splitext(os.path.basename(name))
  if myExtension.lower() in extensions:
    myType = outtypes[extensions.index(myExtension)]
  else:
    myType = 'paraview'
    myExtension = extensions[outtypes.index(myType)]
  files.append({'name':basename, 'output':open(basename+myExtension,'w'), 'outtype': myType})  
    
leftColor = Color(options.colormodel.upper(),list(options.left))
rightColor = Color(options.colormodel.upper(),list(options.right))
myColormap = Colormap(leftColor,rightColor)

for file in files:
  outColormap = myColormap.export(file['name'],file['outtype'],options.steps,list(options.trim))
  file['output'].write(outColormap)
  file['output'].close()
