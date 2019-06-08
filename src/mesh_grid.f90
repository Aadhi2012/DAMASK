!--------------------------------------------------------------------------------------------------
!> @author Franz Roters, Max-Planck-Institut für Eisenforschung GmbH
!> @author Philip Eisenlohr, Max-Planck-Institut für Eisenforschung GmbH
!> @author Martin Diehl, Max-Planck-Institut für Eisenforschung GmbH
!> @brief Parse geometry file to set up discretization and geometry for nonlocal model
!--------------------------------------------------------------------------------------------------
module mesh
#include <petsc/finclude/petscsys.h>
  use PETScsys

  use prec
  use system_routines
  use DAMASK_interface
  use IO
  use debug
  use numerics
  use discretization
  use geometry_plastic_nonlocal
  use FEsolving
 
  implicit none
  private
 
  real(pReal), dimension(:,:,:), allocatable, public :: &
    mesh_ipCoordinates                                                                              !< IP x,y,z coordinates (after deformation!)
 
  integer,     dimension(3), public, protected :: &
    grid                                                                                            !< (global) grid
  integer,                   public, protected :: &
    grid3, &                                                                                        !< (local) grid in 3rd direction
    grid3Offset                                                                                     !< (local) grid offset in 3rd direction
    
  real(pReal), dimension(3), public, protected :: &
    geomSize
  real(pReal),               public, protected :: &
    size3, &                                                                                        !< (local) size in 3rd direction
    size3offset                                                                                     !< (local) size offset in 3rd direction
 
  public :: &
    mesh_init
 
contains


!--------------------------------------------------------------------------------------------------
!> @brief reads the geometry file to obtain information on discretization
!--------------------------------------------------------------------------------------------------
subroutine mesh_init(ip,el)

  integer, intent(in), optional :: el, ip                                                           ! for compatibility reasons
  
  include 'fftw3-mpi.f03'
  real(pReal), dimension(3) :: &
    mySize                                                                                          !< domain size of this process
  integer,     dimension(3) :: &
    myGrid                                                                                          !< domain grid of this process

  integer,     dimension(:),   allocatable :: &
    microstructureAt, &
    homogenizationAt

  logical :: myDebug
  integer :: j
  integer(C_INTPTR_T) :: &
    devNull, z, z_offset

  write(6,'(/,a)')   ' <<<+-  mesh init  -+>>>'

  myDebug = iand(debug_level(debug_mesh),debug_levelBasic) /= 0

  call mesh_spectral_read_grid(grid,geomSize,microstructureAt,homogenizationAt)

  if(worldsize>grid(3)) call IO_error(894, ext_msg='number of processes exceeds grid(3)')

  call fftw_mpi_init
  devNull = fftw_mpi_local_size_3d(int(grid(3),C_INTPTR_T), &
                                   int(grid(2),C_INTPTR_T), &
                                   int(grid(1),C_INTPTR_T)/2+1, &
                                   PETSC_COMM_WORLD, &
                                   z, &                                                             ! domain grid size along z
                                   z_offset)                                                        ! domain grid offset along z
  grid3       = int(z)
  grid3Offset = int(z_offset)
  size3       = geomSize(3)*real(grid3,pReal)      /real(grid(3),pReal)
  size3Offset = geomSize(3)*real(grid3Offset,pReal)/real(grid(3),pReal)
  myGrid = [grid(1:2),grid3]
  mySize = [geomSize(1:2),size3]

  microstructureAt = microstructureAt(product(grid(1:2))*grid3Offset+1: &
                                      product(grid(1:2))*(grid3Offset+grid3))                       ! reallocate/shrink in case of MPI
  homogenizationAt = homogenizationAt(product(grid(1:2))*grid3Offset+1: &
                                      product(grid(1:2))*(grid3Offset+grid3))                       ! reallocate/shrink in case of MPI

 
  mesh_ipCoordinates = mesh_build_ipCoordinates(myGrid,mySize,grid3Offset)
  if (myDebug) write(6,'(a)') ' Built IP coordinates'; flush(6)

  call geometry_plastic_nonlocal_setIPvolume( &
    reshape([(product(mySize/real(myGrid,pReal)),j=1,product(myGrid))],[1,product(myGrid)]))
  call geometry_plastic_nonlocal_setIParea(mesh_build_ipAreas(mySize,myGrid))
  call geometry_plastic_nonlocal_setIPareaNormal(mesh_build_ipNormals(product(myGrid)))
  call geometry_plastic_nonlocal_setIPneighborhood(mesh_spectral_build_ipNeighborhood(myGrid))
  if (myDebug) write(6,'(a)') ' Built nonlocal geometry'; flush(6)

  if (debug_e < 1 .or. debug_e > product(myGrid)) &
    call IO_error(602,ext_msg='element')                                                            ! selected element does not exist
  if (debug_i /= 1) &
    call IO_error(602,ext_msg='IP')                                                                 ! selected element does not have requested IP

  FEsolving_execElem = [1,product(myGrid)]                                                          ! parallel loop bounds set to comprise all elements
  allocate(FEsolving_execIP(2,product(myGrid)),source=1)                                            ! parallel loop bounds set to comprise the only IP

  call discretization_init(homogenizationAt,microstructureAt, &
                           reshape(mesh_ipCoordinates,[3,product(myGrid)]), &
                           mesh_spectral_build_nodes(myGrid,mySize,grid3Offset))

end subroutine mesh_init


!--------------------------------------------------------------------------------------------------
!> @brief Parses geometry file
!> @details important variables have an implicit "save" attribute. Therefore, this function is 
! supposed to be called only once!
!--------------------------------------------------------------------------------------------------
subroutine mesh_spectral_read_grid(grid,geomSize,microstructure,homogenization)

  integer,     dimension(3), intent(out)              :: grid                                       ! grid (for all processes!)
  real(pReal), dimension(3), intent(out)              :: geomSize                                   ! size (for all processes!)
  integer,     dimension(:), intent(out), allocatable :: &
   microstructure, &
   homogenization
   
  character(len=:),            allocatable :: rawData
  character(len=65536)                     :: line
  integer(pInt), allocatable, dimension(:) :: chunkPos
  integer(pInt) :: h =- 1_pInt
  integer(pInt) ::  &
    headerLength = -1_pInt, &                                                                       !< length of header (in lines)
    fileLength, &                                                                                   !< length of the geom file (in characters)
    fileUnit, &
    startPos, endPos, &
    myStat, &
    l, &                                                                                            !< line counter
    c, &                                                                                            !< counter for # microstructures in line
    o, &                                                                                            !< order of "to" packing
    e, &                                                                                            !< "element", i.e. spectral collocation point 
    i, j
    
  grid = -1_pInt
  geomSize = -1.0_pReal

!--------------------------------------------------------------------------------------------------
! read data as stream
  inquire(file = trim(geometryFile), size=fileLength)
  open(newunit=fileUnit, file=trim(geometryFile), access='stream',&
       status='old', position='rewind', action='read',iostat=myStat)
  if(myStat /= 0_pInt) call IO_error(100_pInt,ext_msg=trim(geometryFile))
  allocate(character(len=fileLength)::rawData)
  read(fileUnit) rawData
  close(fileUnit)
  
!--------------------------------------------------------------------------------------------------
! get header length
  endPos = index(rawData,new_line(''))
  if(endPos <= index(rawData,'head')) then
    startPos = len(rawData)
    call IO_error(error_ID=841_pInt, ext_msg='mesh_spectral_read_grid')
  else
    chunkPos = IO_stringPos(rawData(1:endPos))
    if (chunkPos(1) < 2_pInt) call IO_error(error_ID=841_pInt, ext_msg='mesh_spectral_read_grid')
    headerLength = IO_intValue(rawData(1:endPos),chunkPos,1_pInt)
    startPos = endPos + 1_pInt
  endif

!--------------------------------------------------------------------------------------------------
! read and interprete header
  l = 0
  do while (l < headerLength .and. startPos < len(rawData))
    endPos = startPos + index(rawData(startPos:),new_line('')) - 1_pInt
    if (endPos < startPos) endPos = len(rawData)                                                    ! end of file without new line
    line = rawData(startPos:endPos)
    startPos = endPos + 1_pInt
    l = l + 1_pInt

    chunkPos = IO_stringPos(trim(line))
    if (chunkPos(1) < 2) cycle                                                                      ! need at least one keyword value pair
    
    select case ( IO_lc(IO_StringValue(trim(line),chunkPos,1_pInt,.true.)) )
      case ('grid')
        if (chunkPos(1) > 6) then
          do j = 2_pInt,6_pInt,2_pInt
            select case (IO_lc(IO_stringValue(line,chunkPos,j)))
              case('a')
                grid(1) = IO_intValue(line,chunkPos,j+1_pInt)
              case('b')
                grid(2) = IO_intValue(line,chunkPos,j+1_pInt)
              case('c')
                grid(3) = IO_intValue(line,chunkPos,j+1_pInt)
            end select
          enddo
        endif
        
      case ('size')
        if (chunkPos(1) > 6) then
          do j = 2_pInt,6_pInt,2_pInt
            select case (IO_lc(IO_stringValue(line,chunkPos,j)))
              case('x')
                geomSize(1) = IO_floatValue(line,chunkPos,j+1_pInt)
              case('y')
                geomSize(2) = IO_floatValue(line,chunkPos,j+1_pInt)
              case('z')
                geomSize(3) = IO_floatValue(line,chunkPos,j+1_pInt)
            end select
          enddo
        endif
        
      case ('homogenization')
        if (chunkPos(1) > 1) h = IO_intValue(line,chunkPos,2_pInt)
    end select

  enddo

!--------------------------------------------------------------------------------------------------
! sanity checks
  if(h < 1_pInt) &
    call IO_error(error_ID = 842_pInt, ext_msg='homogenization (mesh_spectral_read_grid)')
  if(any(grid < 1_pInt)) &
    call IO_error(error_ID = 842_pInt, ext_msg='grid (mesh_spectral_read_grid)')
  if(any(geomSize < 0.0_pReal)) &
    call IO_error(error_ID = 842_pInt, ext_msg='size (mesh_spectral_read_grid)')

  allocate(microstructure(product(grid)), source = -1)                                              ! too large in case of MPI (shrink later, not very elegant)
  allocate(homogenization(product(grid)), source = h)                                               ! too large in case of MPI (shrink later, not very elegant)
     
!--------------------------------------------------------------------------------------------------
! read and interpret content
  e = 1_pInt
  do while (startPos < len(rawData))
    endPos = startPos + index(rawData(startPos:),new_line('')) - 1_pInt
    if (endPos < startPos) endPos = len(rawData)                                                    ! end of file without new line
    line = rawData(startPos:endPos)
    startPos = endPos + 1_pInt
    l = l + 1_pInt
    chunkPos = IO_stringPos(trim(line))
    
    noCompression: if (chunkPos(1) /= 3) then
      c = chunkPos(1)
      microstructure(e:e+c-1_pInt) =  [(IO_intValue(line,chunkPos,i+1_pInt), i=0_pInt, c-1_pInt)]
    else noCompression
      compression: if (IO_lc(IO_stringValue(line,chunkPos,2))  == 'of') then
        c = IO_intValue(line,chunkPos,1)
        microstructure(e:e+c-1_pInt) = [(IO_intValue(line,chunkPos,3),i = 1_pInt,IO_intValue(line,chunkPos,1))]
      else if (IO_lc(IO_stringValue(line,chunkPos,2))  == 'to') then compression
        c = abs(IO_intValue(line,chunkPos,3) - IO_intValue(line,chunkPos,1)) + 1_pInt
        o = merge(+1_pInt, -1_pInt, IO_intValue(line,chunkPos,3) > IO_intValue(line,chunkPos,1))
        microstructure(e:e+c-1_pInt) = [(i, i = IO_intValue(line,chunkPos,1),IO_intValue(line,chunkPos,3),o)]
      else compression
        c = chunkPos(1)
        microstructure(e:e+c-1_pInt) =  [(IO_intValue(line,chunkPos,i+1_pInt), i=0_pInt, c-1_pInt)]
      endif compression
    endif noCompression

    e = e+c
  end do

  if (e-1 /= product(grid)) call IO_error(error_ID = 843_pInt, el=e)

end subroutine mesh_spectral_read_grid


!---------------------------------------------------------------------------------------------------
!> @brief Calculates position of nodes (pretend to be an element)
!---------------------------------------------------------------------------------------------------
pure function mesh_spectral_build_nodes(grid,geomSize,grid3Offset) result(nodes)

  integer,     dimension(3), intent(in)      :: grid                                                ! grid (for this process!)
  real(pReal), dimension(3), intent(in)      :: geomSize                                            ! size (for this process!)
  integer,                   intent(in)      :: grid3Offset                                         ! grid(3) offset
  real(pReal), dimension(3,product(grid+1))  :: nodes
  integer :: n,a,b,c

  n = 0
  do c = 0, grid3
    do b = 0, grid(2)
      do a = 0, grid(1)
         n = n + 1
         nodes(1:3,n) = geomSize/real(grid,pReal) * real([a,b,grid3Offset+c],pReal)
      enddo
    enddo
  enddo

end function mesh_spectral_build_nodes


!---------------------------------------------------------------------------------------------------
!> @brief Calculates position of IPs/cell centres (pretend to be an element)
!---------------------------------------------------------------------------------------------------
function mesh_build_ipCoordinates(grid,geomSize,grid3Offset) result(ipCoordinates)

  integer,     dimension(3), intent(in)      :: grid                                                ! grid (for this process!)
  real(pReal), dimension(3), intent(in)      :: geomSize                                            ! size (for this process!)
  integer,                   intent(in)      :: grid3Offset                                         ! grid(3) offset
  real(pReal), dimension(3,1,product(grid))  :: ipCoordinates
  integer :: n,a,b,c
 
  n = 0
  do c = 1, grid(3)
    do b = 1, grid(2)
      do a = 1, grid(1)
         n = n + 1
         ipCoordinates(1:3,1,n) = geomSize/real(grid,pReal) * (real([a,b,grid3Offset+c],pReal) -0.5_pReal)
      enddo
    enddo
  enddo

end function mesh_build_ipCoordinates


!--------------------------------------------------------------------------------------------------
!> @brief build neighborhood relations for spectral
!> @details assign globals: mesh_ipNeighborhood
!--------------------------------------------------------------------------------------------------
pure function mesh_spectral_build_ipNeighborhood(grid) result(IPneighborhood)

 integer, dimension(3), intent(in) :: grid                                                          ! grid (for this process!)
 
 integer, dimension(3,6,1,product(grid)) :: IPneighborhood                                          !< 6 or less neighboring IPs as [element_num, IP_index, neighbor_index that points to me]
 
 integer :: &
  x,y,z, &
  e

 e = 0
 do z = 0,grid(3)-1
   do y = 0,grid(2)-1
     do x = 0,grid(1)-1
       e = e + 1
         IPneighborhood(1,1,1,e) = z * grid(1) * grid(2) &
                                      + y * grid(1) &
                                      + modulo(x+1,grid(1)) &
                                      + 1
         IPneighborhood(1,2,1,e) = z * grid(1) * grid(2) &
                                      + y * grid(1) &
                                      + modulo(x-1,grid(1)) &
                                      + 1
         IPneighborhood(1,3,1,e) = z * grid(1) * grid(2) &
                                      + modulo(y+1,grid(2)) * grid(1) &
                                      + x &
                                      + 1
         IPneighborhood(1,4,1,e) = z * grid(1) * grid(2) &
                                      + modulo(y-1,grid(2)) * grid(1) &
                                      + x &
                                      + 1
         IPneighborhood(1,5,1,e) = modulo(z+1,grid(3)) * grid(1) * grid(2) &
                                      + y * grid(1) &
                                      + x &
                                      + 1
         IPneighborhood(1,6,1,e) = modulo(z-1,grid(3)) * grid(1) * grid(2) &
                                      + y * grid(1) &
                                      + x &
                                      + 1
         IPneighborhood(2,1:6,1,e) = 1
         IPneighborhood(3,1,1,e) = 2
         IPneighborhood(3,2,1,e) = 1
         IPneighborhood(3,3,1,e) = 4
         IPneighborhood(3,4,1,e) = 3
         IPneighborhood(3,5,1,e) = 6
         IPneighborhood(3,6,1,e) = 5
     enddo
   enddo
 enddo
 
end function mesh_spectral_build_ipNeighborhood


!--------------------------------------------------------------------------------------------------
!> @brief calculation of IP interface areas
!--------------------------------------------------------------------------------------------------
pure function mesh_build_ipAreas(geomSize,grid) result(IPareas)
  
  real(pReal), dimension(3), intent(in)     :: geomSize                                             ! size (for this process!)
  integer,     dimension(3), intent(in)     :: grid                                                 ! grid (for this process!)
  
  real(pReal), dimension(6,1,product(grid)) :: IPareas

  IPareas(1:2,1,:) = geomSize(2)/real(grid(2)) * geomSize(3)/real(grid(3))
  IPareas(3:4,1,:) = geomSize(3)/real(grid(3)) * geomSize(1)/real(grid(1))
  IPareas(5:6,1,:) = geomSize(1)/real(grid(1)) * geomSize(2)/real(grid(2))
  
end function mesh_build_ipAreas


!--------------------------------------------------------------------------------------------------
!> @brief calculation of IP interface areas normals
!--------------------------------------------------------------------------------------------------
pure function mesh_build_ipNormals(nElems) result(IPnormals)

  integer, intent(in) :: nElems
  
  real, dimension(3,6,1,nElems) :: IPnormals

  IPnormals(1:3,1,1,:) = spread([+1.0_pReal, 0.0_pReal, 0.0_pReal],2,nElems)
  IPnormals(1:3,2,1,:) = spread([-1.0_pReal, 0.0_pReal, 0.0_pReal],2,nElems)
  IPnormals(1:3,3,1,:) = spread([ 0.0_pReal,+1.0_pReal, 0.0_pReal],2,nElems)
  IPnormals(1:3,4,1,:) = spread([ 0.0_pReal,-1.0_pReal, 0.0_pReal],2,nElems)
  IPnormals(1:3,5,1,:) = spread([ 0.0_pReal, 0.0_pReal,+1.0_pReal],2,nElems)
  IPnormals(1:3,6,1,:) = spread([ 0.0_pReal, 0.0_pReal,-1.0_pReal],2,nElems)
  
end function mesh_build_ipNormals




!--------------------------------------------------------------------------------------------------
!> @brief builds mesh of (distorted) cubes for given coordinates (= center of the cubes)
!--------------------------------------------------------------------------------------------------
function mesh_nodesAroundCentres(gDim,Favg,centres) result(nodes)

 real(pReal), intent(in), dimension(:,:,:,:) :: &
   centres
 real(pReal),             dimension(3,size(centres,2)+1,size(centres,3)+1,size(centres,4)+1) :: &
   nodes
 real(pReal), intent(in), dimension(3) :: &
   gDim
 real(pReal), intent(in), dimension(3,3) :: &
   Favg
 real(pReal),             dimension(3,size(centres,2)+2,size(centres,3)+2,size(centres,4)+2) :: &
   wrappedCentres

 integer(pInt) :: &
   i,j,k,n
 integer(pInt),           dimension(3), parameter :: &
   diag = 1_pInt
 integer(pInt),           dimension(3) :: &
   shift = 0_pInt, &
   lookup = 0_pInt, &
   me = 0_pInt, &
   iRes = 0_pInt
 integer(pInt),           dimension(3,8) :: &
   neighbor = reshape([ &
                       0_pInt, 0_pInt, 0_pInt, &
                       1_pInt, 0_pInt, 0_pInt, &
                       1_pInt, 1_pInt, 0_pInt, &
                       0_pInt, 1_pInt, 0_pInt, &
                       0_pInt, 0_pInt, 1_pInt, &
                       1_pInt, 0_pInt, 1_pInt, &
                       1_pInt, 1_pInt, 1_pInt, &
                       0_pInt, 1_pInt, 1_pInt  ], [3,8])

!--------------------------------------------------------------------------------------------------
! initializing variables
 iRes =  [size(centres,2),size(centres,3),size(centres,4)]
 nodes = 0.0_pReal
 wrappedCentres = 0.0_pReal

!--------------------------------------------------------------------------------------------------
! building wrappedCentres = centroids + ghosts
 wrappedCentres(1:3,2_pInt:iRes(1)+1_pInt,2_pInt:iRes(2)+1_pInt,2_pInt:iRes(3)+1_pInt) = centres
 do k = 0_pInt,iRes(3)+1_pInt
   do j = 0_pInt,iRes(2)+1_pInt
     do i = 0_pInt,iRes(1)+1_pInt
       if (k==0_pInt .or. k==iRes(3)+1_pInt .or. &                                                  ! z skin
           j==0_pInt .or. j==iRes(2)+1_pInt .or. &                                                  ! y skin
           i==0_pInt .or. i==iRes(1)+1_pInt      ) then                                             ! x skin
         me = [i,j,k]                                                                               ! me on skin
         shift = sign(abs(iRes+diag-2_pInt*me)/(iRes+diag),iRes+diag-2_pInt*me)
         lookup = me-diag+shift*iRes
         wrappedCentres(1:3,i+1_pInt,        j+1_pInt,        k+1_pInt) = &
                centres(1:3,lookup(1)+1_pInt,lookup(2)+1_pInt,lookup(3)+1_pInt) &
                - matmul(Favg, real(shift,pReal)*gDim)
       endif
 enddo; enddo; enddo

!--------------------------------------------------------------------------------------------------
! averaging
 do k = 0_pInt,iRes(3); do j = 0_pInt,iRes(2); do i = 0_pInt,iRes(1)
   do n = 1_pInt,8_pInt
    nodes(1:3,i+1_pInt,j+1_pInt,k+1_pInt) = &
    nodes(1:3,i+1_pInt,j+1_pInt,k+1_pInt) + wrappedCentres(1:3,i+1_pInt+neighbor(1,n), &
                                                               j+1_pInt+neighbor(2,n), &
                                                               k+1_pInt+neighbor(3,n) )
   enddo
 enddo; enddo; enddo
 nodes = nodes/8.0_pReal

end function mesh_nodesAroundCentres

end module mesh
