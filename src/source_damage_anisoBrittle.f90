!--------------------------------------------------------------------------------------------------
!> @author Luv Sharma, Max-Planck-Institut für Eisenforschung GmbH
!> @author Pratheek Shanthraj, Max-Planck-Institut für Eisenforschung GmbH
!> @brief material subroutine incorporating anisotropic brittle damage source mechanism
!> @details to be done
!--------------------------------------------------------------------------------------------------
module source_damage_anisoBrittle
  use prec
  use debug
  use IO
  use math
  use material
  use discretization
  use config
  use lattice
  use results

  implicit none
  private

  integer,                       dimension(:),           allocatable :: &
    source_damage_anisoBrittle_offset, &                                                            !< which source is my current source mechanism?
    source_damage_anisoBrittle_instance                                                             !< instance of source mechanism
    
  integer,                       dimension(:,:),         allocatable :: &
    source_damage_anisoBrittle_Ncleavage                                                            !< number of cleavage systems per family

  enum, bind(c) 
    enumerator :: undefined_ID, &
                  damage_drivingforce_ID
  end enum                                                


  type :: tParameters                                                                                !< container type for internal constitutive parameters
    real(pReal) :: &
      aTol, &
      sdot_0, &
      N
    real(pReal), dimension(:), allocatable :: &
      critDisp, &
      critLoad
    real(pReal), dimension(:,:,:,:), allocatable :: &
      cleavage_systems
    integer :: &
      totalNcleavage
    integer, dimension(:), allocatable :: &
      Ncleavage
    integer(kind(undefined_ID)), allocatable, dimension(:) :: &
      outputID                                                                                      !< ID of each post result output
  end type tParameters

  type(tParameters), dimension(:), allocatable :: param                                             !< containers of constitutive parameters (len Ninstance)


  public :: &
    source_damage_anisoBrittle_init, &
    source_damage_anisoBrittle_dotState, &
    source_damage_anisobrittle_getRateAndItsTangent, &
    source_damage_anisoBrittle_results

contains


!--------------------------------------------------------------------------------------------------
!> @brief module initialization
!> @details reads in material parameters, allocates arrays, and does sanity checks
!--------------------------------------------------------------------------------------------------
subroutine source_damage_anisoBrittle_init

  integer :: Ninstance,phase,instance,source,sourceOffset
  integer :: NofMyPhase,p   ,i
  integer(kind(undefined_ID)) :: &
    outputID

  character(len=pStringLen) :: &
    extmsg = ''
  character(len=65536), dimension(:), allocatable :: &
    outputs

  write(6,'(/,a)')   ' <<<+-  source_'//SOURCE_DAMAGE_ANISOBRITTLE_LABEL//' init  -+>>>'; flush(6)

  Ninstance = count(phase_source == SOURCE_damage_anisoBrittle_ID)
  if (Ninstance == 0) return
  
  if (iand(debug_level(debug_constitutive),debug_levelBasic) /= 0) &
    write(6,'(a16,1x,i5,/)') '# instances:',Ninstance
  
  allocate(source_damage_anisoBrittle_offset(material_Nphase), source=0)
  allocate(source_damage_anisoBrittle_instance(material_Nphase), source=0)
  do phase = 1, material_Nphase
    source_damage_anisoBrittle_instance(phase) = count(phase_source(:,1:phase) == source_damage_anisoBrittle_ID)
    do source = 1, phase_Nsources(phase)
      if (phase_source(source,phase) == source_damage_anisoBrittle_ID) &
        source_damage_anisoBrittle_offset(phase) = source
    enddo    
  enddo
  
  allocate(source_damage_anisoBrittle_Ncleavage(lattice_maxNcleavageFamily,Ninstance), source=0)

  allocate(param(Ninstance))
  
  do p=1, size(config_phase)
    if (all(phase_source(:,p) /= SOURCE_DAMAGE_ANISOBRITTLE_ID)) cycle
    associate(prm => param(source_damage_anisoBrittle_instance(p)), &
              config => config_phase(p))
              
    prm%aTol      = config%getFloat('anisobrittle_atol',defaultVal = 1.0e-3_pReal)

    prm%N         = config%getFloat('anisobrittle_ratesensitivity')
    prm%sdot_0    = config%getFloat('anisobrittle_sdot0')
    
    ! sanity checks
    if (prm%aTol      < 0.0_pReal) extmsg = trim(extmsg)//' anisobrittle_atol'
    
    if (prm%N        <= 0.0_pReal) extmsg = trim(extmsg)//' anisobrittle_ratesensitivity'
    if (prm%sdot_0   <= 0.0_pReal) extmsg = trim(extmsg)//' anisobrittle_sdot0'
    
    prm%Ncleavage = config%getInts('ncleavage',defaultVal=emptyIntArray)

    prm%critDisp = config%getFloats('anisobrittle_criticaldisplacement',requiredSize=size(prm%Ncleavage))
    prm%critLoad = config%getFloats('anisobrittle_criticalload',        requiredSize=size(prm%Ncleavage))
    
    prm%cleavage_systems  = lattice_SchmidMatrix_cleavage (prm%Ncleavage,config%getString('lattice_structure'),&
                                                     config%getFloat('c/a',defaultVal=0.0_pReal))

      ! expand: family => system
      prm%critDisp  = math_expand(prm%critDisp, prm%Ncleavage)
      prm%critLoad  = math_expand(prm%critLoad, prm%Ncleavage)
      
      if (any(prm%critLoad < 0.0_pReal))     extmsg = trim(extmsg)//' anisobrittle_criticalload'
     if (any(prm%critDisp < 0.0_pReal))     extmsg = trim(extmsg)//' anisobrittle_criticaldisplacement'  
!--------------------------------------------------------------------------------------------------
!  exit if any parameter is out of range
    if (extmsg /= '') &
      call IO_error(211,ext_msg=trim(extmsg)//'('//SOURCE_DAMAGE_ANISOBRITTLE_LABEL//')')

!--------------------------------------------------------------------------------------------------
!  output pararameters
    outputs = config%getStrings('(output)',defaultVal=emptyStringArray)
    allocate(prm%outputID(0))
    do i=1, size(outputs)
      outputID = undefined_ID
      select case(outputs(i))
      
        case ('anisobrittle_drivingforce')
          prm%outputID = [prm%outputID, damage_drivingforce_ID]

      end select

    enddo

    end associate
    
    phase = p
    NofMyPhase=count(material_phaseAt==phase) * discretization_nIP
    instance = source_damage_anisoBrittle_instance(phase)
    sourceOffset = source_damage_anisoBrittle_offset(phase)


    call material_allocateSourceState(phase,sourceOffset,NofMyPhase,1,1,0)
    sourceState(phase)%p(sourceOffset)%aTolState=param(instance)%aTol


    source_damage_anisoBrittle_Ncleavage(1:size(param(instance)%Ncleavage),instance) = param(instance)%Ncleavage
  enddo

end subroutine source_damage_anisoBrittle_init


!--------------------------------------------------------------------------------------------------
!> @brief calculates derived quantities from state
!--------------------------------------------------------------------------------------------------
subroutine source_damage_anisoBrittle_dotState(S, ipc, ip, el)

  integer, intent(in) :: &
    ipc, &                                                                                          !< component-ID of integration point
    ip, &                                                                                           !< integration point
    el                                                                                              !< element
  real(pReal),  intent(in), dimension(3,3) :: &
    S
  integer :: &
    phase, &
    constituent, &
    instance, &
    sourceOffset, &
    damageOffset, &
    homog, &
    f, i, index_myFamily, index
  real(pReal) :: &
    traction_d, traction_t, traction_n, traction_crit

  phase = material_phaseAt(ipc,el)
  constituent = material_phasememberAt(ipc,ip,el)
  instance = source_damage_anisoBrittle_instance(phase)
  sourceOffset = source_damage_anisoBrittle_offset(phase)
  homog = material_homogenizationAt(el)
  damageOffset = damageMapping(homog)%p(ip,el)
  
  sourceState(phase)%p(sourceOffset)%dotState(1,constituent) = 0.0_pReal
  
  index = 1
  do f = 1,lattice_maxNcleavageFamily
    index_myFamily = sum(lattice_NcleavageSystem(1:f-1,phase))                                      ! at which index starts my family
    do i = 1,source_damage_anisoBrittle_Ncleavage(f,instance)                                       ! process each (active) cleavage system in family

      traction_d    = math_mul33xx33(S,lattice_Scleavage(1:3,1:3,1,index_myFamily+i,phase))
      traction_t    = math_mul33xx33(S,lattice_Scleavage(1:3,1:3,2,index_myFamily+i,phase))
      traction_n    = math_mul33xx33(S,lattice_Scleavage(1:3,1:3,3,index_myFamily+i,phase))
      
      traction_crit = param(instance)%critLoad(index)* &
                      damage(homog)%p(damageOffset)*damage(homog)%p(damageOffset)

      sourceState(phase)%p(sourceOffset)%dotState(1,constituent) = &
        sourceState(phase)%p(sourceOffset)%dotState(1,constituent) + &
        param(instance)%sdot_0* &
        ((max(0.0_pReal, abs(traction_d) - traction_crit)/traction_crit)**param(instance)%N + &
         (max(0.0_pReal, abs(traction_t) - traction_crit)/traction_crit)**param(instance)%N + &
         (max(0.0_pReal, abs(traction_n) - traction_crit)/traction_crit)**param(instance)%N)/ &
        param(instance)%critDisp(index)

    index = index + 1
    enddo
  enddo

end subroutine source_damage_anisoBrittle_dotState


!--------------------------------------------------------------------------------------------------
!> @brief returns local part of nonlocal damage driving force
!--------------------------------------------------------------------------------------------------
subroutine source_damage_anisobrittle_getRateAndItsTangent(localphiDot, dLocalphiDot_dPhi, phi, phase, constituent)

  integer, intent(in) :: &
    phase, &
    constituent
  real(pReal),  intent(in) :: &
    phi
  real(pReal),  intent(out) :: &
    localphiDot, &
    dLocalphiDot_dPhi
  integer :: &
    sourceOffset

  sourceOffset = source_damage_anisoBrittle_offset(phase)
  
  localphiDot = 1.0_pReal &
              - sourceState(phase)%p(sourceOffset)%state(1,constituent)*phi
  
  dLocalphiDot_dPhi = -sourceState(phase)%p(sourceOffset)%state(1,constituent)
 
end subroutine source_damage_anisoBrittle_getRateAndItsTangent


!--------------------------------------------------------------------------------------------------
!> @brief writes results to HDF5 output file
!--------------------------------------------------------------------------------------------------
subroutine source_damage_anisoBrittle_results(phase,group)

  integer, intent(in) :: phase
  character(len=*), intent(in) :: group 
  integer :: sourceOffset, o, instance
   
  instance     = source_damage_anisoBrittle_instance(phase)
  sourceOffset = source_damage_anisoBrittle_offset(phase)

   associate(prm => param(instance), stt => sourceState(phase)%p(sourceOffset)%state)
   outputsLoop: do o = 1,size(prm%outputID)
     select case(prm%outputID(o))
       case (damage_drivingforce_ID)
         call results_writeDataset(group,stt,'tbd','driving force','tbd')
     end select
   enddo outputsLoop
   end associate

end subroutine source_damage_anisoBrittle_results

end module source_damage_anisoBrittle
