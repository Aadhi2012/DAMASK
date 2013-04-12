#!/usr/bin/env python
# -*- coding: UTF-8 no BOM -*-

import os,sys,string,math,numpy
from optparse import OptionParser, OptionGroup, Option, SUPPRESS_HELP


# -----------------------------
class extendedOption(Option):
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


# ----------------------- MAIN -------------------------------

minimal_surfaces = ['primitive','gyroid','diamond',]

surface = {
            'primitive': lambda x,y,z: math.cos(x)+math.cos(y)+math.cos(z),
            'gyroid':    lambda x,y,z: math.sin(x)*math.cos(y)+math.sin(y)*math.cos(z)+math.cos(x)*math.sin(z),
            'diamond':   lambda x,y,z: math.cos(x-y)*math.cos(z)+math.sin(x+y)*math.sin(z),
          }
  

parser = OptionParser(option_class=extendedOption, usage='%prog', description = """
Generate a geometry file of a bicontinuous structure of given type.
""" + string.replace('$Id$','\n','\\n')
)

parser.add_option('-t','--type', dest='type', type='string', \
                  help='type of minimal surface (%s)'%(','.join(minimal_surfaces)))
parser.add_option('-f','--threshold', dest='threshold', type='float', \
                  help='threshold value defining minimal surface [%default]')
parser.add_option('-g', '--grid', dest='grid', type='int', nargs=3, \
                  help='a,b,c grid of hexahedral box %default')
parser.add_option('-s', '--size', dest='size', type='float', nargs=3, \
                  help='x,y,z size of hexahedral box %default')
parser.add_option('-p', '--periods', dest='periods', type='int', \
                  help='number of repetitions of unit cell [%default]')
parser.add_option('--homogenization', dest='homogenization', type='int', \
                  help='homogenization index to be used [%defaults]')
parser.add_option('--phase', dest='phase', type='int', nargs = 2, \
                  help='two phase indices to be used %default')
parser.add_option('-2', '--twodimensional', dest='twoD', action='store_true', \
                  help='output geom file with two-dimensional data arrangement [%default]')

parser.set_defaults(type = minimal_surfaces[0])
parser.set_defaults(threshold = 0.0)
parser.set_defaults(periods = 1)
parser.set_defaults(grid = numpy.array([16,16,16]))
parser.set_defaults(size = numpy.array([1.0,1.0,1.0]))
parser.set_defaults(homogenization = 1)
parser.set_defaults(phase = [1,2])
parser.set_defaults(twoD  = False)

(options, args) = parser.parse_args()

# ------------------------------------------ setup file handles ---------------------------------------  

file = {'name':'STDIN',
          'input':sys.stdin,
          'output':sys.stdout,
          'croak':sys.stderr,
       }

if numpy.any(options.grid < 1):
  file['croak'].write('invalid grid...\n')
  sys.exit()

if numpy.any(options.size < 0.0):
  file['croak'].write('invalid size...\n')
  sys.exit()


file['output'].write("6 header\n" + \
                     "$Id$\n" +\
                     "grid\ta %i\tb %i\tc %i\n"%(options.grid[0],options.grid[1],options.grid[2],) + \
                     "size\tx %g\ty %g\tz %g\n"%(options.size[0],options.size[1],options.size[2],) + \
                     "origin\tx 0\ty 0\tz 0\n" + \
                     "microstructures 2\n" +\
                     "homogenization %i\n"%options.homogenization
                     )

for z in xrange(options.grid[2]):
  Z = options.periods*2.0*math.pi*(z+0.5)/options.grid[2]
  for y in xrange(options.grid[1]):
    Y = options.periods*2.0*math.pi*(y+0.5)/options.grid[1]
    for x in xrange(options.grid[0]):
      X = options.periods*2.0*math.pi*(x+0.5)/options.grid[0]
      file['output'].write(\
        str({True:options.phase[0],False:options.phase[1]}[options.threshold > surface[options.type](X,Y,Z)]) + \
        {True:' ',False:'\n'}[options.twoD] )
    file['output'].write({True:'\n',False:''}[options.twoD])
