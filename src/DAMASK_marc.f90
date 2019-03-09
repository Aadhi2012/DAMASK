!--------------------------------------------------------------------------------------------------
!> @author Philip Eisenlohr, Max-Planck-Institut für Eisenforschung GmbH
!> @author Franz Roters, Max-Planck-Institut für Eisenforschung GmbH
!> @author Luc Hantcherli, Max-Planck-Institut für Eisenforschung GmbH
!> @author W.A. Counts
!> @author Denny Tjahjanto, Max-Planck-Institut für Eisenforschung GmbH
!> @author Christoph Kords, Max-Planck-Institut für Eisenforschung GmbH
!> @author Martin Diehl, Max-Planck-Institut für Eisenforschung GmbH
!> @brief Interfaces DAMASK with MSC.Marc
!> @details Usage:
!> @details   - choose material as hypela2
!> @details   - set statevariable 2 to index of homogenization
!> @details   - set statevariable 3 to index of microstructure
!> @details   - use nonsymmetric option for solver (e.g. direct profile or multifrontal sparse, the latter seems to be faster!)
!> @details   - in case of ddm (domain decomposition) a SYMMETRIC solver has to be used, i.e uncheck "non-symmetric"
!> @details  Marc subroutines used:
!> @details   - hypela2
!> @details   - plotv
!> @details   - flux
!> @details   - quit
!> @details  Marc common blocks included:
!> @details   - concom: lovl, inc
!> @details   - creeps: timinc
!--------------------------------------------------------------------------------------------------
#define QUOTE(x) #x
#define PASTE(x,y) x ## y

#include "prec.f90"

module DAMASK_interface

 implicit none
 private
 character(len=4), parameter, public :: InputFileExtension = '.dat'
 character(len=4), parameter, public :: LogFileExtension = '.log'
 
 public :: &
  DAMASK_interface_init, &
  getSolverJobName

contains

!--------------------------------------------------------------------------------------------------
!> @brief reports and sets working directory
!--------------------------------------------------------------------------------------------------
subroutine DAMASK_interface_init
#if __INTEL_COMPILER >= 1800
 use, intrinsic :: iso_fortran_env, only: &
   compiler_version, &
   compiler_options
#endif
 use ifport, only: &
   CHDIR

 implicit none
 integer, dimension(8) :: &
   dateAndTime
 integer :: ierr
 character(len=1024) :: wd

 write(6,'(/,a)') ' <<<+-  DAMASK_marc init -+>>>'

 write(6,'(/,a)') ' Roters et al., Computational Materials Science 158:420–478, 2018'
 write(6,'(a)')   ' https://doi.org/10.1016/j.commatsci.2018.04.030'

 write(6,'(/,a)') ' Version: '//DAMASKVERSION

 ! https://github.com/jeffhammond/HPCInfo/blob/master/docs/Preprocessor-Macros.md
#if __INTEL_COMPILER >= 1800
  write(6,'(/,a)') 'Compiled with: '//compiler_version()
  write(6,'(a)')   'Compiler options: '//compiler_options()
#else
  write(6,'(/,a,i4.4,a,i8.8)') ' Compiled with Intel fortran version :', __INTEL_COMPILER,&
                                                       ', build date :', __INTEL_COMPILER_BUILD_DATE
#endif

 write(6,'(/,a)') ' Compiled on: '//__DATE__//' at '//__TIME__

 call date_and_time(values = dateAndTime)
 write(6,'(/,a,2(i2.2,a),i4.4)') ' Date: ',dateAndTime(3),'/',dateAndTime(2),'/', dateAndTime(1)
 write(6,'(a,2(i2.2,a),i2.2)')   ' Time: ',dateAndTime(5),':', dateAndTime(6),':', dateAndTime(7)

 inquire(5, name=wd)
 wd = wd(1:scan(wd,'/',back=.true.))
 ierr = CHDIR(wd)
 if (ierr /= 0) then
   write(6,'(a20,a,a16)') ' working directory "',trim(wd),'" does not exist'
   call quit(1)
 endif

end subroutine DAMASK_interface_init


!--------------------------------------------------------------------------------------------------
!> @brief solver job name (no extension) as combination of geometry and load case name
!--------------------------------------------------------------------------------------------------
function getSolverJobName()
 use prec, only: &
   pReal, &
   pInt

 implicit none
 character(1024) :: getSolverJobName, inputName
 character(len=*), parameter :: pathSep = achar(47)//achar(92)                                      ! forward and backward slash
 integer(pInt) :: extPos

 getSolverJobName=''
 inputName=''
 inquire(5, name=inputName)                                                                         ! determine inputfile
 extPos = len_trim(inputName)-4
 getSolverJobName=inputName(scan(inputName,pathSep,back=.true.)+1:extPos)

end function getSolverJobName


end module DAMASK_interface




#include "commercialFEM_fileList.f90"

!--------------------------------------------------------------------------------------------------
!> @brief This is the MSC.Marc user subroutine for defining material behavior
!> @details (1) F,R,U are only available for continuum and membrane elements (not for
!> @details     shells and beams).
!> @details
!> @details (2) Use the -> 'Plasticity,3' card(=update+finite+large disp+constant d)
!> @details     in the parameter section of input deck (updated Lagrangian formulation).
!--------------------------------------------------------------------------------------------------
subroutine hypela2(d,g,e,de,s,t,dt,ngens,m,nn,kcus,matus,ndi,nshear,disp, &
                   dispt,coord,ffn,frotn,strechn,eigvn,ffn1,frotn1, &
                   strechn1,eigvn1,ncrd,itel,ndeg,ndm,nnode, &
                   jtype,lclass,ifr,ifu)
 use prec, only: &
   pReal, &
   pInt
 use numerics, only: &
!$ DAMASK_NumThreadsInt, &
   numerics_unitlength, &
   usePingPong
 use FEsolving, only: &
   calcMode, &
   terminallyIll, &
   symmetricSolver
 use debug, only: &
   debug_level, &
   debug_LEVELBASIC, &
   debug_MARC, &
   debug_info, &
   debug_reset
 use mesh, only: &
   theMesh, &
   mesh_FEasCP, &
   mesh_element, &
   mesh_node0, &
   mesh_node, &
   mesh_Ncellnodes, &
   mesh_cellnode, &
   mesh_build_cellnodes, &
   mesh_build_ipCoordinates
 use CPFEM, only: &
   CPFEM_general, &
   CPFEM_init_done, &
   CPFEM_initAll, &
   CPFEM_CALCRESULTS, &
   CPFEM_AGERESULTS, &
   CPFEM_COLLECT, &
   CPFEM_RESTOREJACOBIAN, &
   CPFEM_BACKUPJACOBIAN, &
   cycleCounter, &
   theInc, &
   theTime, &
   theDelta, &
   lastIncConverged, &
   outdatedByNewInc, &
   outdatedFFN1, &
   lastLovl

 implicit none
!$ include "omp_lib.h"                                                                              ! the openMP function library
 integer(pInt),                         intent(in) :: &                                             ! according to MSC.Marc 2012 Manual D
   ngens, &                                                                                         !< size of stress-strain law
   nn, &                                                                                            !< integration point number
   ndi, &                                                                                           !< number of direct components
   nshear, &                                                                                        !< number of shear components
   ncrd, &                                                                                          !< number of coordinates
   itel, &                                                                                          !< dimension of F and R, either 2 or 3
   ndeg, &                                                                                          !< number of degrees of freedom
   ndm, &                                                                                           !< not specified in MSC.Marc 2012 Manual D
   nnode, &                                                                                         !< number of nodes per element
   jtype, &                                                                                         !< element type
   ifr, &                                                                                           !< set to 1 if R has been calculated
   ifu                                                                                              !< set to 1 if stretch has been calculated
 integer(pInt), dimension(2),           intent(in) :: &                                             ! according to MSC.Marc 2012 Manual D
   m, &                                                                                             !< (1) user element number, (2) internal element number
   matus, &                                                                                         !< (1) user material identification number, (2) internal material identification number
   kcus, &                                                                                          !< (1) layer number, (2) internal layer number
   lclass                                                                                           !< (1) element class, (2) 0: displacement, 1: low order Herrmann, 2: high order Herrmann
 real(pReal),   dimension(*),           intent(in) :: &                                             ! has dimension(1) according to MSC.Marc 2012 Manual D, but according to example hypela2.f dimension(*)
   e, &                                                                                             !< total elastic strain
   de, &                                                                                            !< increment of strain
   dt                                                                                               !< increment of state variables
 real(pReal),   dimension(itel),        intent(in) :: &                                             ! according to MSC.Marc 2012 Manual D
   strechn, &                                                                                       !< square of principal stretch ratios, lambda(i) at t=n
   strechn1                                                                                         !< square of principal stretch ratios, lambda(i) at t=n+1
 real(pReal),   dimension(3,3),         intent(in) :: &                                             ! has dimension(itel,*) according to MSC.Marc 2012 Manual D, but we alway assume dimension(3,3)
   ffn, &                                                                                           !< deformation gradient at t=n
   ffn1                                                                                             !< deformation gradient at t=n+1
 real(pReal),   dimension(itel,*),      intent(in) :: &                                             ! according to MSC.Marc 2012 Manual D
   frotn, &                                                                                         !< rotation tensor at t=n
   eigvn, &                                                                                         !< i principal direction components for j eigenvalues at t=n
   frotn1, &                                                                                        !< rotation tensor at t=n+1
   eigvn1                                                                                           !< i principal direction components for j eigenvalues at t=n+1
 real(pReal),   dimension(ndeg,*),      intent(in) :: &                                             ! according to MSC.Marc 2012 Manual D
   disp, &                                                                                          !< incremental displacements
   dispt                                                                                            !< displacements at t=n (at assembly, lovl=4) and displacements at t=n+1 (at stress recovery, lovl=6)
 real(pReal),   dimension(ncrd,*),      intent(in) :: &                                             ! according to MSC.Marc 2012 Manual D
   coord                                                                                            !< coordinates
 real(pReal),   dimension(*),           intent(inout) :: &                                          ! according to MSC.Marc 2012 Manual D
   t                                                                                                !< state variables (comes in at t=n, must be updated to have state variables at t=n+1)
 real(pReal),   dimension(ndi+nshear),  intent(out) :: &                                            ! has dimension(*) according to MSC.Marc 2012 Manual D, but we need to loop over it
   s, &                                                                                             !< stress - should be updated by user
   g                                                                                                !< change in stress due to temperature effects
 real(pReal),   dimension(ngens,ngens), intent(out) :: &                                            ! according to MSC.Marc 2012 Manual D, but according to example hypela2.f dimension(ngens,*)
   d                                                                                                !< stress-strain law to be formed

!--------------------------------------------------------------------------------------------------
! Marc common blocks are in fixed format so they have to be reformated to free format (f90)
! Beware of changes in newer Marc versions

#include QUOTE(PASTE(./MarcInclude/concom,Marc4DAMASK))                                             ! concom is needed for inc, lovl
#include QUOTE(PASTE(./MarcInclude/creeps,Marc4DAMASK))                                             ! creeps is needed for timinc (time increment)

 logical :: cutBack
 real(pReal), dimension(6) ::   stress
 real(pReal), dimension(6,6) :: ddsdde
 integer(pInt) :: computationMode, i, cp_en, node, CPnodeID
 !$ integer(4) :: defaultNumThreadsInt                                                              !< default value set by Marc

 if (iand(debug_level(debug_MARC),debug_LEVELBASIC) /= 0_pInt) then
   write(6,'(a,/,i8,i8,i2)') ' MSC.MARC information on shape of element(2), IP:', m, nn
   write(6,'(a,2(i1))')      ' Jacobian:                      ', ngens,ngens
   write(6,'(a,i1)')         ' Direct stress:                 ', ndi
   write(6,'(a,i1)')         ' Shear stress:                  ', nshear
   write(6,'(a,i2)')         ' DoF:                           ', ndeg
   write(6,'(a,i2)')         ' Coordinates:                   ', ncrd
   write(6,'(a,i12)')        ' Nodes:                         ', nnode
   write(6,'(a,i1)')         ' Deformation gradient:          ', itel
   write(6,'(/,a,/,3(3(f12.7,1x)/))',advance='no') ' Deformation gradient at t=n:', &
                                 transpose(ffn)
   write(6,'(/,a,/,3(3(f12.7,1x)/))',advance='no') ' Deformation gradient at t=n+1:', &
                                 transpose(ffn1)
 endif

 !$ defaultNumThreadsInt = omp_get_num_threads()                                                    ! remember number of threads set by Marc

 if (.not. CPFEM_init_done) call CPFEM_initAll(m(1),nn)

 !$ call omp_set_num_threads(DAMASK_NumThreadsInt)                                                  ! set number of threads for parallel execution set by DAMASK_NUM_THREADS

 computationMode = 0_pInt                                                                           ! save initialization value, since it does not result in any calculation
 if (lovl == 4 ) then                                                                               ! jacobian requested by marc
   if (timinc < theDelta .and. theInc == inc .and. lastLovl /= lovl) &                              ! first after cutback
     computationMode = CPFEM_RESTOREJACOBIAN
 elseif (lovl == 6) then                                                                            ! stress requested by marc
   cp_en = mesh_FEasCP('elem',m(1))
   if (cptim > theTime .or. inc /= theInc) then                                                     ! reached "convergence"
     terminallyIll = .false.
     cycleCounter = -1                                                                              ! first calc step increments this to cycle = 0
     if (inc == 0) then                                                                             ! >> start of analysis <<
       lastIncConverged = .false.                                                                   ! no Jacobian backup
       outdatedByNewInc = .false.                                                                   ! no aging of state
       calcMode = .false.                                                                           ! pretend last step was collection
       lastLovl = lovl                                                                              ! pretend that this is NOT the first after a lovl change
       !$OMP CRITICAL (write2out)
         write(6,'(a,i6,1x,i2)') '<< HYPELA2 >> start of analysis..! ',m(1),nn
         flush(6)
       !$OMP END CRITICAL (write2out)
     else if (inc - theInc > 1) then                                                                ! >> restart of broken analysis <<
       lastIncConverged = .false.                                                                   ! no Jacobian backup
       outdatedByNewInc = .false.                                                                   ! no aging of state
       calcMode = .true.                                                                            ! pretend last step was calculation
       !$OMP CRITICAL (write2out)
         write(6,'(a,i6,1x,i2)') '<< HYPELA2 >> restart of analysis..! ',m(1),nn
         flush(6)
       !$OMP END CRITICAL (write2out)
     else                                                                                           ! >> just the next inc <<
       lastIncConverged = .true.                                                                    ! request Jacobian backup
       outdatedByNewInc = .true.                                                                    ! request aging of state
       calcMode = .true.                                                                            ! assure last step was calculation
       !$OMP CRITICAL (write2out)
         write(6,'(a,i6,1x,i2)') '<< HYPELA2 >> new increment..! ',m(1),nn
         flush(6)
       !$OMP END CRITICAL (write2out)
     endif
   else if ( timinc < theDelta ) then                                                               ! >> cutBack <<
     lastIncConverged = .false.                                                                     ! no Jacobian backup
     outdatedByNewInc = .false.                                                                     ! no aging of state
     terminallyIll = .false.
     cycleCounter = -1                                                                              ! first calc step increments this to cycle = 0
     calcMode = .true.                                                                              ! pretend last step was calculation
     !$OMP CRITICAL (write2out)
       write(6,'(a,i6,1x,i2)') '<< HYPELA2 >> cutback detected..! ',m(1),nn
       flush(6)
     !$OMP END CRITICAL (write2out)
   endif                                                                                            ! convergence treatment end


   if (usePingPong) then
     calcMode(nn,cp_en) = .not. calcMode(nn,cp_en)                                                  ! ping pong (calc <--> collect)
     if (calcMode(nn,cp_en)) then                                                                   ! now --- CALC ---
       computationMode = CPFEM_CALCRESULTS
       if (lastLovl /= lovl) then                                                                   ! first after ping pong
         call debug_reset()                                                                         ! resets debugging
         outdatedFFN1  = .false.
         cycleCounter  = cycleCounter + 1_pInt
         mesh_cellnode = mesh_build_cellnodes(mesh_node,mesh_Ncellnodes)                            ! update cell node coordinates
         call mesh_build_ipCoordinates()                                                            ! update ip coordinates
       endif
       if (outdatedByNewInc) then
         computationMode = ior(computationMode,CPFEM_AGERESULTS)                                    ! calc and age results
         outdatedByNewInc = .false.                                                                 ! reset flag
       endif
     else                                                                                           ! now --- COLLECT ---
       computationMode = CPFEM_COLLECT                                                              ! plain collect
       if (lastLovl /= lovl .and. & .not. terminallyIll) &
         call debug_info()                                                                          ! first after ping pong reports (meaningful) debugging
       if (lastIncConverged) then
         computationMode = ior(computationMode,CPFEM_BACKUPJACOBIAN)                                ! collect and backup Jacobian after convergence
         lastIncConverged = .false.                                                                 ! reset flag
       endif
       do node = 1,theMesh%elem%nNodes
         CPnodeID = mesh_element(4_pInt+node,cp_en)
         mesh_node(1:ndeg,CPnodeID) = mesh_node0(1:ndeg,CPnodeID) + numerics_unitlength * dispt(1:ndeg,node)
       enddo
     endif

   else                                                                                             ! --- PLAIN MODE ---
     computationMode = CPFEM_CALCRESULTS                                                            ! always calc
     if (lastLovl /= lovl) then
       if (.not. terminallyIll) &
         call debug_info()                                                                          ! first reports (meaningful) debugging
       call debug_reset()                                                                           ! and resets debugging
       outdatedFFN1  = .false.
       cycleCounter  = cycleCounter + 1_pInt
       mesh_cellnode = mesh_build_cellnodes(mesh_node,mesh_Ncellnodes)                              ! update cell node coordinates
       call mesh_build_ipCoordinates()                                                              ! update ip coordinates
     endif
     if (outdatedByNewInc) then
       computationMode = ior(computationMode,CPFEM_AGERESULTS)
       outdatedByNewInc = .false.                                                                   ! reset flag
     endif
     if (lastIncConverged) then
       computationMode = ior(computationMode,CPFEM_BACKUPJACOBIAN)                                  ! backup Jacobian after convergence
       lastIncConverged = .false.                                                                   ! reset flag
     endif
   endif

   theTime  = cptim                                                                                 ! record current starting time
   theDelta = timinc                                                                                ! record current time increment
   theInc   = inc                                                                                   ! record current increment number

 endif
 lastLovl = lovl                                                                                    ! record lovl

 call CPFEM_general(computationMode,usePingPong,ffn,ffn1,t(1),timinc,m(1),nn,stress,ddsdde)

!     Mandel: 11, 22, 33, SQRT(2)*12, SQRT(2)*23, SQRT(2)*13
!     Marc:   11, 22, 33, 12, 23, 13
!     Marc:   11, 22, 33, 12

 d = ddsdde(1:ngens,1:ngens)
 s = stress(1:ndi+nshear)
 g = 0.0_pReal
 if(symmetricSolver) d = 0.5_pReal*(d+transpose(d))

 !$ call omp_set_num_threads(defaultNumThreadsInt)                                                  ! reset number of threads to stored default value

end subroutine hypela2


!--------------------------------------------------------------------------------------------------
!> @brief calculate internal heat generated due to inelastic energy dissipation
!--------------------------------------------------------------------------------------------------
subroutine flux(f,ts,n,time)
 use prec, only: &
   pReal, &
   pInt
 use thermal_conduction, only: &
   thermal_conduction_getSourceAndItsTangent
 use mesh, only: &
   mesh_FEasCP

 implicit none
 real(pReal),   dimension(6),           intent(in) :: &
   ts
 integer(pInt), dimension(10),          intent(in) :: &
   n
 real(pReal),                           intent(in) :: &
   time
 real(pReal),   dimension(2),           intent(out) :: &
   f

 call thermal_conduction_getSourceAndItsTangent(f(1), f(2), ts(3), n(3),mesh_FEasCP('elem',n(1)))

 end subroutine flux


!--------------------------------------------------------------------------------------------------
!> @brief sets user defined output variables for Marc
!> @details select a variable contour plotting (user subroutine).
!--------------------------------------------------------------------------------------------------
subroutine plotv(v,s,sp,etot,eplas,ecreep,t,m,nn,layer,ndi,nshear,jpltcd)
 use prec, only: &
   pReal, &
   pInt
 use mesh, only: &
   mesh_FEasCP
 use IO, only: &
   IO_error
 use homogenization, only: &
   materialpoint_results,&
   materialpoint_sizeResults

 implicit none
 integer(pInt),               intent(in) :: &
   m, &                                                                                             !< element number
   nn, &                                                                                            !< integration point number
   layer, &                                                                                         !< layer number
   ndi, &                                                                                           !< number of direct stress components
   nshear, &                                                                                        !< number of shear stress components
   jpltcd                                                                                           !< user variable index
 real(pReal),   dimension(*), intent(in) :: &
   s, &                                                                                             !< stress array
   sp, &                                                                                            !< stresses in preferred direction
   etot, &                                                                                          !< total strain (generalized)
   eplas, &                                                                                         !< total plastic strain
   ecreep, &                                                                                        !< total creep strain
   t                                                                                                !< current temperature
 real(pReal),                 intent(out) :: &
   v                                                                                                !< variable

 if (jpltcd > materialpoint_sizeResults) call IO_error(700_pInt,jpltcd)                             ! complain about out of bounds error
 v = materialpoint_results(jpltcd,nn,mesh_FEasCP('elem', m))

end subroutine plotv
