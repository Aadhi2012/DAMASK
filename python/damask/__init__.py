"""Main aggregator."""
import os
import re

name = 'damask'
with open(os.path.join(os.path.dirname(__file__),'VERSION')) as f:
    version = re.sub(r'^v','',f.readline().strip())

# classes
from .environment import Environment      # noqa
from .table       import Table            # noqa
from .asciitable  import ASCIItable       # noqa
    
from .config      import Material         # noqa
from .colormaps   import Colormap, Color  # noqa
from .orientation import Symmetry, Lattice, Rotation, Orientation # noqa
from .dadf5       import DADF5            # noqa

from .geom        import Geom             # noqa
from .solver      import Solver           # noqa
from .test        import Test             # noqa
from .util        import extendableOption # noqa

# functions in modules
from .            import mechanics        # noqa
from .            import grid_filters     # noqa

# clean temporary variables
del os
del re
del f
