!--------------------------------------------------------------------------------------------------
!> @author Martin Diehl, Max-Planck-Institut für Eisenforschung GmbH
!> @brief Reads in the material, numerics & debug configuration from their respective file
!> @details Reads the material configuration file, where solverJobName.yaml takes
!! precedence over material.yaml.
!--------------------------------------------------------------------------------------------------
module config
  use prec
  use DAMASK_interface
  use IO
  use YAML_parse
  use YAML_types

#ifdef PETSc
#include <petsc/finclude/petscsys.h>
   use petscsys
#endif

  implicit none
  private

  class(tNode), pointer, public :: &
    material_root, &
    numerics_root, &
    debug_root

  public :: &
    config_init, &
    config_deallocate

contains

!--------------------------------------------------------------------------------------------------
!> @brief calls subroutines that reads material, numerics and debug configuration files
!--------------------------------------------------------------------------------------------------
subroutine config_init

  write(6,'(/,a)') ' <<<+-  config init  -+>>>'; flush(6)

  call parse_material
  call parse_numerics
  call parse_debug

end subroutine config_init


!--------------------------------------------------------------------------------------------------
!> @brief reads material.yaml
!--------------------------------------------------------------------------------------------------
subroutine parse_material

  logical :: fileExists
  character(len=:), allocatable :: fname

  fname = getSolverJobName()//'.yaml'
  inquire(file=fname,exist=fileExists)
  if(.not. fileExists) then
    fname = 'material.yaml'
    inquire(file=fname,exist=fileExists)
    if(.not. fileExists) call IO_error(100,ext_msg=fname)
  endif
  write(6,*) 'reading '//fname; flush(6)
  material_root => parse_flow(to_flow(IO_read(fname)))

end subroutine parse_material


!--------------------------------------------------------------------------------------------------
!> @brief reads in parameters from numerics.yaml and sets openMP related parameters. Also does
! a sanity check
!--------------------------------------------------------------------------------------------------
subroutine parse_numerics

  logical :: fexist

  numerics_root => emptyDict
  inquire(file='numerics.yaml', exist=fexist)
  if (fexist) then
    write(6,*) 'reading numerics.yaml'; flush(6)
    numerics_root =>  parse_flow(to_flow(IO_read('numerics.yaml')))
  endif

end subroutine parse_numerics


!--------------------------------------------------------------------------------------------------
!> @brief reads in parameters from debug.yaml
!--------------------------------------------------------------------------------------------------
subroutine parse_debug

  logical :: fexist

  debug_root => emptyDict
  inquire(file='debug.yaml', exist=fexist)
  fileExists: if (fexist) then
    write(6,*) 'reading debug.yaml'; flush(6)
    debug_root  => parse_flow(to_flow(IO_read('debug.yaml')))
  endif fileExists

end subroutine parse_debug


!--------------------------------------------------------------------------------------------------
!> @brief deallocates material.yaml structure
!ToDo: deallocation of numerics debug (optional)
!--------------------------------------------------------------------------------------------------
subroutine config_deallocate

  deallocate(material_root)                            

end subroutine config_deallocate

end module config
