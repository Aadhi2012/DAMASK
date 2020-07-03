!--------------------------------------------------------------------------------------------------
!> @author Franz Roters, Max-Planck-Institut für Eisenforschung GmbH
!> @author Philip Eisenlohr, Max-Planck-Institut für Eisenforschung GmbH
!> @brief elasticity, plasticity, internal microstructure state
!--------------------------------------------------------------------------------------------------
module constitutive
  use prec
  use math
  use rotations
  use debug
  use numerics
  use IO
  use config
  use material
  use results
  use lattice
  use discretization
  use geometry_plastic_nonlocal
  use source_thermal_dissipation
  use source_thermal_externalheat
  use source_damage_isoBrittle
  use source_damage_isoDuctile
  use source_damage_anisoBrittle
  use source_damage_anisoDuctile
  use kinematics_cleavage_opening
  use kinematics_slipplane_opening
  use kinematics_thermal_expansion

  implicit none
  private

  integer, public, protected :: &
    constitutive_plasticity_maxSizeDotState, &
    constitutive_source_maxSizeDotState

  interface

    module subroutine plastic_none_init
    end subroutine plastic_none_init

    module subroutine plastic_isotropic_init
    end subroutine plastic_isotropic_init

    module subroutine plastic_phenopowerlaw_init
    end subroutine plastic_phenopowerlaw_init

    module subroutine plastic_kinehardening_init
    end subroutine plastic_kinehardening_init

    module subroutine plastic_dislotwin_init
    end subroutine plastic_dislotwin_init

    module subroutine plastic_disloUCLA_init
    end subroutine plastic_disloUCLA_init

    module subroutine plastic_nonlocal_init
    end subroutine plastic_nonlocal_init


    module subroutine plastic_isotropic_LpAndItsTangent(Lp,dLp_dMp,Mp,instance,of)
      real(pReal), dimension(3,3),     intent(out) :: &
        Lp                                                                                          !< plastic velocity gradient
      real(pReal), dimension(3,3,3,3), intent(out) :: &
        dLp_dMp                                                                                     !< derivative of Lp with respect to the Mandel stress

      real(pReal), dimension(3,3),     intent(in) :: &
        Mp                                                                                          !< Mandel stress
      integer,                         intent(in) :: &
        instance, &
        of
    end subroutine plastic_isotropic_LpAndItsTangent

    pure module subroutine plastic_phenopowerlaw_LpAndItsTangent(Lp,dLp_dMp,Mp,instance,of)
      real(pReal), dimension(3,3),     intent(out) :: &
        Lp                                                                                          !< plastic velocity gradient
      real(pReal), dimension(3,3,3,3), intent(out) :: &
        dLp_dMp                                                                                     !< derivative of Lp with respect to the Mandel stress

      real(pReal), dimension(3,3),     intent(in) :: &
        Mp                                                                                          !< Mandel stress
      integer,                         intent(in) :: &
        instance, &
        of
    end subroutine plastic_phenopowerlaw_LpAndItsTangent

    pure module subroutine plastic_kinehardening_LpAndItsTangent(Lp,dLp_dMp,Mp,instance,of)
      real(pReal), dimension(3,3),     intent(out) :: &
        Lp                                                                                          !< plastic velocity gradient
      real(pReal), dimension(3,3,3,3), intent(out) :: &
        dLp_dMp                                                                                     !< derivative of Lp with respect to the Mandel stress

      real(pReal), dimension(3,3),     intent(in) :: &
        Mp                                                                                          !< Mandel stress
      integer,                         intent(in) :: &
        instance, &
        of
    end subroutine plastic_kinehardening_LpAndItsTangent

    module subroutine plastic_dislotwin_LpAndItsTangent(Lp,dLp_dMp,Mp,T,instance,of)
      real(pReal), dimension(3,3),     intent(out) :: &
        Lp                                                                                          !< plastic velocity gradient
      real(pReal), dimension(3,3,3,3), intent(out) :: &
        dLp_dMp                                                                                     !< derivative of Lp with respect to the Mandel stress

      real(pReal), dimension(3,3),     intent(in) :: &
        Mp                                                                                          !< Mandel stress
      real(pReal),                     intent(in) :: &
        T
      integer,                         intent(in) :: &
        instance, &
        of
    end subroutine plastic_dislotwin_LpAndItsTangent

    pure module subroutine plastic_disloUCLA_LpAndItsTangent(Lp,dLp_dMp,Mp,T,instance,of)
      real(pReal), dimension(3,3),     intent(out) :: &
        Lp                                                                                          !< plastic velocity gradient
      real(pReal), dimension(3,3,3,3), intent(out) :: &
        dLp_dMp                                                                                     !< derivative of Lp with respect to the Mandel stress

      real(pReal), dimension(3,3),     intent(in) :: &
        Mp                                                                                          !< Mandel stress
      real(pReal),                     intent(in) :: &
        T
      integer,                         intent(in) :: &
        instance, &
        of
    end subroutine plastic_disloUCLA_LpAndItsTangent

    module subroutine plastic_nonlocal_LpAndItsTangent(Lp,dLp_dMp, &
                                                       Mp,Temperature,instance,of,ip,el)
      real(pReal), dimension(3,3),     intent(out) :: &
        Lp                                                                                          !< plastic velocity gradient
      real(pReal), dimension(3,3,3,3), intent(out) :: &
        dLp_dMp                                                                                     !< derivative of Lp with respect to the Mandel stress

      real(pReal), dimension(3,3),     intent(in) :: &
        Mp                                                                                          !< Mandel stress
      real(pReal),                     intent(in) :: &
        Temperature
      integer,                         intent(in) :: &
        instance, &
        of, &
        ip, &                                                                                       !< current integration point
        el                                                                                          !< current element number
    end subroutine plastic_nonlocal_LpAndItsTangent


    module subroutine plastic_isotropic_LiAndItsTangent(Li,dLi_dMi,Mi,instance,of)
      real(pReal), dimension(3,3),     intent(out) :: &
        Li                                                                                          !< inleastic velocity gradient
      real(pReal), dimension(3,3,3,3), intent(out)  :: &
        dLi_dMi                                                                                     !< derivative of Li with respect to Mandel stress

      real(pReal), dimension(3,3),     intent(in) :: &
        Mi                                                                                          !< Mandel stress
      integer,                         intent(in) :: &
        instance, &
        of
    end subroutine plastic_isotropic_LiAndItsTangent


    module subroutine plastic_isotropic_dotState(Mp,instance,of)
      real(pReal), dimension(3,3),  intent(in) :: &
        Mp                                                                                          !< Mandel stress
      integer,                      intent(in) :: &
        instance, &
        of
    end subroutine plastic_isotropic_dotState

    module subroutine plastic_phenopowerlaw_dotState(Mp,instance,of)
      real(pReal), dimension(3,3),  intent(in) :: &
        Mp                                                                                          !< Mandel stress
      integer,                      intent(in) :: &
        instance, &
        of
    end subroutine plastic_phenopowerlaw_dotState

    module subroutine plastic_kinehardening_dotState(Mp,instance,of)
      real(pReal), dimension(3,3),  intent(in) :: &
        Mp                                                                                          !< Mandel stress
      integer,                      intent(in) :: &
        instance, &
        of
    end subroutine plastic_kinehardening_dotState

    module subroutine plastic_dislotwin_dotState(Mp,T,instance,of)
      real(pReal), dimension(3,3),  intent(in) :: &
        Mp                                                                                          !< Mandel stress
      real(pReal),                  intent(in) :: &
        T
      integer,                      intent(in) :: &
        instance, &
        of
    end subroutine plastic_dislotwin_dotState

    module subroutine plastic_disloUCLA_dotState(Mp,T,instance,of)
      real(pReal), dimension(3,3),  intent(in) :: &
        Mp                                                                                          !< Mandel stress
      real(pReal),                  intent(in) :: &
        T
      integer,                      intent(in) :: &
        instance, &
        of
    end subroutine plastic_disloUCLA_dotState

    module subroutine plastic_nonlocal_dotState(Mp, F, Fp, Temperature,timestep, &
                                                instance,of,ip,el)
      real(pReal), dimension(3,3), intent(in) ::&
        Mp                                                                                          !< MandelStress
      real(pReal), dimension(3,3,homogenization_maxNgrains,discretization_nIP,discretization_nElem), intent(in) :: &
        F, &                                                                                        !< deformation gradient
        Fp                                                                                          !< plastic deformation gradient
      real(pReal), intent(in) :: &
        Temperature, &                                                                              !< temperature
        timestep                                                                                    !< substepped crystallite time increment
      integer, intent(in) :: &
        instance, &
        of, &
        ip, &                                                                                       !< current integration point
        el                                                                                          !< current element number
    end subroutine plastic_nonlocal_dotState


    module subroutine plastic_dislotwin_dependentState(T,instance,of)
      integer,       intent(in) :: &
        instance, &
        of
      real(pReal),   intent(in) :: &
        T
    end subroutine plastic_dislotwin_dependentState

    module subroutine plastic_disloUCLA_dependentState(instance,of)
      integer,       intent(in) :: &
        instance, &
        of
    end subroutine plastic_disloUCLA_dependentState

    module subroutine plastic_nonlocal_dependentState(F, Fp, instance, of, ip, el)
      real(pReal), dimension(3,3), intent(in) :: &
        F, &
        Fp
      integer, intent(in) :: &
        instance, &
        of, &
        ip, &
        el
    end subroutine plastic_nonlocal_dependentState


    module subroutine plastic_kinehardening_deltaState(Mp,instance,of)
      real(pReal), dimension(3,3),  intent(in) :: &
        Mp                                                                                          !< Mandel stress
      integer,                      intent(in) :: &
        instance, &
        of
    end subroutine plastic_kinehardening_deltaState

    module subroutine plastic_nonlocal_deltaState(Mp,instance,of,ip,el)
      real(pReal), dimension(3,3), intent(in) :: &
        Mp
      integer, intent(in) :: &
        instance, &
        of, &
        ip, &
        el
    end subroutine plastic_nonlocal_deltaState


    module function plastic_dislotwin_homogenizedC(ipc,ip,el) result(homogenizedC)
      real(pReal), dimension(6,6) :: &
        homogenizedC
      integer,     intent(in) :: &
        ipc, &                                                                                      !< component-ID of integration point
        ip, &                                                                                       !< integration point
        el                                                                                          !< element
    end function plastic_dislotwin_homogenizedC

    module subroutine plastic_nonlocal_updateCompatibility(orientation,instance,i,e)
      integer, intent(in) :: &
        instance, &
        i, &
        e
      type(rotation), dimension(1,discretization_nIP,discretization_nElem), intent(in) :: &
        orientation                                                                                 !< crystal orientation
    end subroutine plastic_nonlocal_updateCompatibility


    module subroutine plastic_isotropic_results(instance,group)
      integer,          intent(in) :: instance
      character(len=*), intent(in) :: group
    end subroutine plastic_isotropic_results

    module subroutine plastic_phenopowerlaw_results(instance,group)
      integer,          intent(in) :: instance
      character(len=*), intent(in) :: group
    end subroutine plastic_phenopowerlaw_results

    module subroutine plastic_kinehardening_results(instance,group)
      integer,          intent(in) :: instance
      character(len=*), intent(in) :: group
    end subroutine plastic_kinehardening_results

    module subroutine plastic_dislotwin_results(instance,group)
      integer,          intent(in) :: instance
      character(len=*), intent(in) :: group
    end subroutine plastic_dislotwin_results

    module subroutine plastic_disloUCLA_results(instance,group)
      integer,          intent(in) :: instance
      character(len=*), intent(in) :: group
    end subroutine plastic_disloUCLA_results

    module subroutine plastic_nonlocal_results(instance,group)
      integer,          intent(in) :: instance
      character(len=*), intent(in) :: group
    end subroutine plastic_nonlocal_results

  end interface


  type :: tDebugOptions
    logical :: &
      basic, &
      extensive, &
      selective
    integer :: &
      element, &
      ip, &
      grain
  end type tDebugOptions

  type(tDebugOptions) :: debugConstitutive
  
  public :: &
    plastic_nonlocal_updateCompatibility, &
    constitutive_init, &
    constitutive_homogenizedC, &
    constitutive_dependentState, &
    constitutive_LpAndItsTangents, &
    constitutive_LiAndItsTangents, &
    constitutive_initialFi, &
    constitutive_SandItsTangents, &
    constitutive_collectDotState, &
    constitutive_deltaState, &
    constitutive_results

contains


!--------------------------------------------------------------------------------------------------
!> @brief allocates arrays pointing to array of the various constitutive modules
!--------------------------------------------------------------------------------------------------
subroutine constitutive_init

  integer :: &
    ph, &                                                                                           !< counter in phase loop
    s                                                                                               !< counter in source loop
  class (tNode), pointer :: &
    debug_constitutive

  debug_constitutive => debug_root%get('constitutive', defaultVal=emptyList)
  debugConstitutive%basic      =  debug_constitutive%contains('basic') 
  debugConstitutive%extensive  =  debug_constitutive%contains('extensive') 
  debugConstitutive%selective  =  debug_constitutive%contains('selective')
  debugConstitutive%element    =  debug_root%get_asInt('element',defaultVal = 1) 
  debugConstitutive%ip         =  debug_root%get_asInt('integrationpoint',defaultVal = 1) 
  debugConstitutive%grain      =  debug_root%get_asInt('grain',defaultVal = 1)

!--------------------------------------------------------------------------------------------------
! initialized plasticity
  if (any(phase_plasticity == PLASTICITY_NONE_ID))          call plastic_none_init
  if (any(phase_plasticity == PLASTICITY_ISOTROPIC_ID))     call plastic_isotropic_init
  if (any(phase_plasticity == PLASTICITY_PHENOPOWERLAW_ID)) call plastic_phenopowerlaw_init
  if (any(phase_plasticity == PLASTICITY_KINEHARDENING_ID)) call plastic_kinehardening_init
  if (any(phase_plasticity == PLASTICITY_DISLOTWIN_ID))     call plastic_dislotwin_init
  if (any(phase_plasticity == PLASTICITY_DISLOUCLA_ID))     call plastic_disloucla_init
  if (any(phase_plasticity == PLASTICITY_NONLOCAL_ID)) then
    call plastic_nonlocal_init
  else
    call geometry_plastic_nonlocal_disable
  endif
!--------------------------------------------------------------------------------------------------
! initialize source mechanisms
  if (any(phase_source == SOURCE_thermal_dissipation_ID))     call source_thermal_dissipation_init
  if (any(phase_source == SOURCE_thermal_externalheat_ID))    call source_thermal_externalheat_init
  if (any(phase_source == SOURCE_damage_isoBrittle_ID))       call source_damage_isoBrittle_init
  if (any(phase_source == SOURCE_damage_isoDuctile_ID))       call source_damage_isoDuctile_init
  if (any(phase_source == SOURCE_damage_anisoBrittle_ID))     call source_damage_anisoBrittle_init
  if (any(phase_source == SOURCE_damage_anisoDuctile_ID))     call source_damage_anisoDuctile_init

!--------------------------------------------------------------------------------------------------
! initialize kinematic mechanisms
  if (any(phase_kinematics == KINEMATICS_cleavage_opening_ID))  call kinematics_cleavage_opening_init
  if (any(phase_kinematics == KINEMATICS_slipplane_opening_ID)) call kinematics_slipplane_opening_init
  if (any(phase_kinematics == KINEMATICS_thermal_expansion_ID)) call kinematics_thermal_expansion_init

  write(6,'(/,a)')   ' <<<+-  constitutive init  -+>>>'; flush(6)

  constitutive_source_maxSizeDotState = 0
  PhaseLoop2:do ph = 1,material_Nphase
!--------------------------------------------------------------------------------------------------
! partition and initialize state
    plasticState(ph)%partionedState0 = plasticState(ph)%state0
    plasticState(ph)%state           = plasticState(ph)%partionedState0
    forall(s = 1:phase_Nsources(ph))
      sourceState(ph)%p(s)%partionedState0 = sourceState(ph)%p(s)%state0
      sourceState(ph)%p(s)%state           = sourceState(ph)%p(s)%partionedState0
    end forall
!--------------------------------------------------------------------------------------------------
! determine max size of source state
    constitutive_source_maxSizeDotState   = max(constitutive_source_maxSizeDotState, &
                                                maxval(sourceState(ph)%p%sizeDotState))
  enddo PhaseLoop2
  constitutive_plasticity_maxSizeDotState = maxval(plasticState%sizeDotState)

end subroutine constitutive_init


!--------------------------------------------------------------------------------------------------
!> @brief returns the homogenize elasticity matrix
!> ToDo: homogenizedC66 would be more consistent
!--------------------------------------------------------------------------------------------------
function constitutive_homogenizedC(ipc,ip,el)

  real(pReal), dimension(6,6) :: constitutive_homogenizedC
  integer, intent(in) :: &
    ipc, &                                                                                          !< component-ID of integration point
    ip, &                                                                                           !< integration point
    el                                                                                              !< element

  plasticityType: select case (phase_plasticity(material_phaseAt(ipc,el)))
    case (PLASTICITY_DISLOTWIN_ID) plasticityType
      constitutive_homogenizedC = plastic_dislotwin_homogenizedC(ipc,ip,el)
    case default plasticityType
      constitutive_homogenizedC = lattice_C66(1:6,1:6,material_phaseAt(ipc,el))
  end select plasticityType

end function constitutive_homogenizedC


!--------------------------------------------------------------------------------------------------
!> @brief calls microstructure function of the different constitutive models
!--------------------------------------------------------------------------------------------------
subroutine constitutive_dependentState(F, Fp, ipc, ip, el)

  integer, intent(in) :: &
    ipc, &                                                                                          !< component-ID of integration point
    ip, &                                                                                           !< integration point
    el                                                                                              !< element
  real(pReal),   intent(in), dimension(3,3) :: &
    F, &                                                                                           !< elastic deformation gradient
    Fp                                                                                              !< plastic deformation gradient
  integer :: &
    ho, &                                                                                           !< homogenization
    tme, &                                                                                          !< thermal member position
    instance, of

  ho  = material_homogenizationAt(el)
  tme = thermalMapping(ho)%p(ip,el)
  of  = material_phasememberAt(ipc,ip,el)
  instance = phase_plasticityInstance(material_phaseAt(ipc,el))

  plasticityType: select case (phase_plasticity(material_phaseAt(ipc,el)))
    case (PLASTICITY_DISLOTWIN_ID) plasticityType
      call plastic_dislotwin_dependentState(temperature(ho)%p(tme),instance,of)
    case (PLASTICITY_DISLOUCLA_ID) plasticityType
      call plastic_disloUCLA_dependentState(instance,of)
    case (PLASTICITY_NONLOCAL_ID) plasticityType
      call plastic_nonlocal_dependentState (F,Fp,instance,of,ip,el)
  end select plasticityType

end subroutine constitutive_dependentState


!--------------------------------------------------------------------------------------------------
!> @brief  contains the constitutive equation for calculating the velocity gradient
! ToDo: Discuss whether it makes sense if crystallite handles the configuration conversion, i.e.
! Mp in, dLp_dMp out
!--------------------------------------------------------------------------------------------------
subroutine constitutive_LpAndItsTangents(Lp, dLp_dS, dLp_dFi, &
                                         S, Fi, ipc, ip, el)
  integer, intent(in) :: &
    ipc, &                                                                                          !< component-ID of integration point
    ip, &                                                                                           !< integration point
    el                                                                                              !< element
  real(pReal),   intent(in),  dimension(3,3) :: &
    S, &                                                                                            !< 2nd Piola-Kirchhoff stress
    Fi                                                                                              !< intermediate deformation gradient
  real(pReal),   intent(out), dimension(3,3) :: &
    Lp                                                                                              !< plastic velocity gradient
  real(pReal),   intent(out), dimension(3,3,3,3) :: &
    dLp_dS, &
    dLp_dFi                                                                                         !< derivative of Lp with respect to Fi
  real(pReal), dimension(3,3,3,3) :: &
    dLp_dMp                                                                                         !< derivative of Lp with respect to Mandel stress
  real(pReal), dimension(3,3) :: &
    Mp                                                                                              !< Mandel stress work conjugate with Lp
  integer :: &
    ho, &                                                                                           !< homogenization
    tme                                                                                             !< thermal member position
  integer :: &
    i, j, instance, of

  ho = material_homogenizationAt(el)
  tme = thermalMapping(ho)%p(ip,el)

  Mp = matmul(matmul(transpose(Fi),Fi),S)
  of = material_phasememberAt(ipc,ip,el)
  instance = phase_plasticityInstance(material_phaseAt(ipc,el))

  plasticityType: select case (phase_plasticity(material_phaseAt(ipc,el)))

    case (PLASTICITY_NONE_ID) plasticityType
      Lp = 0.0_pReal
      dLp_dMp = 0.0_pReal

    case (PLASTICITY_ISOTROPIC_ID) plasticityType
      call plastic_isotropic_LpAndItsTangent   (Lp,dLp_dMp,Mp,instance,of)

    case (PLASTICITY_PHENOPOWERLAW_ID) plasticityType
      call plastic_phenopowerlaw_LpAndItsTangent(Lp,dLp_dMp,Mp,instance,of)

    case (PLASTICITY_KINEHARDENING_ID) plasticityType
      call plastic_kinehardening_LpAndItsTangent(Lp,dLp_dMp,Mp,instance,of)

    case (PLASTICITY_NONLOCAL_ID) plasticityType
      call plastic_nonlocal_LpAndItsTangent     (Lp,dLp_dMp,Mp, temperature(ho)%p(tme),instance,of,ip,el)

    case (PLASTICITY_DISLOTWIN_ID) plasticityType
      call plastic_dislotwin_LpAndItsTangent    (Lp,dLp_dMp,Mp,temperature(ho)%p(tme),instance,of)

    case (PLASTICITY_DISLOUCLA_ID) plasticityType
      call plastic_disloucla_LpAndItsTangent    (Lp,dLp_dMp,Mp,temperature(ho)%p(tme),instance,of)

  end select plasticityType

  do i=1,3; do j=1,3
    dLp_dFi(i,j,1:3,1:3) = matmul(matmul(Fi,S),transpose(dLp_dMp(i,j,1:3,1:3))) + &
                           matmul(matmul(Fi,dLp_dMp(i,j,1:3,1:3)),S)
    dLp_dS(i,j,1:3,1:3)  = matmul(matmul(transpose(Fi),Fi),dLp_dMp(i,j,1:3,1:3))                     ! ToDo: @PS: why not:   dLp_dMp:(FiT Fi)
  enddo; enddo

end subroutine constitutive_LpAndItsTangents


!--------------------------------------------------------------------------------------------------
!> @brief  contains the constitutive equation for calculating the velocity gradient
! ToDo: MD: S is Mi?
!--------------------------------------------------------------------------------------------------
subroutine constitutive_LiAndItsTangents(Li, dLi_dS, dLi_dFi, &
                                         S, Fi, ipc, ip, el)

  integer, intent(in) :: &
    ipc, &                                                                                          !< component-ID of integration point
    ip, &                                                                                           !< integration point
    el                                                                                              !< element
  real(pReal),   intent(in),  dimension(3,3) :: &
    S                                                                                               !< 2nd Piola-Kirchhoff stress
  real(pReal),   intent(in),  dimension(3,3) :: &
    Fi                                                                                              !< intermediate deformation gradient
  real(pReal),   intent(out), dimension(3,3) :: &
    Li                                                                                              !< intermediate velocity gradient
  real(pReal),   intent(out), dimension(3,3,3,3) :: &
    dLi_dS, &                                                                                       !< derivative of Li with respect to S
    dLi_dFi

  real(pReal), dimension(3,3) :: &
    my_Li, &                                                                                        !< intermediate velocity gradient
    FiInv, &
    temp_33
  real(pReal), dimension(3,3,3,3) :: &
    my_dLi_dS
  real(pReal) :: &
    detFi
  integer :: &
    k, i, j, &
    instance, of

  Li = 0.0_pReal
  dLi_dS  = 0.0_pReal
  dLi_dFi = 0.0_pReal

  plasticityType: select case (phase_plasticity(material_phaseAt(ipc,el)))
    case (PLASTICITY_isotropic_ID) plasticityType
      of = material_phasememberAt(ipc,ip,el)
      instance = phase_plasticityInstance(material_phaseAt(ipc,el))
      call plastic_isotropic_LiAndItsTangent(my_Li, my_dLi_dS, S ,instance,of)
    case default plasticityType
      my_Li = 0.0_pReal
      my_dLi_dS = 0.0_pReal
  end select plasticityType

  Li = Li + my_Li
  dLi_dS = dLi_dS + my_dLi_dS

  KinematicsLoop: do k = 1, phase_Nkinematics(material_phaseAt(ipc,el))
    kinematicsType: select case (phase_kinematics(k,material_phaseAt(ipc,el)))
      case (KINEMATICS_cleavage_opening_ID) kinematicsType
        call kinematics_cleavage_opening_LiAndItsTangent(my_Li, my_dLi_dS, S, ipc, ip, el)
      case (KINEMATICS_slipplane_opening_ID) kinematicsType
        call kinematics_slipplane_opening_LiAndItsTangent(my_Li, my_dLi_dS, S, ipc, ip, el)
      case (KINEMATICS_thermal_expansion_ID) kinematicsType
        call kinematics_thermal_expansion_LiAndItsTangent(my_Li, my_dLi_dS, ipc, ip, el)
      case default kinematicsType
        my_Li = 0.0_pReal
        my_dLi_dS = 0.0_pReal
    end select kinematicsType
    Li = Li + my_Li
    dLi_dS = dLi_dS + my_dLi_dS
  enddo KinematicsLoop

  FiInv = math_inv33(Fi)
  detFi = math_det33(Fi)
  Li = matmul(matmul(Fi,Li),FiInv)*detFi                                                            !< push forward to intermediate configuration
  temp_33 = matmul(FiInv,Li)

  do i = 1,3; do j = 1,3
    dLi_dS(1:3,1:3,i,j)  = matmul(matmul(Fi,dLi_dS(1:3,1:3,i,j)),FiInv)*detFi
    dLi_dFi(1:3,1:3,i,j) = dLi_dFi(1:3,1:3,i,j) + Li*FiInv(j,i)
    dLi_dFi(1:3,i,1:3,j) = dLi_dFi(1:3,i,1:3,j) + math_I3*temp_33(j,i) + Li*FiInv(j,i)
  enddo; enddo

end subroutine constitutive_LiAndItsTangents


!--------------------------------------------------------------------------------------------------
!> @brief  collects initial intermediate deformation gradient
!--------------------------------------------------------------------------------------------------
pure function constitutive_initialFi(ipc, ip, el)

  integer, intent(in) :: &
    ipc, &                                                                                          !< component-ID of integration point
    ip, &                                                                                           !< integration point
    el                                                                                              !< element
  real(pReal), dimension(3,3) :: &
    constitutive_initialFi                                                                          !< composite initial intermediate deformation gradient
  integer :: &
    k                                                                                               !< counter in kinematics loop
  integer :: &
    phase, &
    homog, offset

  constitutive_initialFi = math_I3
  phase = material_phaseAt(ipc,el)

  KinematicsLoop: do k = 1, phase_Nkinematics(phase)                                                !< Warning: small initial strain assumption
    kinematicsType: select case (phase_kinematics(k,phase))
      case (KINEMATICS_thermal_expansion_ID) kinematicsType
        homog = material_homogenizationAt(el)
        offset = thermalMapping(homog)%p(ip,el)
        constitutive_initialFi = &
          constitutive_initialFi + kinematics_thermal_expansion_initialStrain(homog,phase,offset)
    end select kinematicsType
  enddo KinematicsLoop

end function constitutive_initialFi


!--------------------------------------------------------------------------------------------------
!> @brief returns the 2nd Piola-Kirchhoff stress tensor and its tangent with respect to
!> the elastic/intermediate deformation gradients depending on the selected elastic law
!! (so far no case switch because only Hooke is implemented)
!--------------------------------------------------------------------------------------------------
subroutine constitutive_SandItsTangents(S, dS_dFe, dS_dFi, Fe, Fi, ipc, ip, el)

  integer, intent(in) :: &
    ipc, &                                                                                          !< component-ID of integration point
    ip, &                                                                                           !< integration point
    el                                                                                              !< element
  real(pReal),   intent(in),  dimension(3,3) :: &
    Fe, &                                                                                           !< elastic deformation gradient
    Fi                                                                                              !< intermediate deformation gradient
  real(pReal),   intent(out), dimension(3,3) :: &
    S                                                                                               !< 2nd Piola-Kirchhoff stress tensor
  real(pReal),   intent(out), dimension(3,3,3,3) :: &
    dS_dFe, &                                                                                       !< derivative of 2nd P-K stress with respect to elastic deformation gradient
    dS_dFi                                                                                          !< derivative of 2nd P-K stress with respect to intermediate deformation gradient

  call constitutive_hooke_SandItsTangents(S, dS_dFe, dS_dFi, Fe, Fi, ipc, ip, el)


end subroutine constitutive_SandItsTangents


!--------------------------------------------------------------------------------------------------
!> @brief returns the 2nd Piola-Kirchhoff stress tensor and its tangent with respect to
!> the elastic and intermediate deformation gradients using Hooke's law
!--------------------------------------------------------------------------------------------------
subroutine constitutive_hooke_SandItsTangents(S, dS_dFe, dS_dFi, &
                                              Fe, Fi, ipc, ip, el)

  integer, intent(in) :: &
    ipc, &                                                                                          !< component-ID of integration point
    ip, &                                                                                           !< integration point
    el                                                                                              !< element
  real(pReal),   intent(in),  dimension(3,3) :: &
    Fe, &                                                                                           !< elastic deformation gradient
    Fi                                                                                              !< intermediate deformation gradient
  real(pReal),   intent(out), dimension(3,3) :: &
    S                                                                                               !< 2nd Piola-Kirchhoff stress tensor in lattice configuration
  real(pReal),   intent(out), dimension(3,3,3,3) :: &
    dS_dFe, &                                                                                       !< derivative of 2nd P-K stress with respect to elastic deformation gradient
    dS_dFi                                                                                          !< derivative of 2nd P-K stress with respect to intermediate deformation gradient
  real(pReal), dimension(3,3) :: E
  real(pReal), dimension(3,3,3,3) :: C
  integer :: &
    ho, &                                                                                           !< homogenization
    d                                                                                               !< counter in degradation loop
  integer :: &
    i, j

  ho = material_homogenizationAt(el)
  C = math_66toSym3333(constitutive_homogenizedC(ipc,ip,el))

  DegradationLoop: do d = 1, phase_NstiffnessDegradations(material_phaseAt(ipc,el))
    degradationType: select case(phase_stiffnessDegradation(d,material_phaseAt(ipc,el)))
      case (STIFFNESS_DEGRADATION_damage_ID) degradationType
        C = C * damage(ho)%p(damageMapping(ho)%p(ip,el))**2
    end select degradationType
  enddo DegradationLoop

  E = 0.5_pReal*(matmul(transpose(Fe),Fe)-math_I3)                                                  !< Green-Lagrange strain in unloaded configuration
  S = math_mul3333xx33(C,matmul(matmul(transpose(Fi),E),Fi))                                        !< 2PK stress in lattice configuration in work conjugate with GL strain pulled back to lattice configuration

  do i =1, 3;do j=1,3
    dS_dFe(i,j,1:3,1:3) = matmul(Fe,matmul(matmul(Fi,C(i,j,1:3,1:3)),transpose(Fi)))                !< dS_ij/dFe_kl = C_ijmn * Fi_lm * Fi_on * Fe_ko
    dS_dFi(i,j,1:3,1:3) = 2.0_pReal*matmul(matmul(E,Fi),C(i,j,1:3,1:3))                             !< dS_ij/dFi_kl = C_ijln * E_km * Fe_mn
  enddo; enddo

end subroutine constitutive_hooke_SandItsTangents


!--------------------------------------------------------------------------------------------------
!> @brief contains the constitutive equation for calculating the rate of change of microstructure
!--------------------------------------------------------------------------------------------------
function constitutive_collectDotState(S, FArray, Fi, FpArray, subdt, ipc, ip, el,phase,of) result(broken)

  integer, intent(in) :: &
    ipc, &                                                                                          !< component-ID of integration point
    ip, &                                                                                           !< integration point
    el, &                                                                                              !< element
    phase, &
    of
  real(pReal),  intent(in) :: &
    subdt                                                                                           !< timestep
  real(pReal),  intent(in), dimension(3,3,homogenization_maxNgrains,discretization_nIP,discretization_nElem) :: &
    FArray, &                                                                                       !< elastic deformation gradient
    FpArray                                                                                         !< plastic deformation gradient
  real(pReal),  intent(in), dimension(3,3) :: &
    Fi                                                                                              !< intermediate deformation gradient
  real(pReal),  intent(in), dimension(3,3) :: &
    S                                                                                               !< 2nd Piola Kirchhoff stress (vector notation)
  real(pReal),              dimension(3,3) :: &
    Mp
  integer :: &
    ho, &                                                                                           !< homogenization
    tme, &                                                                                          !< thermal member position
    i, &                                                                                            !< counter in source loop
    instance
  logical :: broken

  ho = material_homogenizationAt(el)
  tme = thermalMapping(ho)%p(ip,el)
  instance = phase_plasticityInstance(phase)

  Mp = matmul(matmul(transpose(Fi),Fi),S)

  plasticityType: select case (phase_plasticity(phase))

    case (PLASTICITY_ISOTROPIC_ID) plasticityType
      call plastic_isotropic_dotState    (Mp,instance,of)

    case (PLASTICITY_PHENOPOWERLAW_ID) plasticityType
      call plastic_phenopowerlaw_dotState(Mp,instance,of)

    case (PLASTICITY_KINEHARDENING_ID) plasticityType
      call plastic_kinehardening_dotState(Mp,instance,of)

    case (PLASTICITY_DISLOTWIN_ID) plasticityType
      call plastic_dislotwin_dotState    (Mp,temperature(ho)%p(tme),instance,of)

    case (PLASTICITY_DISLOUCLA_ID) plasticityType
      call plastic_disloucla_dotState    (Mp,temperature(ho)%p(tme),instance,of)

    case (PLASTICITY_NONLOCAL_ID) plasticityType
      call plastic_nonlocal_dotState     (Mp,FArray,FpArray,temperature(ho)%p(tme),subdt, &
                                          instance,of,ip,el)
  end select plasticityType
  broken = any(IEEE_is_NaN(plasticState(phase)%dotState(:,of)))

  SourceLoop: do i = 1, phase_Nsources(phase)

    sourceType: select case (phase_source(i,phase))

      case (SOURCE_damage_anisoBrittle_ID) sourceType
        call source_damage_anisoBrittle_dotState (S, ipc, ip, el) !< correct stress?

      case (SOURCE_damage_isoDuctile_ID) sourceType
        call source_damage_isoDuctile_dotState   (   ipc, ip, el)

      case (SOURCE_damage_anisoDuctile_ID) sourceType
        call source_damage_anisoDuctile_dotState (   ipc, ip, el)

      case (SOURCE_thermal_externalheat_ID) sourceType
        call source_thermal_externalheat_dotState(phase,of)

    end select sourceType

    broken = broken .or. any(IEEE_is_NaN(sourceState(phase)%p(i)%dotState(:,of)))

  enddo SourceLoop

end function constitutive_collectDotState


!--------------------------------------------------------------------------------------------------
!> @brief for constitutive models having an instantaneous change of state
!> will return false if delta state is not needed/supported by the constitutive model
!--------------------------------------------------------------------------------------------------
function constitutive_deltaState(S, Fe, Fi, ipc, ip, el, phase, of) result(broken)

  integer, intent(in) :: &
    ipc, &                                                                                          !< component-ID of integration point
    ip, &                                                                                           !< integration point
    el, &                                                                                           !< element
    phase, &
    of
  real(pReal),   intent(in), dimension(3,3) :: &
    S, &                                                                                            !< 2nd Piola Kirchhoff stress
    Fe, &                                                                                           !< elastic deformation gradient
    Fi                                                                                              !< intermediate deformation gradient
  real(pReal),               dimension(3,3) :: &
    Mp
  integer :: &
    i, &
    instance, &
    myOffset, &
    mySize
  logical :: &
    broken

  Mp  = matmul(matmul(transpose(Fi),Fi),S)
  instance = phase_plasticityInstance(phase)

  plasticityType: select case (phase_plasticity(phase))

    case (PLASTICITY_KINEHARDENING_ID) plasticityType
      call plastic_kinehardening_deltaState(Mp,instance,of)
      broken = any(IEEE_is_NaN(plasticState(phase)%deltaState(:,of)))

    case (PLASTICITY_NONLOCAL_ID) plasticityType
      call plastic_nonlocal_deltaState(Mp,instance,of,ip,el)
      broken = any(IEEE_is_NaN(plasticState(phase)%deltaState(:,of)))

    case default
      broken = .false.

  end select plasticityType

  if(.not. broken) then
    select case(phase_plasticity(phase))
      case (PLASTICITY_NONLOCAL_ID,PLASTICITY_KINEHARDENING_ID)

        myOffset = plasticState(phase)%offsetDeltaState
        mySize   = plasticState(phase)%sizeDeltaState
        plasticState(phase)%state(myOffset + 1:myOffset + mySize,of) = &
        plasticState(phase)%state(myOffset + 1:myOffset + mySize,of) + plasticState(phase)%deltaState(1:mySize,of)
    end select
  endif


  sourceLoop: do i = 1, phase_Nsources(phase)

     sourceType: select case (phase_source(i,phase))

      case (SOURCE_damage_isoBrittle_ID) sourceType
        call source_damage_isoBrittle_deltaState  (constitutive_homogenizedC(ipc,ip,el), Fe, &
                                                   ipc, ip, el)
        broken = broken .or. any(IEEE_is_NaN(sourceState(phase)%p(i)%deltaState(:,of)))
        if(.not. broken) then
          myOffset = sourceState(phase)%p(i)%offsetDeltaState
          mySize   = sourceState(phase)%p(i)%sizeDeltaState
          sourceState(phase)%p(i)%state(myOffset + 1: myOffset + mySize,of) = &
          sourceState(phase)%p(i)%state(myOffset + 1: myOffset + mySize,of) + sourceState(phase)%p(i)%deltaState(1:mySize,of)
        endif

    end select sourceType

  enddo SourceLoop

end function constitutive_deltaState


!--------------------------------------------------------------------------------------------------
!> @brief writes constitutive results to HDF5 output file
!--------------------------------------------------------------------------------------------------
subroutine constitutive_results

  integer :: p
  character(len=pStringLen) :: group
  do p=1,size(config_name_phase)
    group = trim('current/constituent')//'/'//trim(config_name_phase(p))
    call results_closeGroup(results_addGroup(group))

    group = trim(group)//'/plastic'

    call results_closeGroup(results_addGroup(group))
    select case(phase_plasticity(p))

      case(PLASTICITY_ISOTROPIC_ID)
        call plastic_isotropic_results(phase_plasticityInstance(p),group)

      case(PLASTICITY_PHENOPOWERLAW_ID)
        call plastic_phenopowerlaw_results(phase_plasticityInstance(p),group)

      case(PLASTICITY_KINEHARDENING_ID)
        call plastic_kinehardening_results(phase_plasticityInstance(p),group)

      case(PLASTICITY_DISLOTWIN_ID)
        call plastic_dislotwin_results(phase_plasticityInstance(p),group)

      case(PLASTICITY_DISLOUCLA_ID)
        call plastic_disloUCLA_results(phase_plasticityInstance(p),group)

      case(PLASTICITY_NONLOCAL_ID)
        call plastic_nonlocal_results(phase_plasticityInstance(p),group)
    end select

  enddo

end subroutine constitutive_results

end module constitutive
