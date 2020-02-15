from queue import Queue
import re
import glob
import os

import vtk
from vtk.util import numpy_support
import h5py
import numpy as np

from . import util
from . import version
from . import mechanics

# ------------------------------------------------------------------
class DADF5():
  """
  Read and write to DADF5 files.

  DADF5 files contain DAMASK results.
  """

# ------------------------------------------------------------------
  def __init__(self,fname):
    """
    Opens an existing DADF5 file.

    Parameters
    ----------
    fname : str
        name of the DADF5 file to be openend.

    """
    with h5py.File(fname,'r') as f:

      try:
        self.version_major = f.attrs['DADF5_version_major']
        self.version_minor = f.attrs['DADF5_version_minor']
      except KeyError:
        self.version_major = f.attrs['DADF5-major']
        self.version_minor = f.attrs['DADF5-minor']

      if self.version_major != 0 or not 2 <= self.version_minor <= 6:
        raise TypeError('Unsupported DADF5 version {}.{} '.format(f.attrs['DADF5_version_major'],
                                                                  f.attrs['DADF5_version_minor']))

      self.structured = 'grid' in f['geometry'].attrs.keys()

      if self.structured:
        self.grid = f['geometry'].attrs['grid']
        self.size = f['geometry'].attrs['size']
        if self.version_major == 0 and self.version_minor >= 5:
          self.origin = f['geometry'].attrs['origin']


      r=re.compile('inc[0-9]+')
      increments_unsorted = {int(i[3:]):i for i in f.keys() if r.match(i)}
      self.increments     = [increments_unsorted[i] for i in sorted(increments_unsorted)]
      self.times          = [round(f[i].attrs['time/s'],12) for i in self.increments]

      self.Nmaterialpoints, self.Nconstituents =   np.shape(f['mapping/cellResults/constituent'])
      self.materialpoints  = [m.decode() for m in np.unique(f['mapping/cellResults/materialpoint']['Name'])]
      self.constituents    = [c.decode() for c in np.unique(f['mapping/cellResults/constituent']  ['Name'])]

      self.con_physics  = []
      for c in self.constituents:
        self.con_physics += f['/'.join([self.increments[0],'constituent',c])].keys()
      self.con_physics = list(set(self.con_physics))                                                # make unique

      self.mat_physics = []
      for m in self.materialpoints:
        self.mat_physics += f['/'.join([self.increments[0],'materialpoint',m])].keys()
      self.mat_physics = list(set(self.mat_physics))                                                # make unique

    self.visible= {'increments':     self.increments,
                   'constituents':   self.constituents,
                   'materialpoints': self.materialpoints,
                   'constituent':    range(self.Nconstituents),                                     # ToDo: stupid naming
                   'con_physics':    self.con_physics,
                   'mat_physics':    self.mat_physics}

    self.fname = fname


  def __manage_visible(self,datasets,what,action):
    """
    Manages the visibility of the groups.

    Parameters
    ----------
    datasets : list of str or Boolean
      name of datasets as list, supports ? and * wildcards.
      True is equivalent to [*], False is equivalent to []
    what : str
      attribute to change (must be in self.visible)
    action : str
      select from 'set', 'add', and 'del'

    """
    # allow True/False and string arguments
    if datasets is True:
      datasets = ['*']
    elif datasets is False:
      datasets = []
    choice = [datasets] if isinstance(datasets,str) else datasets

    valid = [e for e_ in [glob.fnmatch.filter(getattr(self,what),s) for s in choice] for e in e_]
    existing = set(self.visible[what])

    if   action == 'set':
      self.visible[what] = valid
    elif action == 'add':
      self.visible[what] = list(existing.union(valid))
    elif action == 'del':
      self.visible[what] = list(existing.difference_update(valid))


  def __time_to_inc(self,start,end):
    selected = []
    for i,time in enumerate(self.times):
      if start <= time <= end:
        selected.append(self.increments[i])
    return selected


  def set_by_time(self,start,end):
    """
    Set active increments based on start and end time.

    Parameters
    ----------
    start : float
      start time (included)
    end : float
      end time (included)

    """
    self.__manage_visible(self.__time_to_inc(start,end),'increments','set')


  def add_by_time(self,start,end):
    """
    Add to active increments based on start and end time.

    Parameters
    ----------
    start : float
      start time (included)
    end : float
      end time (included)

    """
    self.__manage_visible(self.__time_to_inc(start,end),'increments','add')


  def del_by_time(self,start,end):
    """
    Delete from active increments based on start and end time.

    Parameters
    ----------
    start : float
      start time (included)
    end : float
      end time (included)

    """
    self.__manage_visible(self.__time_to_inc(start,end),'increments','del')


  def set_by_increment(self,start,end):
    """
    Set active time increments based on start and end increment.

    Parameters
    ----------
    start : int
      start increment (included)
    end : int
      end increment (included)

    """
    if self.version_minor >= 4:
      self.__manage_visible([    'inc{}'.format(i) for i in range(start,end+1)],'increments','set')
    else:
      self.__manage_visible(['inc{:05d}'.format(i) for i in range(start,end+1)],'increments','set')


  def add_by_increment(self,start,end):
    """
    Add to active time increments based on start and end increment.

    Parameters
    ----------
    start : int
      start increment (included)
    end : int
      end increment (included)

    """
    if self.version_minor >= 4:
      self.__manage_visible([    'inc{}'.format(i) for i in range(start,end+1)],'increments','add')
    else:
      self.__manage_visible(['inc{:05d}'.format(i) for i in range(start,end+1)],'increments','add')


  def del_by_increment(self,start,end):
    """
    Delet from active time increments based on start and end increment.

    Parameters
    ----------
    start : int
      start increment (included)
    end : int
      end increment (included)

    """
    if self.version_minor >= 4:
      self.__manage_visible([    'inc{}'.format(i) for i in range(start,end+1)],'increments','del')
    else:
      self.__manage_visible(['inc{:05d}'.format(i) for i in range(start,end+1)],'increments','del')


  def iter_visible(self,what):
    """
    Iterate over visible items by setting each one visible.

    Parameters
    ----------
    what : str
      attribute to change (must be in self.visible)

    """
    datasets = self.visible[what]
    last_datasets = datasets.copy()
    for dataset in datasets:
      if last_datasets != self.visible[what]:
        self.__manage_visible(datasets,what,'set')
        raise Exception
      self.__manage_visible(dataset,what,'set')
      last_datasets = self.visible[what]
      yield dataset
    self.__manage_visible(datasets,what,'set')


  def set_visible(self,what,datasets):
    """
    Set active groups.

    Parameters
    ----------
    datasets : list of str or Boolean
      name of datasets as list, supports ? and * wildcards.
      True is equivalent to [*], False is equivalent to []
    what : str
      attribute to change (must be in self.visible)

    """
    self.__manage_visible(datasets,what,'set')


  def add_visible(self,what,datasets):
    """
    Add to active groups.

    Parameters
    ----------
    datasets : list of str or Boolean
      name of datasets as list, supports ? and * wildcards.
      True is equivalent to [*], False is equivalent to []
    what : str
      attribute to change (must be in self.visible)

    """
    self.__manage_visible(datasets,what,'add')


  def del_visible(self,what,datasets):
    """
    Delete from active groupse.

    Parameters
    ----------
    datasets : list of str or Boolean
      name of datasets as list, supports ? and * wildcards.
      True is equivalent to [*], False is equivalent to []
    what : str
      attribute to change (must be in self.visible)

    """
    self.__manage_visible(datasets,what,'del')


  def groups_with_datasets(self,datasets):
    """
    Get groups that contain all requested datasets.

    Only groups within inc?????/constituent/*_*/* inc?????/materialpoint/*_*/*
    are considered as they contain the data.
    Single strings will be treated as list with one entry.

    Wild card matching is allowed, but the number of arguments need to fit.

    Parameters
    ----------
      datasets : iterable or str or boolean

    Examples
    --------
      datasets = False matches no group
      datasets = True matches all groups
      datasets = ['F','P'] matches a group with ['F','P','sigma']
      datasets = ['*','P'] matches a group with ['F','P']
      datasets = ['*'] does not match a group with ['F','P','sigma']
      datasets = ['*','*'] does not match a group with ['F','P','sigma']
      datasets = ['*','*','*'] matches a group with ['F','P','sigma']

    """
    if datasets is False: return []
    sets = [datasets] if isinstance(datasets,str) else datasets

    groups = []

    with h5py.File(self.fname,'r') as f:
      for i in self.iter_visible('increments'):
        for o,p in zip(['constituents','materialpoints'],['con_physics','mat_physics']):
          for oo in self.iter_visible(o):
            for pp in self.iter_visible(p):
              group = '/'.join([i,o[:-1],oo,pp])                              # o[:-1]: plural/singular issue
              if sets is True:
                groups.append(group)
              else:
                match = [e for e_ in [glob.fnmatch.filter(f[group].keys(),s) for s in sets] for e in e_]
                if len(set(match)) == len(sets) : groups.append(group)
    return groups


  def list_data(self):
    """Return information on all active datasets in the file."""
    message = ''
    with h5py.File(self.fname,'r') as f:
      for i in self.iter_visible('increments'):
        message+='\n{} ({}s)\n'.format(i,self.times[self.increments.index(i)])
        for o,p in zip(['constituents','materialpoints'],['con_physics','mat_physics']):
          for oo in self.iter_visible(o):
            message+='  {}\n'.format(oo)
            for pp in self.iter_visible(p):
              message+='    {}\n'.format(pp)
              group = '/'.join([i,o[:-1],oo,pp])                              # o[:-1]: plural/singular issue
              for d in f[group].keys():
                try:
                  dataset = f['/'.join([group,d])]
                  message+='      {} / ({}): {}\n'.format(d,dataset.attrs['Unit'].decode(),dataset.attrs['Description'].decode())
                except KeyError:
                  pass
    return message


  def get_dataset_location(self,label):
    """Return the location of all active datasets with given label."""
    path = []
    with h5py.File(self.fname,'r') as f:
      for i in self.iter_visible('increments'):
        k = '/'.join([i,'geometry',label])
        try:
          f[k]
          path.append(k)
        except KeyError as e:
          pass
        for o,p in zip(['constituents','materialpoints'],['con_physics','mat_physics']):
          for oo in self.iter_visible(o):
            for pp in self.iter_visible(p):
              k = '/'.join([i,o[:-1],oo,pp,label])
              try:
                f[k]
                path.append(k)
              except KeyError as e:
                pass
    return path


  def get_constituent_ID(self,c=0):
    """Pointwise constituent ID."""
    with h5py.File(self.fname,'r') as f:
      names = f['/mapping/cellResults/constituent']['Name'][:,c].astype('str')
    return np.array([int(n.split('_')[0]) for n in names.tolist()],dtype=np.int32)


  def get_crystal_structure(self):                                                                  # ToDo: extension to multi constituents/phase
    """Info about the crystal structure."""
    with h5py.File(self.fname,'r') as f:
      return f[self.get_dataset_location('orientation')[0]].attrs['Lattice'].astype('str')          # np.bytes_ to string


  def read_dataset(self,path,c=0,plain=False):
    """
    Dataset for all points/cells.

    If more than one path is given, the dataset is composed of the individual contributions.
    """
    with h5py.File(self.fname,'r') as f:
      shape = (self.Nmaterialpoints,) + np.shape(f[path[0]])[1:]
      if len(shape) == 1: shape = shape +(1,)
      dataset = np.full(shape,np.nan,dtype=np.dtype(f[path[0]]))
      for pa in path:
        label = pa.split('/')[2]

        if (pa.split('/')[1] == 'geometry'):
          dataset = np.array(f[pa])
          continue

        p = np.where(f['mapping/cellResults/constituent'][:,c]['Name'] == str.encode(label))[0]
        if len(p)>0:
          u = (f['mapping/cellResults/constituent']['Position'][p,c])
          a = np.array(f[pa])
          if len(a.shape) == 1:
            a=a.reshape([a.shape[0],1])
          dataset[p,:] = a[u,:]

        p = np.where(f['mapping/cellResults/materialpoint']['Name'] == str.encode(label))[0]
        if len(p)>0:
          u = (f['mapping/cellResults/materialpoint']['Position'][p.tolist()])
          a = np.array(f[pa])
          if len(a.shape) == 1:
            a=a.reshape([a.shape[0],1])
          dataset[p,:] = a[u,:]

    if plain and dataset.dtype.names is not None:
      return dataset.view(('float64',len(dataset.dtype.names)))
    else:
      return dataset


  def cell_coordinates(self):
    """Return initial coordinates of the cell centers."""
    if self.structured:
      delta = self.size/self.grid*0.5
      z, y, x = np.meshgrid(np.linspace(delta[2],self.size[2]-delta[2],self.grid[2]),
                            np.linspace(delta[1],self.size[1]-delta[1],self.grid[1]),
                            np.linspace(delta[0],self.size[0]-delta[0],self.grid[0]),
                           )
      return np.concatenate((x[:,:,:,None],y[:,:,:,None],z[:,:,:,None]),axis = 3).reshape([np.product(self.grid),3])
    else:
      with h5py.File(self.fname,'r') as f:
        return f['geometry/x_c'][()]


  def add_absolute(self,x):
    """
    Add absolute value.

    Parameters
    ----------
    x : str
      Label of the dataset containing a scalar, vector, or tensor.

    """
    def __add_absolute(x):

      return {
              'data':  np.abs(x['data']),
              'label': '|{}|'.format(x['label']),
              'meta':  {
                        'Unit':        x['meta']['Unit'],
                        'Description': 'Absolute value of {} ({})'.format(x['label'],x['meta']['Description']),
                        'Creator':     'dadf5.py:add_abs v{}'.format(version)
                        }
               }

    requested = [{'label':x,'arg':'x'}]

    self.__add_generic_pointwise(__add_absolute,requested)


  def add_calculation(self,formula,label,unit='n/a',description=None,vectorized=True):
    """
    Add result of a general formula.

    Parameters
    ----------
    formula : str
      Formula, refer to datasets by ‘#Label#‘.
    label : str
      Label of the dataset containing the result of the calculation.
    unit : str, optional
      Physical unit of the result.
    description : str, optional
      Human readable description of the result.
    vectorized : bool, optional
      Indicate whether the formula is written in vectorized form. Default is ‘True’.

    """
    if vectorized is False:
      raise NotImplementedError

    def __add_calculation(**kwargs):

      formula = kwargs['formula']
      for d in re.findall(r'#(.*?)#',formula):
        formula = formula.replace('#{}#'.format(d),"kwargs['{}']['data']".format(d))

      return {
              'data':  eval(formula),
              'label': kwargs['label'],
              'meta':  {
                        'Unit':        kwargs['unit'],
                        'Description': '{} (formula: {})'.format(kwargs['description'],kwargs['formula']),
                        'Creator':     'dadf5.py:add_calculation v{}'.format(version)
                        }
               }

    requested    = [{'label':d,'arg':d} for d in set(re.findall(r'#(.*?)#',formula))]               # datasets used in the formula
    pass_through = {'formula':formula,'label':label,'unit':unit,'description':description}

    self.__add_generic_pointwise(__add_calculation,requested,pass_through)


  def add_Cauchy(self,P='P',F='F'):
    """
    Add Cauchy stress calculated from 1. Piola-Kirchhoff stress and deformation gradient.

    Parameters
    ----------
    P : str, optional
      Label of the dataset containing the 1. Piola-Kirchhoff stress. Default value is ‘P’.
    F : str, optional
      Label of the dataset containing the deformation gradient. Default value is ‘F’.

    """
    def __add_Cauchy(F,P):

      return {
              'data':  mechanics.Cauchy(F['data'],P['data']),
              'label': 'sigma',
              'meta':  {
                        'Unit':        P['meta']['Unit'],
                        'Description': 'Cauchy stress calculated from {} ({}) '.format(P['label'],
                                                                                       P['meta']['Description'])+\
                                       'and deformation gradient {} ({})'.format(F['label'],
                                                                                 F['meta']['Description']),
                        'Creator':     'dadf5.py:add_Cauchy v{}'.format(version)
                        }
              }

    requested = [{'label':F,'arg':'F'},
                 {'label':P,'arg':'P'} ]

    self.__add_generic_pointwise(__add_Cauchy,requested)


  def add_determinant(self,x):
    """
    Add the determinant of a tensor.

    Parameters
    ----------
    x : str
      Label of the dataset containing a tensor.

    """
    def __add_determinant(x):

      return {
              'data':  np.linalg.det(x['data']),
              'label': 'det({})'.format(x['label']),
              'meta':  {
                        'Unit':        x['meta']['Unit'],
                        'Description': 'Determinant of tensor {} ({})'.format(x['label'],x['meta']['Description']),
                        'Creator':     'dadf5.py:add_determinant v{}'.format(version)
                        }
              }

    requested = [{'label':x,'arg':'x'}]

    self.__add_generic_pointwise(__add_determinant,requested)


  def add_deviator(self,x):
    """
    Add the deviatoric part of a tensor.

    Parameters
    ----------
    x : str
      Label of the dataset containing a tensor.

    """
    def __add_deviator(x):

      if not np.all(np.array(x['data'].shape[1:]) == np.array([3,3])):
        raise ValueError

      return {
              'data':  mechanics.deviatoric_part(x['data']),
              'label': 's_{}'.format(x['label']),
              'meta':  {
                        'Unit':        x['meta']['Unit'],
                        'Description': 'Deviator of tensor {} ({})'.format(x['label'],x['meta']['Description']),
                        'Creator':     'dadf5.py:add_deviator v{}'.format(version)
                        }
               }

    requested = [{'label':x,'arg':'x'}]

    self.__add_generic_pointwise(__add_deviator,requested)


  def add_eigenvalues(self,x):
    """
    Add eigenvalues of symmetric tensor.

    Parameters
    ----------
    x : str
      Label of the dataset containing a symmetric tensor.

    """
    def __add_eigenvalue(x):

      return {
              'data': mechanics.eigenvalues(x['data']),
              'label': 'lambda({})'.format(x['label']),
              'meta' : {
                        'Unit':         x['meta']['Unit'],
                        'Description': 'Eigenvalues of {} ({})'.format(x['label'],x['meta']['Description']),
                        'Creator':     'dadf5.py:add_eigenvalues v{}'.format(version)
                       }
              }
    requested = [{'label':x,'arg':'x'}]

    self.__add_generic_pointwise(__add_eigenvalue,requested)


  def add_eigenvectors(self,x):
    """
    Add eigenvectors of symmetric tensor.

    Parameters
    ----------
    x : str
      Label of the dataset containing a symmetric tensor.

    """
    def __add_eigenvector(x):

      return {
              'data': mechanics.eigenvectors(x['data']),
              'label': 'v({})'.format(x['label']),
              'meta' : {
                        'Unit':        '1',
                        'Description': 'Eigenvectors of {} ({})'.format(x['label'],x['meta']['Description']),
                        'Creator':     'dadf5.py:add_eigenvectors v{}'.format(version)
                       }
              }
    requested = [{'label':x,'arg':'x'}]

    self.__add_generic_pointwise(__add_eigenvector,requested)


  def add_IPFcolor(self,q,p):
    """
    Add RGB color tuple of inverse pole figure (IPF) color.

    Parameters
    ----------
    orientation : str
      Label of the dataset containing the orientation data as quaternions.
    pole : list of int
      Pole direction as Miller indices. Default value is [0, 0, 1].

    """
    def __add_IPFcolor(orientation,pole):

      lattice   = orientation['meta']['Lattice']
      unit_pole = pole/np.linalg.norm(pole)
      colors    = np.empty((len(orientation['data']),3),np.uint8)

      for i,q in enumerate(orientation['data']):
         rot = Rotation(np.array([q['w'],q['x'],q['y'],q['z']]))
         orientation = Orientation(rot,lattice = lattice).reduced()
         colors[i]   = np.uint8(orientation.IPFcolor(unit_pole)*255)
      return {
              'data': colors,
              'label': 'IPFcolor_[{} {} {}]'.format(*pole),
              'meta' : {
                        'Unit':        'RGB (8bit)',
                        'Lattice':     lattice,
                        'Description': 'Inverse Pole Figure colors',
                        'Creator':     'dadf5.py:addIPFcolor v{}'.format(version)
                       }
             }

    requested = [{'label':'orientation','arg':'orientation'}]

    self.__add_generic_pointwise(__add_IPFcolor,requested,{'pole':pole})


  def add_maximum_shear(self,x):
    """
    Add maximum shear components of symmetric tensor.

    Parameters
    ----------
    x : str
      Label of the dataset containing a symmetric tensor.

    """
    def __add_maximum_shear(x):

      return {
              'data':  mechanics.maximum_shear(x['data']),
              'label': 'max_shear({})'.format(x['label']),
              'meta':  {
                        'Unit':        x['meta']['Unit'],
                        'Description': 'Maximum shear component of of {} ({})'.format(x['label'],x['meta']['Description']),
                        'Creator':     'dadf5.py:add_maximum_shear v{}'.format(version)
                        }
               }

    requested = [{'label':x,'arg':'x'}]

    self.__add_generic_pointwise(__add_maximum_shear,requested)


  def add_Mises(self,x):
    """
    Add the equivalent Mises stress or strain of a symmetric tensor.

    Parameters
    ----------
    x : str
      Label of the dataset containing a symmetric stress or strain tensor.

    """
    def __add_Mises(x):

      t = 'strain' if x['meta']['Unit'] == '1' else \
          'stress'
      return {
              'data':  mechanics.Mises_strain(x['data']) if t=='strain' else  mechanics.Mises_stress(x['data']),
              'label': '{}_vM'.format(x['label']),
              'meta':  {
                        'Unit':        x['meta']['Unit'],
                        'Description': 'Mises equivalent {} of {} ({})'.format(t,x['label'],x['meta']['Description']),
                        'Creator':     'dadf5.py:add_Mises v{}'.format(version)
                        }
              }

    requested = [{'label':x,'arg':'x'}]

    self.__add_generic_pointwise(__add_Mises,requested)


  def add_norm(self,x,ord=None):
    """
    Add the norm of vector or tensor.

    Parameters
    ----------
    x : str
      Label of the dataset containing a vector or tensor.
    ord : {non-zero int, inf, -inf, ‘fro’, ‘nuc’}, optional
      Order of the norm. inf means numpy’s inf object. For details refer to numpy.linalg.norm.

    """
    def __add_norm(x,ord):

      o = ord
      if len(x['data'].shape) == 2:
        axis = 1
        t = 'vector'
        if o is None: o = 2
      elif len(x['data'].shape) == 3:
        axis = (1,2)
        t = 'tensor'
        if o is None: o = 'fro'
      else:
        raise ValueError

      return {
              'data':  np.linalg.norm(x['data'],ord=o,axis=axis,keepdims=True),
              'label': '|{}|_{}'.format(x['label'],o),
              'meta':  {
                        'Unit':        x['meta']['Unit'],
                        'Description': '{}-Norm of {} {} ({})'.format(ord,t,x['label'],x['meta']['Description']),
                        'Creator':     'dadf5.py:add_norm v{}'.format(version)
                        }
               }

    requested = [{'label':x,'arg':'x'}]

    self.__add_generic_pointwise(__add_norm,requested,{'ord':ord})


  def add_PK2(self,F='F',P='P'):
    """
    Add 2. Piola-Kirchhoff calculated from 1. Piola-Kirchhoff stress and deformation gradient.

    Parameters
    ----------
    P : str, optional
      Label of the dataset containing the 1. Piola-Kirchhoff stress. Default value is ‘P’.
    F : str, optional
      Label of the dataset containing the deformation gradient. Default value is ‘F’.

    """
    def __add_PK2(F,P):

      return {
              'data':  mechanics.PK2(F['data'],P['data']),
              'label': 'S',
              'meta':  {
                        'Unit':        P['meta']['Unit'],
                        'Description': '2. Kirchhoff stress calculated from {} ({}) '.format(P['label'],
                                                                                             P['meta']['Description'])+\
                                       'and deformation gradient {} ({})'.format(F['label'],
                                                                                 F['meta']['Description']),
                        'Creator':     'dadf5.py:add_PK2 v{}'.format(version)
                        }
              }

    requested = [{'label':F,'arg':'F'},
                 {'label':P,'arg':'P'},]

    self.__add_generic_pointwise(__add_PK2,requested)


  def addPole(self,q,p,polar=False):
    """
    Add coordinates of stereographic projection of given direction (pole) in crystal frame.

    Parameters
    ----------
    q : str
      Label of the dataset containing the crystallographic orientation as a quaternion.
    p : numpy.array of shape (3)
      Pole (direction) in crystal frame.
    polar : bool, optional
      Give pole in polar coordinates. Default is false.

    """
    def __addPole(orientation,pole):

      pole       = np.array(pole)
      unit_pole /= np.linalg.norm(pole)
      coords = np.empty((len(orientation['data']),2))

      for i,q in enumerate(orientation['data']):
        o = Rotation(np.array([q['w'],q['x'],q['y'],q['z']]))
        rotatedPole = o*pole                                # rotate pole according to crystal orientation
        (x,y) = rotatedPole[0:2]/(1.+abs(pole[2]))          # stereographic projection

        if polar is True:
          coords[i] = [np.sqrt(x*x+y*y),np.arctan2(y,x)]
        else:
          coords[i] = [x,y]

      return {
              'data': coords,
              'label': 'Pole',
              'meta' : {
                        'Unit': '1',
                        'Description': 'Coordinates of stereographic projection of given direction (pole) in crystal frame',
                        'Creator' : 'dadf5.py:addPole v{}'.format(version)
                       }
             }

    requested = [{'label':'orientation','arg':'orientation'}]

    self.__add_generic_pointwise(__addPole,requested,{'pole':pole})


  def add_principal_components(self,x):
    """
    Add principal components of symmetric tensor.

    The principal components are sorted in descending order, each repeated according to its multiplicity.

    Parameters
    ----------
    x : str
      Label of the dataset containing a symmetric tensor.

    """
    def __add_principal_components(x):

      return {
              'data':  mechanics.principal_components(x['data']),
              'label': 'lambda_{}'.format(x['label']),
              'meta':  {
                        'Unit':        x['meta']['Unit'],
                        'Description': 'Pricipal components of {} ({})'.format(x['label'],x['meta']['Description']),
                        'Creator':     'dadf5.py:add_principal_components v{}'.format(version)
                        }
               }

    requested = [{'label':x,'arg':'x'}]

    self.__add_generic_pointwise(__add_principal_components,requested)


  def add_spherical(self,x):
    """
    Add the spherical (hydrostatic) part of a tensor.

    Parameters
    ----------
    x : str
      Label of the dataset containing a tensor.

    """
    def __add_spherical(x):

      if not np.all(np.array(x['data'].shape[1:]) == np.array([3,3])):
        raise ValueError

      return {
              'data':  mechanics.spherical_part(x['data']),
              'label': 'p_{}'.format(x['label']),
              'meta':  {
                        'Unit':        x['meta']['Unit'],
                        'Description': 'Spherical component of tensor {} ({})'.format(x['label'],x['meta']['Description']),
                        'Creator':     'dadf5.py:add_spherical v{}'.format(version)
                        }
               }

    requested = [{'label':x,'arg':'x'}]

    self.__add_generic_pointwise(__add_spherical,requested)


  def add_strain_tensor(self,F='F',t='U',m=0):
    """
    Add strain tensor calculated from a deformation gradient.

    For details refer to damask.mechanics.strain_tensor

    Parameters
    ----------
    F : str, optional
      Label of the dataset containing the deformation gradient. Default value is ‘F’.
    t : {‘V’, ‘U’}, optional
      Type of the polar decomposition, ‘V’ for right stretch tensor and ‘U’ for left stretch tensor.
      Defaults value is ‘U’.
    m : float, optional
      Order of the strain calculation. Default value is ‘0.0’.

    """
    def __add_strain_tensor(F,t,m):

      return {
              'data':  mechanics.strain_tensor(F['data'],t,m),
              'label': 'epsilon_{}^{}({})'.format(t,m,F['label']),
              'meta':  {
                        'Unit':        F['meta']['Unit'],
                        'Description': 'Strain tensor of {} ({})'.format(F['label'],F['meta']['Description']),
                        'Creator':     'dadf5.py:add_strain_tensor v{}'.format(version)
                        }
               }

    requested = [{'label':F,'arg':'F'}]

    self.__add_generic_pointwise(__add_strain_tensor,requested,{'t':t,'m':m})


  def __add_generic_pointwise(self,func,datasets_requested,extra_args={}):
    """
    General function to add pointwise data.

    Parameters
    ----------
    func : function
      Function that calculates a new dataset from one or more datasets per HDF5 group.
    datasets_requested : list of dictionaries
      Details of the datasets to be used: label (in HDF5 file) and arg (argument to which the data is parsed in func).
    extra_args : dictionary, optional
      Any extra arguments parsed to func.

    """
    def job(args):
      """Call function with input data + extra arguments, returns results + group."""
      args['results'].put({**args['func'](**args['in']),'group':args['group']})


    N_threads = 1 # ToDo: should be a parameter

    results = Queue(N_threads)
    pool    = util.ThreadPool(N_threads)
    N_added = N_threads + 1

    todo = []
    # ToDo: It would be more memory efficient to read only from file when required, i.e. do to it in pool.add_task
    for group in self.groups_with_datasets([d['label'] for d in datasets_requested]):
      with h5py.File(self.fname,'r') as f:
        datasets_in = {}
        for d in datasets_requested:
          loc  = f[group+'/'+d['label']]
          data = loc[()]
          meta = {k:loc.attrs[k].decode() for k in loc.attrs.keys()}
          datasets_in[d['arg']] = {'data': data, 'meta' : meta, 'label' : d['label']}

      todo.append({'in':{**datasets_in,**extra_args},'func':func,'group':group,'results':results})

    pool.map(job, todo[:N_added])                                                                   # initialize

    N_not_calculated = len(todo)
    while N_not_calculated > 0:
      result = results.get()
      with h5py.File(self.fname,'a') as f:                                                          # write to file
        dataset_out = f[result['group']].create_dataset(result['label'],data=result['data'])
        for k in result['meta'].keys():
          dataset_out.attrs[k] = result['meta'][k].encode()
        N_not_calculated-=1

      if N_added < len(todo):                                                                       # add more jobs
        pool.add_task(job,todo[N_added])
        N_added +=1

    pool.wait_completion()


  def to_vtk(self,labels,mode='Cell'):
    """
    Export to vtk cell/point data.

    Parameters
    ----------
    labels : str or list of
      Labels of the datasets to be exported.
    mode : str, either 'Cell' or 'Point'
      Export in cell format or point format.
      Default value is 'Cell'.

    """
    if mode=='Cell':

      if self.structured:

        coordArray = [vtk.vtkDoubleArray(),vtk.vtkDoubleArray(),vtk.vtkDoubleArray()]
        for dim in [0,1,2]:
          for c in np.linspace(0,self.size[dim],1+self.grid[dim]):
            coordArray[dim].InsertNextValue(c)

        vtk_geom = vtk.vtkRectilinearGrid()
        vtk_geom.SetDimensions(*(self.grid+1))
        vtk_geom.SetXCoordinates(coordArray[0])
        vtk_geom.SetYCoordinates(coordArray[1])
        vtk_geom.SetZCoordinates(coordArray[2])

      else:

        nodes = vtk.vtkPoints()
        with h5py.File(self.fname,'r') as f:
          nodes.SetData(numpy_support.numpy_to_vtk(f['/geometry/x_n'][()],deep=True))

          vtk_geom = vtk.vtkUnstructuredGrid()
          vtk_geom.SetPoints(nodes)
          vtk_geom.Allocate(f['/geometry/T_c'].shape[0])

          if self.version_major == 0 and self.version_minor <= 5:
            vtk_type = vtk.VTK_HEXAHEDRON
            n_nodes = 8
          else:
            if   f['/geometry/T_c'].attrs['VTK_TYPE'] == b'TRIANGLE':
              vtk_type = vtk.VTK_TRIANGLE
              n_nodes = 3
            elif f['/geometry/T_c'].attrs['VTK_TYPE'] == b'QUAD':
              vtk_type = vtk.VTK_QUAD
              n_nodes = 4
            elif f['/geometry/T_c'].attrs['VTK_TYPE'] == b'TETRA':                                  # not tested
              vtk_type = vtk.VTK_TETRA
              n_nodes = 4
            elif f['/geometry/T_c'].attrs['VTK_TYPE'] == b'HEXAHEDRON':
              vtk_type = vtk.VTK_HEXAHEDRON
              n_nodes = 8

          for i in f['/geometry/T_c']:
            vtk_geom.InsertNextCell(vtk_type,n_nodes,i-1)

    elif mode == 'Point':
      Points   = vtk.vtkPoints()
      Vertices = vtk.vtkCellArray()
      for c in self.cell_coordinates():
        pointID = Points.InsertNextPoint(c)
        Vertices.InsertNextCell(1)
        Vertices.InsertCellPoint(pointID)

      vtk_geom = vtk.vtkPolyData()
      vtk_geom.SetPoints(Points)
      vtk_geom.SetVerts(Vertices)
      vtk_geom.Modified()

    N_digits = int(np.floor(np.log10(int(self.increments[-1][3:]))))+1

    for i,inc in enumerate(self.iter_visible('increments')):
      vtk_data = []

      materialpoints_backup = self.visible['materialpoints'].copy()
      self.set_visible('materialpoints',False)
      for label in (labels if isinstance(labels,list) else [labels]):
        for p in self.iter_visible('con_physics'):
          if p != 'generic':
            for c in self.iter_visible('constituents'):
              x = self.get_dataset_location(label)
              if len(x) == 0:
                continue
              array = self.read_dataset(x,0)
              shape = [array.shape[0],np.product(array.shape[1:])]
              vtk_data.append(numpy_support.numpy_to_vtk(num_array=array.reshape(shape),
                              deep=True,array_type= vtk.VTK_DOUBLE))
              vtk_data[-1].SetName('1_'+x[0].split('/',1)[1]) #ToDo: hard coded 1!
              vtk_geom.GetCellData().AddArray(vtk_data[-1])

          else:
            x = self.get_dataset_location(label)
            if len(x) == 0:
              continue
            array = self.read_dataset(x,0)
            shape = [array.shape[0],np.product(array.shape[1:])]
            vtk_data.append(numpy_support.numpy_to_vtk(num_array=array.reshape(shape),
                            deep=True,array_type= vtk.VTK_DOUBLE))
            ph_name = re.compile(r'(?<=(constituent\/))(.*?)(?=(generic))')                         # identify  phase name
            dset_name = '1_' + re.sub(ph_name,r'',x[0].split('/',1)[1])                             # removing phase name
            vtk_data[-1].SetName(dset_name)
            vtk_geom.GetCellData().AddArray(vtk_data[-1])

      self.set_visible('materialpoints',materialpoints_backup)

      constituents_backup = self.visible['constituents'].copy()
      self.set_visible('constituents',False)
      for label in (labels if isinstance(labels,list) else [labels]):
        for p in self.iter_visible('mat_physics'):
          if p != 'generic':
            for m in self.iter_visible('materialpoints'):
              x = self.get_dataset_location(label)
              if len(x) == 0:
                continue
              array = self.read_dataset(x,0)
              shape = [array.shape[0],np.product(array.shape[1:])]
              vtk_data.append(numpy_support.numpy_to_vtk(num_array=array.reshape(shape),
                              deep=True,array_type= vtk.VTK_DOUBLE))
              vtk_data[-1].SetName('1_'+x[0].split('/',1)[1]) #ToDo: why 1_?
              vtk_geom.GetCellData().AddArray(vtk_data[-1])
          else:
            x = self.get_dataset_location(label)
            if len(x) == 0:
              continue
            array = self.read_dataset(x,0)
            shape = [array.shape[0],np.product(array.shape[1:])]
            vtk_data.append(numpy_support.numpy_to_vtk(num_array=array.reshape(shape),
                            deep=True,array_type= vtk.VTK_DOUBLE))
            vtk_data[-1].SetName('1_'+x[0].split('/',1)[1])
            vtk_geom.GetCellData().AddArray(vtk_data[-1])
      self.set_visible('constituents',constituents_backup)

      if mode=='Cell':
        writer = vtk.vtkXMLRectilinearGridWriter() if self.structured else \
                 vtk.vtkXMLUnstructuredGridWriter()
        x = self.get_dataset_location('u_n')
        vtk_data.append(numpy_support.numpy_to_vtk(num_array=self.read_dataset(x,0),
                        deep=True,array_type=vtk.VTK_DOUBLE))
        vtk_data[-1].SetName('u')
        vtk_geom.GetPointData().AddArray(vtk_data[-1])
      elif mode == 'Point':
        writer = vtk.vtkXMLPolyDataWriter()


      file_out = '{}_inc{}.{}'.format(os.path.splitext(os.path.basename(self.fname))[0],
                                      inc[3:].zfill(N_digits),
                                      writer.GetDefaultFileExtension())

      writer.SetCompressorTypeToZLib()
      writer.SetDataModeToBinary()
      writer.SetFileName(file_out)
      writer.SetInputData(vtk_geom)

      writer.Write()
