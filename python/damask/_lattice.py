import numpy as np

from . import util
from . import LatticeFamily

lattice_symmetries = {
                'aP': 'triclinic',

                'mP': 'monoclinic',
                'mS': 'monoclinic',

                'oP': 'orthorhombic',
                'oS': 'orthorhombic',
                'oI': 'orthorhombic',
                'oF': 'orthorhombic',

                'tP': 'tetragonal',
                'tI': 'tetragonal',

                'hP': 'hexagonal',

                'cP': 'cubic',
                'cI': 'cubic',
                'cF': 'cubic',
               }


class Lattice(LatticeFamily):
    """Lattice."""

    def __init__(self,
                 lattice = None,
                 a = None,b = None,c = None,
                 alpha = None,beta = None,gamma = None,
                 degrees = False):
        """
        Lattice.

        Parameters
        ----------
        lattice : {'aP', 'mP', 'mS', 'oP', 'oS', 'oI', 'oF', 'tP', 'tI', 'hP', 'cP', 'cI', 'cF'}.
            Name of the Bravais lattice in Pearson notation.
        a : float, optional
            Length of lattice parameter 'a'.
        b : float, optional
            Length of lattice parameter 'b'.
        c : float, optional
            Length of lattice parameter 'c'.
        alpha : float, optional
            Angle between b and c lattice basis.
        beta : float, optional
            Angle between c and a lattice basis.
        gamma : float, optional
            Angle between a and b lattice basis.
        degrees : bool, optional
            Angles are given in degrees. Defaults to False.

        """
        super().__init__(lattice_symmetries[lattice])
        self.lattice = lattice


        self.a = 1 if a is None else a
        self.b = b
        self.c = c
        self.a = float(self.a) if self.a is not None else \
                 (self.b / self.ratio['b'] if self.b is not None and self.ratio['b'] is not None else
                  self.c / self.ratio['c'] if self.c is not None and self.ratio['c'] is not None else None)
        self.b = float(self.b) if self.b is not None else \
                 (self.a * self.ratio['b'] if self.a is not None and self.ratio['b'] is not None else
                  self.c / self.ratio['c'] * self.ratio['b']
                  if self.c is not None and self.ratio['b'] is not None and self.ratio['c'] is not None else None)
        self.c = float(self.c) if self.c is not None else \
                 (self.a * self.ratio['c'] if self.a is not None and self.ratio['c'] is not None else
                  self.b / self.ratio['b'] * self.ratio['c']
                  if self.c is not None and self.ratio['b'] is not None and self.ratio['c'] is not None else None)

        self.alpha = np.radians(alpha) if degrees and alpha is not None else alpha
        self.beta  = np.radians(beta)  if degrees and beta  is not None else beta
        self.gamma = np.radians(gamma) if degrees and gamma is not None else gamma
        if self.alpha is None and 'alpha' in self.immutable: self.alpha = self.immutable['alpha']
        if self.beta  is None and 'beta'  in self.immutable: self.beta  = self.immutable['beta']
        if self.gamma is None and 'gamma' in self.immutable: self.gamma = self.immutable['gamma']

        if \
            (self.a     is None) \
         or (self.b     is None or ('b'     in self.immutable and self.b     != self.immutable['b'] * self.a)) \
         or (self.c     is None or ('c'     in self.immutable and self.c     != self.immutable['c'] * self.b)) \
         or (self.alpha is None or ('alpha' in self.immutable and self.alpha != self.immutable['alpha'])) \
         or (self.beta  is None or ( 'beta' in self.immutable and self.beta  != self.immutable['beta'])) \
         or (self.gamma is None or ('gamma' in self.immutable and self.gamma != self.immutable['gamma'])):
            raise ValueError (f'Incompatible parameters {self.parameters} for crystal family {self.family}')

        if np.any(np.array([self.alpha,self.beta,self.gamma]) <= 0):
            raise ValueError ('Lattice angles must be positive')
        if np.any([np.roll([self.alpha,self.beta,self.gamma],r)[0]
          > np.sum(np.roll([self.alpha,self.beta,self.gamma],r)[1:]) for r in range(3)]):
            raise ValueError ('Each lattice angle must be less than sum of others')


    @property
    def parameters(self):
        """Return lattice parameters a, b, c, alpha, beta, gamma."""
        return (self.a,self.b,self.c,self.alpha,self.beta,self.gamma)


    @property
    def ratio(self):
        """Return axes ratios of own lattice."""
        _ratio = { 'hexagonal': {'c': np.sqrt(8./3.)}}

        return dict(b = self.immutable['b']
                        if 'b' in self.immutable else
                        _ratio[self.family]['b'] if self.family in _ratio and 'b' in _ratio[self.family] else None,
                    c = self.immutable['c']
                        if 'c' in self.immutable else
                        _ratio[self.family]['c'] if self.family in _ratio and 'c' in _ratio[self.family] else None,
                   )


    @property
    def basis_real(self):
        """
        Calculate orthogonal real space crystal basis.

        References
        ----------
        C.T. Young and J.L. Lytton, Journal of Applied Physics 43:1408–1417, 1972
        https://doi.org/10.1063/1.1661333

        """
        if None in self.parameters:
            raise KeyError('missing crystal lattice parameters')
        return np.array([
                          [1,0,0],
                          [np.cos(self.gamma),np.sin(self.gamma),0],
                          [np.cos(self.beta),
                           (np.cos(self.alpha)-np.cos(self.beta)*np.cos(self.gamma))                     /np.sin(self.gamma),
                           np.sqrt(1 - np.cos(self.alpha)**2 - np.cos(self.beta)**2 - np.cos(self.gamma)**2
                                 + 2 * np.cos(self.alpha)    * np.cos(self.beta)    * np.cos(self.gamma))/np.sin(self.gamma)],
                         ],dtype=float).T \
             * np.array([self.a,self.b,self.c])


    @property
    def basis_reciprocal(self):
        """Calculate reciprocal (dual) crystal basis."""
        return np.linalg.inv(self.basis_real.T)


    def to_lattice(self,*,direction=None,plane=None):
        """
        Calculate lattice vector corresponding to crystal frame direction or plane normal.

        Parameters
        ----------
        direction|normal : numpy.ndarray of shape (...,3)
            Vector along direction or plane normal.

        Returns
        -------
        Miller : numpy.ndarray of shape (...,3)
            lattice vector of direction or plane.
            Use util.scale_to_coprime to convert to (integer) Miller indices.

        """
        if (direction is not None) ^ (plane is None):
            raise KeyError('Specify either "direction" or "plane"')
        axis,basis  = (np.array(direction),self.basis_reciprocal.T) \
                      if plane is None else \
                      (np.array(plane),self.basis_real.T)
        return np.einsum('il,...l',basis,axis)


    def to_frame(self,*,uvw=None,hkl=None):
        """
        Calculate crystal frame vector along lattice direction [uvw] or plane normal (hkl).

        Parameters
        ----------
        uvw|hkl : numpy.ndarray of shape (...,3)
            Miller indices of crystallographic direction or plane normal.

        Returns
        -------
        vector : numpy.ndarray of shape (...,3) or (N,...,3)
            Crystal frame vector (or vectors if with_symmetry) along [uvw] direction or (hkl) plane normal.

        """
        if (uvw is not None) ^ (hkl is None):
            raise KeyError('Specify either "uvw" or "hkl"')
        axis,basis  = (np.array(uvw),self.basis_real) \
                      if hkl is None else \
                      (np.array(hkl),self.basis_reciprocal)
        return np.einsum('il,...l',basis,axis)


    def kinematics(self,mode):
        master = self._kinematics[self.lattice][mode]
        if self.lattice == 'hP':
            return {'direction':util.Bravais_to_Miller(uvtw=master[:,0:4]),
                    'plane':    util.Bravais_to_Miller(hkil=master[:,4:8])}
        else:
            return {'direction':master[:,0:3],
                    'plane':    master[:,3:6]}


    @property
    def orientation_relationships(self):
        return {k:v for k,v in self._orientation_relationships.items() if self.lattice in v}


    _kinematics = {
        'cF': {
            'slip' : np.array([
                    [+0,+1,-1, +1,+1,+1],
                    [-1,+0,+1, +1,+1,+1],
                    [+1,-1,+0, +1,+1,+1],
                    [+0,-1,-1, -1,-1,+1],
                    [+1,+0,+1, -1,-1,+1],
                    [-1,+1,+0, -1,-1,+1],
                    [+0,-1,+1, +1,-1,-1],
                    [-1,+0,-1, +1,-1,-1],
                    [+1,+1,+0, +1,-1,-1],
                    [+0,+1,+1, -1,+1,-1],
                    [+1,+0,-1, -1,+1,-1],
                    [-1,-1,+0, -1,+1,-1],
                    [+1,+1,+0, +1,-1,+0],
                    [+1,-1,+0, +1,+1,+0],
                    [+1,+0,+1, +1,+0,-1],
                    [+1,+0,-1, +1,+0,+1],
                    [+0,+1,+1, +0,+1,-1],
                    [+0,+1,-1, +0,+1,+1],
                   ],'d'),
            'twin' : np.array([
                    [-2, 1, 1,  1, 1, 1],
                    [ 1,-2, 1,  1, 1, 1],
                    [ 1, 1,-2,  1, 1, 1],
                    [ 2,-1, 1, -1,-1, 1],
                    [-1, 2, 1, -1,-1, 1],
                    [-1,-1,-2, -1,-1, 1],
                    [-2,-1,-1,  1,-1,-1],
                    [ 1, 2,-1,  1,-1,-1],
                    [ 1,-1, 2,  1,-1,-1],
                    [ 2, 1,-1, -1, 1,-1],
                    [-1,-2,-1, -1, 1,-1],
                    [-1, 1, 2, -1, 1,-1],
                    ],dtype=float),
        },
        'cI': {
            'slip' : np.array([
                    [+1,-1,+1, +0,+1,+1],
                    [-1,-1,+1, +0,+1,+1],
                    [+1,+1,+1, +0,-1,+1],
                    [-1,+1,+1, +0,-1,+1],
                    [-1,+1,+1, +1,+0,+1],
                    [-1,-1,+1, +1,+0,+1],
                    [+1,+1,+1, -1,+0,+1],
                    [+1,-1,+1, -1,+0,+1],
                    [-1,+1,+1, +1,+1,+0],
                    [-1,+1,-1, +1,+1,+0],
                    [+1,+1,+1, -1,+1,+0],
                    [+1,+1,-1, -1,+1,+0],
                    [-1,+1,+1, +2,+1,+1],
                    [+1,+1,+1, -2,+1,+1],
                    [+1,+1,-1, +2,-1,+1],
                    [+1,-1,+1, +2,+1,-1],
                    [+1,-1,+1, +1,+2,+1],
                    [+1,+1,-1, -1,+2,+1],
                    [+1,+1,+1, +1,-2,+1],
                    [-1,+1,+1, +1,+2,-1],
                    [+1,+1,-1, +1,+1,+2],
                    [+1,-1,+1, -1,+1,+2],
                    [-1,+1,+1, +1,-1,+2],
                    [+1,+1,+1, +1,+1,-2],
                    [+1,+1,-1, +1,+2,+3],
                    [+1,-1,+1, -1,+2,+3],
                    [-1,+1,+1, +1,-2,+3],
                    [+1,+1,+1, +1,+2,-3],
                    [+1,-1,+1, +1,+3,+2],
                    [+1,+1,-1, -1,+3,+2],
                    [+1,+1,+1, +1,-3,+2],
                    [-1,+1,+1, +1,+3,-2],
                    [+1,+1,-1, +2,+1,+3],
                    [+1,-1,+1, -2,+1,+3],
                    [-1,+1,+1, +2,-1,+3],
                    [+1,+1,+1, +2,+1,-3],
                    [+1,-1,+1, +2,+3,+1],
                    [+1,+1,-1, -2,+3,+1],
                    [+1,+1,+1, +2,-3,+1],
                    [-1,+1,+1, +2,+3,-1],
                    [-1,+1,+1, +3,+1,+2],
                    [+1,+1,+1, -3,+1,+2],
                    [+1,+1,-1, +3,-1,+2],
                    [+1,-1,+1, +3,+1,-2],
                    [-1,+1,+1, +3,+2,+1],
                    [+1,+1,+1, -3,+2,+1],
                    [+1,+1,-1, +3,-2,+1],
                    [+1,-1,+1, +3,+2,-1],
                   ],'d'),
            'twin' : np.array([
                    [-1, 1, 1,  2, 1, 1],
                    [ 1, 1, 1, -2, 1, 1],
                    [ 1, 1,-1,  2,-1, 1],
                    [ 1,-1, 1,  2, 1,-1],
                    [ 1,-1, 1,  1, 2, 1],
                    [ 1, 1,-1, -1, 2, 1],
                    [ 1, 1, 1,  1,-2, 1],
                    [-1, 1, 1,  1, 2,-1],
                    [ 1, 1,-1,  1, 1, 2],
                    [ 1,-1, 1, -1, 1, 2],
                    [-1, 1, 1,  1,-1, 2],
                    [ 1, 1, 1,  1, 1,-2],
                    ],dtype=float),
        },
        'hP': {
            'slip' : np.array([
                    [+2,-1,-1,+0, +0,+0,+0,+1],
                    [-1,+2,-1,+0, +0,+0,+0,+1],
                    [-1,-1,+2,+0, +0,+0,+0,+1],
                    [+2,-1,-1,+0, +0,+1,-1,+0],
                    [-1,+2,-1,+0, -1,+0,+1,+0],
                    [-1,-1,+2,+0, +1,-1,+0,+0],
                    [-1,+1,+0,+0, +1,+1,-2,+0],
                    [+0,-1,+1,+0, -2,+1,+1,+0],
                    [+1,+0,-1,+0, +1,-2,+1,+0],
                    [-1,+2,-1,+0, +1,+0,-1,+1],
                    [-2,+1,+1,+0, +0,+1,-1,+1],
                    [-1,-1,+2,+0, -1,+1,+0,+1],
                    [+1,-2,+1,+0, -1,+0,+1,+1],
                    [+2,-1,-1,+0, +0,-1,+1,+1],
                    [+1,+1,-2,+0, +1,-1,+0,+1],
                    [-2,+1,+1,+3, +1,+0,-1,+1],
                    [-1,-1,+2,+3, +1,+0,-1,+1],
                    [-1,-1,+2,+3, +0,+1,-1,+1],
                    [+1,-2,+1,+3, +0,+1,-1,+1],
                    [+1,-2,+1,+3, -1,+1,+0,+1],
                    [+2,-1,-1,+3, -1,+1,+0,+1],
                    [+2,-1,-1,+3, -1,+0,+1,+1],
                    [+1,+1,-2,+3, -1,+0,+1,+1],
                    [+1,+1,-2,+3, +0,-1,+1,+1],
                    [-1,+2,-1,+3, +0,-1,+1,+1],
                    [-1,+2,-1,+3, +1,-1,+0,+1],
                    [-2,+1,+1,+3, +1,-1,+0,+1],
                    [-1,-1,+2,+3, +1,+1,-2,+2],
                    [+1,-2,+1,+3, -1,+2,-1,+2],
                    [+2,-1,-1,+3, -2,+1,+1,+2],
                    [+1,+1,-2,+3, -1,-1,+2,+2],
                    [-1,+2,-1,+3, +1,-2,+1,+2],
                    [-2,+1,+1,+3, +2,-1,-1,+2],
                   ],'d'),
            'twin' : np.array([
                    [-1, 0, 1, 1,  1, 0,-1, 2],   # shear = (3-(c/a)^2)/(sqrt(3) c/a) <-10.1>{10.2}
                    [ 0,-1, 1, 1,  0, 1,-1, 2],
                    [ 1,-1, 0, 1, -1, 1, 0, 2],
                    [ 1, 0,-1, 1, -1, 0, 1, 2],
                    [ 0, 1,-1, 1,  0,-1, 1, 2],
                    [-1, 1, 0, 1,  1,-1, 0, 2],
                    [-1,-1, 2, 6,  1, 1,-2, 1],   # shear = 1/(c/a) <11.6>{-1-1.1}
                    [ 1,-2, 1, 6, -1, 2,-1, 1],
                    [ 2,-1,-1, 6, -2, 1, 1, 1],
                    [ 1, 1,-2, 6, -1,-1, 2, 1],
                    [-1, 2,-1, 6,  1,-2, 1, 1],
                    [-2, 1, 1, 6,  2,-1,-1, 1],
                    [ 1, 0,-1,-2,  1, 0,-1, 1],   # shear = (4(c/a)^2-9)/(4 sqrt(3) c/a)  <10.-2>{10.1}
                    [ 0, 1,-1,-2,  0, 1,-1, 1],
                    [-1, 1, 0,-2, -1, 1, 0, 1],
                    [-1, 0, 1,-2, -1, 0, 1, 1],
                    [ 0,-1, 1,-2,  0,-1, 1, 1],
                    [ 1,-1, 0,-2,  1,-1, 0, 1],
                    [ 1, 1,-2,-3,  1, 1,-2, 2],   # shear = 2((c/a)^2-2)/(3 c/a)  <11.-3>{11.2}
                    [-1, 2,-1,-3, -1, 2,-1, 2],
                    [-2, 1, 1,-3, -2, 1, 1, 2],
                    [-1,-1, 2,-3, -1,-1, 2, 2],
                    [ 1,-2, 1,-3,  1,-2, 1, 2],
                    [ 2,-1,-1,-3,  2,-1,-1, 2],
                    ],dtype=float),
            },
    }


    _orientation_relationships = {
      'KS': {
        'cF' : np.array([
            [[-1, 0, 1],[ 1, 1, 1]],
            [[-1, 0, 1],[ 1, 1, 1]],
            [[ 0, 1,-1],[ 1, 1, 1]],
            [[ 0, 1,-1],[ 1, 1, 1]],
            [[ 1,-1, 0],[ 1, 1, 1]],
            [[ 1,-1, 0],[ 1, 1, 1]],
            [[ 1, 0,-1],[ 1,-1, 1]],
            [[ 1, 0,-1],[ 1,-1, 1]],
            [[-1,-1, 0],[ 1,-1, 1]],
            [[-1,-1, 0],[ 1,-1, 1]],
            [[ 0, 1, 1],[ 1,-1, 1]],
            [[ 0, 1, 1],[ 1,-1, 1]],
            [[ 0,-1, 1],[-1, 1, 1]],
            [[ 0,-1, 1],[-1, 1, 1]],
            [[-1, 0,-1],[-1, 1, 1]],
            [[-1, 0,-1],[-1, 1, 1]],
            [[ 1, 1, 0],[-1, 1, 1]],
            [[ 1, 1, 0],[-1, 1, 1]],
            [[-1, 1, 0],[ 1, 1,-1]],
            [[-1, 1, 0],[ 1, 1,-1]],
            [[ 0,-1,-1],[ 1, 1,-1]],
            [[ 0,-1,-1],[ 1, 1,-1]],
            [[ 1, 0, 1],[ 1, 1,-1]],
            [[ 1, 0, 1],[ 1, 1,-1]],
            ],dtype=float),
        'cI' : np.array([
            [[-1,-1, 1],[ 0, 1, 1]],
            [[-1, 1,-1],[ 0, 1, 1]],
            [[-1,-1, 1],[ 0, 1, 1]],
            [[-1, 1,-1],[ 0, 1, 1]],
            [[-1,-1, 1],[ 0, 1, 1]],
            [[-1, 1,-1],[ 0, 1, 1]],
            [[-1,-1, 1],[ 0, 1, 1]],
            [[-1, 1,-1],[ 0, 1, 1]],
            [[-1,-1, 1],[ 0, 1, 1]],
            [[-1, 1,-1],[ 0, 1, 1]],
            [[-1,-1, 1],[ 0, 1, 1]],
            [[-1, 1,-1],[ 0, 1, 1]],
            [[-1,-1, 1],[ 0, 1, 1]],
            [[-1, 1,-1],[ 0, 1, 1]],
            [[-1,-1, 1],[ 0, 1, 1]],
            [[-1, 1,-1],[ 0, 1, 1]],
            [[-1,-1, 1],[ 0, 1, 1]],
            [[-1, 1,-1],[ 0, 1, 1]],
            [[-1,-1, 1],[ 0, 1, 1]],
            [[-1, 1,-1],[ 0, 1, 1]],
            [[-1,-1, 1],[ 0, 1, 1]],
            [[-1, 1,-1],[ 0, 1, 1]],
            [[-1,-1, 1],[ 0, 1, 1]],
            [[-1, 1,-1],[ 0, 1, 1]],
            ],dtype=float),
      },
      'GT': {
        'cF' : np.array([
            [[ -5,-12, 17],[  1,  1,  1]],
            [[ 17, -5,-12],[  1,  1,  1]],
            [[-12, 17, -5],[  1,  1,  1]],
            [[  5, 12, 17],[ -1, -1,  1]],
            [[-17,  5,-12],[ -1, -1,  1]],
            [[ 12,-17, -5],[ -1, -1,  1]],
            [[ -5, 12,-17],[ -1,  1,  1]],
            [[ 17,  5, 12],[ -1,  1,  1]],
            [[-12,-17,  5],[ -1,  1,  1]],
            [[  5,-12,-17],[  1, -1,  1]],
            [[-17, -5, 12],[  1, -1,  1]],
            [[ 12, 17,  5],[  1, -1,  1]],
            [[ -5, 17,-12],[  1,  1,  1]],
            [[-12, -5, 17],[  1,  1,  1]],
            [[ 17,-12, -5],[  1,  1,  1]],
            [[  5,-17,-12],[ -1, -1,  1]],
            [[ 12,  5, 17],[ -1, -1,  1]],
            [[-17, 12, -5],[ -1, -1,  1]],
            [[ -5,-17, 12],[ -1,  1,  1]],
            [[-12,  5,-17],[ -1,  1,  1]],
            [[ 17, 12,  5],[ -1,  1,  1]],
            [[  5, 17, 12],[  1, -1,  1]],
            [[ 12, -5,-17],[  1, -1,  1]],
            [[-17,-12,  5],[  1, -1,  1]],
            ],dtype=float),
        'cI' : np.array([
            [[-17, -7, 17],[  1,  0,  1]],
            [[ 17,-17, -7],[  1,  1,  0]],
            [[ -7, 17,-17],[  0,  1,  1]],
            [[ 17,  7, 17],[ -1,  0,  1]],
            [[-17, 17, -7],[ -1, -1,  0]],
            [[  7,-17,-17],[  0, -1,  1]],
            [[-17,  7,-17],[ -1,  0,  1]],
            [[ 17, 17,  7],[ -1,  1,  0]],
            [[ -7,-17, 17],[  0,  1,  1]],
            [[ 17, -7,-17],[  1,  0,  1]],
            [[-17,-17,  7],[  1, -1,  0]],
            [[  7, 17, 17],[  0, -1,  1]],
            [[-17, 17, -7],[  1,  1,  0]],
            [[ -7,-17, 17],[  0,  1,  1]],
            [[ 17, -7,-17],[  1,  0,  1]],
            [[ 17,-17, -7],[ -1, -1,  0]],
            [[  7, 17, 17],[  0, -1,  1]],
            [[-17,  7,-17],[ -1,  0,  1]],
            [[-17,-17,  7],[ -1,  1,  0]],
            [[ -7, 17,-17],[  0,  1,  1]],
            [[ 17,  7, 17],[ -1,  0,  1]],
            [[ 17, 17,  7],[  1, -1,  0]],
            [[  7,-17,-17],[  0, -1,  1]],
            [[-17, -7, 17],[  1,  0,  1]],
            ],dtype=float),
      },
      'GT_prime': {
        'cF' : np.array([
            [[  0,  1, -1],[  7, 17, 17]],
            [[ -1,  0,  1],[ 17,  7, 17]],
            [[  1, -1,  0],[ 17, 17,  7]],
            [[  0, -1, -1],[ -7,-17, 17]],
            [[  1,  0,  1],[-17, -7, 17]],
            [[  1, -1,  0],[-17,-17,  7]],
            [[  0,  1, -1],[  7,-17,-17]],
            [[  1,  0,  1],[ 17, -7,-17]],
            [[ -1, -1,  0],[ 17,-17, -7]],
            [[  0, -1, -1],[ -7, 17,-17]],
            [[ -1,  0,  1],[-17,  7,-17]],
            [[ -1, -1,  0],[-17, 17, -7]],
            [[  0, -1,  1],[  7, 17, 17]],
            [[  1,  0, -1],[ 17,  7, 17]],
            [[ -1,  1,  0],[ 17, 17,  7]],
            [[  0,  1,  1],[ -7,-17, 17]],
            [[ -1,  0, -1],[-17, -7, 17]],
            [[ -1,  1,  0],[-17,-17,  7]],
            [[  0, -1,  1],[  7,-17,-17]],
            [[ -1,  0, -1],[ 17, -7,-17]],
            [[  1,  1,  0],[ 17,-17, -7]],
            [[  0,  1,  1],[ -7, 17,-17]],
            [[  1,  0, -1],[-17,  7,-17]],
            [[  1,  1,  0],[-17, 17, -7]],
            ],dtype=float),
        'cI' : np.array([
            [[  1,  1, -1],[ 12,  5, 17]],
            [[ -1,  1,  1],[ 17, 12,  5]],
            [[  1, -1,  1],[  5, 17, 12]],
            [[ -1, -1, -1],[-12, -5, 17]],
            [[  1, -1,  1],[-17,-12,  5]],
            [[  1, -1, -1],[ -5,-17, 12]],
            [[ -1,  1, -1],[ 12, -5,-17]],
            [[  1,  1,  1],[ 17,-12, -5]],
            [[ -1, -1,  1],[  5,-17,-12]],
            [[  1, -1, -1],[-12,  5,-17]],
            [[ -1, -1,  1],[-17, 12, -5]],
            [[ -1, -1, -1],[ -5, 17,-12]],
            [[  1, -1,  1],[ 12, 17,  5]],
            [[  1,  1, -1],[  5, 12, 17]],
            [[ -1,  1,  1],[ 17,  5, 12]],
            [[ -1,  1,  1],[-12,-17,  5]],
            [[ -1, -1, -1],[ -5,-12, 17]],
            [[ -1,  1, -1],[-17, -5, 12]],
            [[ -1, -1,  1],[ 12,-17, -5]],
            [[ -1,  1, -1],[  5,-12,-17]],
            [[  1,  1,  1],[ 17, -5,-12]],
            [[  1,  1,  1],[-12, 17, -5]],
            [[  1, -1, -1],[ -5, 12,-17]],
            [[  1,  1, -1],[-17,  5,-12]],
            ],dtype=float),
      },
      'NW': {
        'cF' : np.array([
            [[  2, -1, -1],[  1,  1,  1]],
            [[ -1,  2, -1],[  1,  1,  1]],
            [[ -1, -1,  2],[  1,  1,  1]],
            [[ -2, -1, -1],[ -1,  1,  1]],
            [[  1,  2, -1],[ -1,  1,  1]],
            [[  1, -1,  2],[ -1,  1,  1]],
            [[  2,  1, -1],[  1, -1,  1]],
            [[ -1, -2, -1],[  1, -1,  1]],
            [[ -1,  1,  2],[  1, -1,  1]],
            [[  2, -1,  1],[ -1, -1,  1]],
            [[ -1,  2,  1],[ -1, -1,  1]],
            [[ -1, -1, -2],[ -1, -1,  1]],
            ],dtype=float),
        'cI' : np.array([
            [[  0, -1,  1],[  0,  1,  1]],
            [[  0, -1,  1],[  0,  1,  1]],
            [[  0, -1,  1],[  0,  1,  1]],
            [[  0, -1,  1],[  0,  1,  1]],
            [[  0, -1,  1],[  0,  1,  1]],
            [[  0, -1,  1],[  0,  1,  1]],
            [[  0, -1,  1],[  0,  1,  1]],
            [[  0, -1,  1],[  0,  1,  1]],
            [[  0, -1,  1],[  0,  1,  1]],
            [[  0, -1,  1],[  0,  1,  1]],
            [[  0, -1,  1],[  0,  1,  1]],
            [[  0, -1,  1],[  0,  1,  1]],
            ],dtype=float),
      },
      'Pitsch': {
        'cF' : np.array([
            [[  1,  0,  1],[  0,  1,  0]],
            [[  1,  1,  0],[  0,  0,  1]],
            [[  0,  1,  1],[  1,  0,  0]],
            [[  0,  1, -1],[  1,  0,  0]],
            [[ -1,  0,  1],[  0,  1,  0]],
            [[  1, -1,  0],[  0,  0,  1]],
            [[  1,  0, -1],[  0,  1,  0]],
            [[ -1,  1,  0],[  0,  0,  1]],
            [[  0, -1,  1],[  1,  0,  0]],
            [[  0,  1,  1],[  1,  0,  0]],
            [[  1,  0,  1],[  0,  1,  0]],
            [[  1,  1,  0],[  0,  0,  1]],
            ],dtype=float),
        'cI' : np.array([
            [[  1, -1,  1],[ -1,  0,  1]],
            [[  1,  1, -1],[  1, -1,  0]],
            [[ -1,  1,  1],[  0,  1, -1]],
            [[ -1,  1, -1],[  0, -1, -1]],
            [[ -1, -1,  1],[ -1,  0, -1]],
            [[  1, -1, -1],[ -1, -1,  0]],
            [[  1, -1, -1],[ -1,  0, -1]],
            [[ -1,  1, -1],[ -1, -1,  0]],
            [[ -1, -1,  1],[  0, -1, -1]],
            [[ -1,  1,  1],[  0, -1,  1]],
            [[  1, -1,  1],[  1,  0, -1]],
            [[  1,  1, -1],[ -1,  1,  0]],
            ],dtype=float),
      },
      'Bain': {
        'cF' : np.array([
            [[  0,  1,  0],[  1,  0,  0]],
            [[  0,  0,  1],[  0,  1,  0]],
            [[  1,  0,  0],[  0,  0,  1]],
            ],dtype=float),
        'cI' : np.array([
            [[  0,  1,  1],[  1,  0,  0]],
            [[  1,  0,  1],[  0,  1,  0]],
            [[  1,  1,  0],[  0,  0,  1]],
            ],dtype=float),
      },
      'Burgers' : {
        'cI' : np.array([
            [[ -1,  1,  1],[  1,  1,  0]],
            [[ -1,  1, -1],[  1,  1,  0]],
            [[  1,  1,  1],[  1, -1,  0]],
            [[  1,  1, -1],[  1, -1,  0]],
    
            [[  1,  1, -1],[  1,  0,  1]],
            [[ -1,  1,  1],[  1,  0,  1]],
            [[  1,  1,  1],[ -1,  0,  1]],
            [[  1, -1,  1],[ -1,  0,  1]],
    
            [[ -1,  1, -1],[  0,  1,  1]],
            [[  1,  1, -1],[  0,  1,  1]],
            [[ -1,  1,  1],[  0, -1,  1]],
            [[  1,  1,  1],[  0, -1,  1]],
          ],dtype=float),
        'hP' : np.array([
            [[  -1,  2,  -1, 0],[  0,  0,  0,  1]],
            [[  -1, -1,   2, 0],[  0,  0,  0,  1]],
            [[  -1,  2,  -1, 0],[  0,  0,  0,  1]],
            [[  -1, -1,   2, 0],[  0,  0,  0,  1]],
    
            [[  -1,  2,  -1, 0],[  0,  0,  0,  1]],
            [[  -1, -1,   2, 0],[  0,  0,  0,  1]],
            [[  -1,  2,  -1, 0],[  0,  0,  0,  1]],
            [[  -1, -1,   2, 0],[  0,  0,  0,  1]],
    
            [[  -1,  2,  -1, 0],[  0,  0,  0,  1]],
            [[  -1, -1,   2, 0],[  0,  0,  0,  1]],
            [[  -1,  2,  -1, 0],[  0,  0,  0,  1]],
            [[  -1, -1,   2, 0],[  0,  0,  0,  1]],
          ],dtype=float),
      },
    }
