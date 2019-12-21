!--------------------------------------------------------------------------------------------------
!> @author Pratheek Shanthraj, Max-Planck-Institut für Eisenforschung GmbH
!> @brief material subroutine for locally evolving damage field
!--------------------------------------------------------------------------------------------------
module damage_local
  use prec
  use material
  use config
  use numerics
  use source_damage_isoBrittle
  use source_damage_isoDuctile
  use source_damage_anisoBrittle
  use source_damage_anisoDuctile
  use results

  implicit none
  private

  enum, bind(c) 
    enumerator :: &
      undefined_ID, &
      damage_ID
  end enum

  type :: tParameters
    integer(kind(undefined_ID)), dimension(:),   allocatable :: &
      outputID
  end type tParameters
  
  type(tparameters),             dimension(:),   allocatable :: &
    param
    
  public :: &
    damage_local_init, &
    damage_local_updateState, &
    damage_local_Results

contains

!--------------------------------------------------------------------------------------------------
!> @brief module initialization
!> @details reads in material parameters, allocates arrays, and does sanity checks
!--------------------------------------------------------------------------------------------------
subroutine damage_local_init

  integer :: maxNinstance,o,NofMyHomog,h
  character(len=65536), dimension(0), parameter   :: emptyStringArray = [character(len=65536)::]
  character(len=65536), dimension(:), allocatable :: outputs
  
  write(6,'(/,a)')   ' <<<+-  damage_'//DAMAGE_local_label//' init  -+>>>'; flush(6)

  maxNinstance = count(damage_type == DAMAGE_local_ID)
  if (maxNinstance == 0) return
  
  allocate(param(maxNinstance))
   
  do h = 1, size(damage_type)
    if (damage_type(h) /= DAMAGE_LOCAL_ID) cycle
    associate(prm => param(damage_typeInstance(h)),config => config_homogenization(h))
              
    outputs = config%getStrings('(output)',defaultVal=emptyStringArray)
    allocate(prm%outputID(0))
    
    do o=1, size(outputs)
      select case(outputs(o))
        case ('damage')
          prm%outputID = [prm%outputID , damage_ID]
      end select     
    enddo

    NofMyHomog = count(material_homogenizationAt == h)
    damageState(h)%sizeState = 1
    allocate(damageState(h)%state0   (1,NofMyHomog), source=damage_initialPhi(h))
    allocate(damageState(h)%subState0(1,NofMyHomog), source=damage_initialPhi(h))
    allocate(damageState(h)%state    (1,NofMyHomog), source=damage_initialPhi(h))
 
    nullify(damageMapping(h)%p)
    damageMapping(h)%p => mappingHomogenization(1,:,:)
    deallocate(damage(h)%p)
    damage(h)%p => damageState(h)%state(1,:)
    
    end associate
  enddo

end subroutine damage_local_init


!--------------------------------------------------------------------------------------------------
!> @brief  calculates local change in damage field   
!--------------------------------------------------------------------------------------------------
function damage_local_updateState(subdt, ip, el)
 
  integer, intent(in) :: &
    ip, &                                                                                           !< integration point number
    el                                                                                              !< element number
  real(pReal),   intent(in) :: &
    subdt
  logical,    dimension(2)  :: &
    damage_local_updateState
  integer :: &
    homog, &
    offset
  real(pReal) :: &
    phi, phiDot, dPhiDot_dPhi  
  
  homog  = material_homogenizationAt(el)
  offset = mappingHomogenization(1,ip,el)
  phi = damageState(homog)%subState0(1,offset)
  call damage_local_getSourceAndItsTangent(phiDot, dPhiDot_dPhi, phi, ip, el)
  phi = max(residualStiffness,min(1.0_pReal,phi + subdt*phiDot))
  
  damage_local_updateState = [     abs(phi - damageState(homog)%state(1,offset)) &
                                <= err_damage_tolAbs &
                              .or. abs(phi - damageState(homog)%state(1,offset)) &
                                <= err_damage_tolRel*abs(damageState(homog)%state(1,offset)), &
                              .true.]

  damageState(homog)%state(1,offset) = phi  

end function damage_local_updateState


!--------------------------------------------------------------------------------------------------
!> @brief  calculates homogenized local damage driving forces  
!--------------------------------------------------------------------------------------------------
subroutine damage_local_getSourceAndItsTangent(phiDot, dPhiDot_dPhi, phi, ip, el)
  
  integer, intent(in) :: &
    ip, &                                                                                           !< integration point number
    el                                                                                              !< element number
  real(pReal),   intent(in) :: &
    phi
  integer :: &
    phase, &
    grain, &
    source, &
    constituent
  real(pReal) :: &
    phiDot, dPhiDot_dPhi, localphiDot, dLocalphiDot_dPhi  

  phiDot = 0.0_pReal
  dPhiDot_dPhi = 0.0_pReal
  do grain = 1, homogenization_Ngrains(material_homogenizationAt(el))
    phase = material_phaseAt(grain,el)
    constituent = material_phasememberAt(grain,ip,el)
    do source = 1, phase_Nsources(phase)
      select case(phase_source(source,phase))                                                   
        case (SOURCE_damage_isoBrittle_ID)
         call source_damage_isobrittle_getRateAndItsTangent  (localphiDot, dLocalphiDot_dPhi, phi, phase, constituent)

        case (SOURCE_damage_isoDuctile_ID)
         call source_damage_isoductile_getRateAndItsTangent  (localphiDot, dLocalphiDot_dPhi, phi, phase, constituent)

        case (SOURCE_damage_anisoBrittle_ID)
         call source_damage_anisobrittle_getRateAndItsTangent(localphiDot, dLocalphiDot_dPhi, phi, phase, constituent)

        case (SOURCE_damage_anisoDuctile_ID)
         call source_damage_anisoductile_getRateAndItsTangent(localphiDot, dLocalphiDot_dPhi, phi, phase, constituent)

        case default
         localphiDot = 0.0_pReal
         dLocalphiDot_dPhi = 0.0_pReal

      end select
      phiDot = phiDot + localphiDot
      dPhiDot_dPhi = dPhiDot_dPhi + dLocalphiDot_dPhi
    enddo  
  enddo
  
  phiDot = phiDot/real(homogenization_Ngrains(material_homogenizationAt(el)),pReal)
  dPhiDot_dPhi = dPhiDot_dPhi/real(homogenization_Ngrains(material_homogenizationAt(el)),pReal)
 
end subroutine damage_local_getSourceAndItsTangent


!--------------------------------------------------------------------------------------------------
!> @brief writes results to HDF5 output file
!--------------------------------------------------------------------------------------------------
subroutine damage_local_results(homog,group)

  integer,          intent(in) :: homog
  character(len=*), intent(in) :: group
  integer :: o
  
  associate(prm => param(damage_typeInstance(homog)))

  outputsLoop: do o = 1,size(prm%outputID)
    select case(prm%outputID(o))
    
      case (damage_ID)
        call results_writeDataset(group,damage(homog)%p,'phi',&
                                  'damage indicator','-')
    end select
  enddo outputsLoop
  end associate

end subroutine damage_local_results


end module damage_local
