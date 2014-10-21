!--------------------------------------------------------------------------------------------------
! $Id: libs.f90 3413 2014-08-24 22:07:53Z MPIE\m.diehl $
!--------------------------------------------------------------------------------------------------
!> @author Martin Diehl, Max-Planck-Institut für Eisenforschung GmbH
!> @brief all DAMASK files without solver
!> @details List of files needed by MSC.Marc, Abaqus/Explicit, and Abaqus/Standard
!--------------------------------------------------------------------------------------------------
#include "IO.f90"
#include "libs.f90"
#include "numerics.f90"
#include "debug.f90"
#include "math.f90"
#include "FEsolving.f90"
#include "mesh.f90"
#include "material.f90"
#include "lattice.f90"
#include "damage_none.f90"
#include "damage_brittle.f90"
#include "damage_ductile.f90"
#include "damage_gurson.f90"
#include "damage_anisotropic.f90"
#include "thermal_isothermal.f90"
#include "thermal_adiabatic.f90"
#include "vacancy_constant.f90"
#include "vacancy_generation.f90"
#include "constitutive_none.f90"
#include "constitutive_j2.f90"
#include "constitutive_phenopowerlaw.f90"
#include "constitutive_titanmod.f90"
#include "constitutive_dislotwin.f90"
#include "constitutive_dislokmc.f90"
#include "constitutive_nonlocal.f90"
#include "constitutive.f90"
#include "crystallite.f90"
#include "homogenization_none.f90"
#include "homogenization_isostrain.f90"
#include "homogenization_RGC.f90"
#include "homogenization.f90"
#include "CPFEM.f90"
