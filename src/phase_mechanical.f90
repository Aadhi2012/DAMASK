!----------------------------------------------------------------------------------------------------
!> @brief internal microstructure state for all plasticity constitutive models
!----------------------------------------------------------------------------------------------------
submodule(phase) mechanical


  enum, bind(c); enumerator :: &
    ELASTICITY_UNDEFINED_ID, &
    ELASTICITY_HOOKE_ID, &
    STIFFNESS_DEGRADATION_UNDEFINED_ID, &
    STIFFNESS_DEGRADATION_DAMAGE_ID, &
    PLASTICITY_UNDEFINED_ID, &
    PLASTICITY_NONE_ID, &
    PLASTICITY_ISOTROPIC_ID, &
    PLASTICITY_PHENOPOWERLAW_ID, &
    PLASTICITY_KINEHARDENING_ID, &
    PLASTICITY_DISLOTWIN_ID, &
    PLASTICITY_DISLOTUNGSTEN_ID, &
    PLASTICITY_NONLOCAL_ID, &
    KINEMATICS_UNDEFINED_ID, &
    KINEMATICS_CLEAVAGE_OPENING_ID, &
    KINEMATICS_SLIPPLANE_OPENING_ID, &
    KINEMATICS_THERMAL_EXPANSION_ID
  end enum

  integer(kind(ELASTICITY_UNDEFINED_ID)), dimension(:),   allocatable :: &
    phase_elasticity                                                                                !< elasticity of each phase
  integer(kind(STIFFNESS_DEGRADATION_UNDEFINED_ID)),     dimension(:,:), allocatable :: &
    phase_stiffnessDegradation                                                                      !< active stiffness degradation mechanisms of each phase

  type(tTensorContainer), dimension(:), allocatable :: &
    ! current value
    phase_mechanical_Fe, &
    phase_mechanical_Fi, &
    phase_mechanical_Fp, &
    phase_mechanical_F, &
    phase_mechanical_Li, &
    phase_mechanical_Lp, &
    phase_mechanical_S, &
    phase_mechanical_P, &
    ! converged value at end of last solver increment
    phase_mechanical_Fi0, &
    phase_mechanical_Fp0, &
    phase_mechanical_F0, &
    phase_mechanical_Li0, &
    phase_mechanical_Lp0, &
    phase_mechanical_S0


  integer(kind(PLASTICITY_undefined_ID)), dimension(:),   allocatable :: &
    phase_plasticity                                                                                !< plasticity of each phase


  interface

    module subroutine eigendeformation_init(phases)
      class(tNode), pointer :: phases
    end subroutine eigendeformation_init

    module subroutine plastic_init
    end subroutine plastic_init

    module subroutine plastic_isotropic_LiAndItsTangent(Li,dLi_dMi,Mi,ph,me)
      real(pReal), dimension(3,3),     intent(out) :: &
        Li                                                                                          !< inleastic velocity gradient
      real(pReal), dimension(3,3,3,3), intent(out)  :: &
        dLi_dMi                                                                                     !< derivative of Li with respect to Mandel stress
      real(pReal), dimension(3,3),     intent(in) :: &
        Mi                                                                                          !< Mandel stress
      integer,                         intent(in) :: &
        ph, &
        me
    end subroutine plastic_isotropic_LiAndItsTangent

    module function plastic_dotState(subdt,co,ip,el,ph,me) result(broken)

      integer, intent(in) :: &
        co, &                                                                                           !< component-ID of integration point
        ip, &                                                                                           !< integration point
        el, &                                                                                           !< element
        ph, &
        me
      real(pReal),  intent(in) :: &
        subdt                                                                                           !< timestep
      logical :: broken
    end function plastic_dotState

    module function plastic_deltaState(ph, me) result(broken)
      integer, intent(in) :: &
        ph, &
        me
      logical :: &
        broken
    end function plastic_deltaState

    module subroutine phase_LiAndItsTangents(Li, dLi_dS, dLi_dFi, &
                                             S, Fi, ph,me)
      integer, intent(in) :: &
        ph,me
      real(pReal),   intent(in),  dimension(3,3) :: &
        S                                                                                               !< 2nd Piola-Kirchhoff stress
      real(pReal),   intent(in),  dimension(3,3) :: &
        Fi                                                                                              !< intermediate deformation gradient
      real(pReal),   intent(out), dimension(3,3) :: &
        Li                                                                                              !< intermediate velocity gradient
      real(pReal),   intent(out), dimension(3,3,3,3) :: &
        dLi_dS, &                                                                                       !< derivative of Li with respect to S
        dLi_dFi

    end subroutine phase_LiAndItsTangents


    module subroutine plastic_LpAndItsTangents(Lp, dLp_dS, dLp_dFi, &
                                               S, Fi, ph,me)
      integer, intent(in) :: &
        ph,me
      real(pReal),   intent(in),  dimension(3,3) :: &
        S, &                                                                                            !< 2nd Piola-Kirchhoff stress
        Fi                                                                                              !< intermediate deformation gradient
      real(pReal),   intent(out), dimension(3,3) :: &
        Lp                                                                                              !< plastic velocity gradient
      real(pReal),   intent(out), dimension(3,3,3,3) :: &
        dLp_dS, &
        dLp_dFi                                                                                         !< derivative of Lp with respect to Fi
    end subroutine plastic_LpAndItsTangents


    module subroutine plastic_isotropic_results(ph,group)
      integer,          intent(in) :: ph
      character(len=*), intent(in) :: group
    end subroutine plastic_isotropic_results

    module subroutine plastic_phenopowerlaw_results(ph,group)
      integer,          intent(in) :: ph
      character(len=*), intent(in) :: group
    end subroutine plastic_phenopowerlaw_results

    module subroutine plastic_kinehardening_results(ph,group)
      integer,          intent(in) :: ph
      character(len=*), intent(in) :: group
    end subroutine plastic_kinehardening_results

    module subroutine plastic_dislotwin_results(ph,group)
      integer,          intent(in) :: ph
      character(len=*), intent(in) :: group
    end subroutine plastic_dislotwin_results

    module subroutine plastic_dislotungsten_results(ph,group)
      integer,          intent(in) :: ph
      character(len=*), intent(in) :: group
    end subroutine plastic_dislotungsten_results

    module subroutine plastic_nonlocal_results(ph,group)
      integer,          intent(in) :: ph
      character(len=*), intent(in) :: group
    end subroutine plastic_nonlocal_results

    module function plastic_dislotwin_homogenizedC(ph,me) result(homogenizedC)
      real(pReal), dimension(6,6) :: homogenizedC
      integer,     intent(in) :: ph,me
    end function plastic_dislotwin_homogenizedC


  end interface
  type :: tOutput                                                                                   !< new requested output (per phase)
    character(len=pStringLen), allocatable, dimension(:) :: &
      label
  end type tOutput
  type(tOutput), allocatable, dimension(:) :: output_constituent

  procedure(integrateStateFPI), pointer :: integrateState

contains


!--------------------------------------------------------------------------------------------------
!> @brief Initialize mechanical field related constitutive models
!> @details Initialize elasticity, plasticity and stiffness degradation models.
!--------------------------------------------------------------------------------------------------
module subroutine mechanical_init(materials,phases)

  class(tNode), pointer :: &
    materials, &
    phases

  integer :: &
    el, &
    ip, &
    co, &
    ce, &
    ph, &
    me, &
    stiffDegradationCtr, &
    Nconstituents
  class(tNode), pointer :: &
    num_crystallite, &
    material, &
    constituents, &
    constituent, &
    phase, &
    mech, &
    elastic, &
    stiffDegradation

  print'(/,a)', ' <<<+-  phase:mechanical init  -+>>>'

!-------------------------------------------------------------------------------------------------
! initialize elasticity (hooke)                         !ToDO: Maybe move to elastic submodule along with function homogenizedC?
  allocate(phase_elasticity(phases%length), source = ELASTICITY_undefined_ID)
  allocate(phase_elasticityInstance(phases%length), source = 0)
  allocate(phase_NstiffnessDegradations(phases%length),source=0)
  allocate(output_constituent(phases%length))

  allocate(phase_mechanical_Fe(phases%length))
  allocate(phase_mechanical_Fi(phases%length))
  allocate(phase_mechanical_Fi0(phases%length))
  allocate(phase_mechanical_Fp(phases%length))
  allocate(phase_mechanical_Fp0(phases%length))
  allocate(phase_mechanical_F(phases%length))
  allocate(phase_mechanical_F0(phases%length))
  allocate(phase_mechanical_Li(phases%length))
  allocate(phase_mechanical_Li0(phases%length))
  allocate(phase_mechanical_Lp0(phases%length))
  allocate(phase_mechanical_Lp(phases%length))
  allocate(phase_mechanical_S(phases%length))
  allocate(phase_mechanical_P(phases%length))
  allocate(phase_mechanical_S0(phases%length))

  allocate(material_orientation0(homogenization_maxNconstituents,phases%length,maxVal(material_phaseMemberAt)))

  do ph = 1, phases%length
    Nconstituents = count(material_phaseAt == ph) * discretization_nIPs

    allocate(phase_mechanical_Fi(ph)%data(3,3,Nconstituents))
    allocate(phase_mechanical_Fe(ph)%data(3,3,Nconstituents))
    allocate(phase_mechanical_Fi0(ph)%data(3,3,Nconstituents))
    allocate(phase_mechanical_Fp(ph)%data(3,3,Nconstituents))
    allocate(phase_mechanical_Fp0(ph)%data(3,3,Nconstituents))
    allocate(phase_mechanical_Li(ph)%data(3,3,Nconstituents))
    allocate(phase_mechanical_Li0(ph)%data(3,3,Nconstituents))
    allocate(phase_mechanical_Lp0(ph)%data(3,3,Nconstituents))
    allocate(phase_mechanical_Lp(ph)%data(3,3,Nconstituents))
    allocate(phase_mechanical_S(ph)%data(3,3,Nconstituents),source=0.0_pReal)
    allocate(phase_mechanical_P(ph)%data(3,3,Nconstituents),source=0.0_pReal)
    allocate(phase_mechanical_S0(ph)%data(3,3,Nconstituents),source=0.0_pReal)
    allocate(phase_mechanical_F(ph)%data(3,3,Nconstituents))
    allocate(phase_mechanical_F0(ph)%data(3,3,Nconstituents))

    phase   => phases%get(ph)
    mech    => phase%get('mechanics')
#if defined(__GFORTRAN__)
    output_constituent(ph)%label  = output_asStrings(mech)
#else
    output_constituent(ph)%label  = mech%get_asStrings('output',defaultVal=emptyStringArray)
#endif
    elastic => mech%get('elasticity')
    if(elastic%get_asString('type') == 'hooke') then
      phase_elasticity(ph) = ELASTICITY_HOOKE_ID
    else
      call IO_error(200,ext_msg=elastic%get_asString('type'))
    endif
    stiffDegradation => mech%get('stiffness_degradation',defaultVal=emptyList)                      ! check for stiffness degradation mechanisms
    phase_NstiffnessDegradations(ph) = stiffDegradation%length
  enddo

  allocate(phase_stiffnessDegradation(maxval(phase_NstiffnessDegradations),phases%length), &
                        source=STIFFNESS_DEGRADATION_undefined_ID)

  if(maxVal(phase_NstiffnessDegradations)/=0) then
    do ph = 1, phases%length
      phase => phases%get(ph)
      mech    => phase%get('mechanics')
      stiffDegradation => mech%get('stiffness_degradation',defaultVal=emptyList)
      do stiffDegradationCtr = 1, stiffDegradation%length
        if(stiffDegradation%get_asString(stiffDegradationCtr) == 'damage') &
            phase_stiffnessDegradation(stiffDegradationCtr,ph) = STIFFNESS_DEGRADATION_damage_ID
      enddo
    enddo
  endif

  
  do el = 1, size(material_phaseMemberAt,3); do ip = 1, size(material_phaseMemberAt,2)
    do co = 1, homogenization_Nconstituents(material_homogenizationAt(el))
      material     => materials%get(discretization_materialAt(el))
      constituents => material%get('constituents')
      constituent => constituents%get(co)

      ph = material_phaseAt(co,el)
      me = material_phaseMemberAt(co,ip,el)

      call material_orientation0(co,ph,me)%fromQuaternion(constituent%get_asFloats('O',requiredSize=4))

      phase_mechanical_Fp0(ph)%data(1:3,1:3,me) = material_orientation0(co,ph,me)%asMatrix()                         ! Fp reflects initial orientation (see 10.1016/j.actamat.2006.01.005)
      phase_mechanical_Fp0(ph)%data(1:3,1:3,me) = phase_mechanical_Fp0(ph)%data(1:3,1:3,me) &
                                                / math_det33(phase_mechanical_Fp0(ph)%data(1:3,1:3,me))**(1.0_pReal/3.0_pReal)
      phase_mechanical_Fi0(ph)%data(1:3,1:3,me) = math_I3
      phase_mechanical_F0(ph)%data(1:3,1:3,me)  = math_I3

      phase_mechanical_Fe(ph)%data(1:3,1:3,me) = math_inv33(matmul(phase_mechanical_Fi0(ph)%data(1:3,1:3,me), &
                                                                   phase_mechanical_Fp0(ph)%data(1:3,1:3,me)))           ! assuming that euler angles are given in internal strain free configuration
      phase_mechanical_Fp(ph)%data(1:3,1:3,me) = phase_mechanical_Fp0(ph)%data(1:3,1:3,me)
      phase_mechanical_Fi(ph)%data(1:3,1:3,me) = phase_mechanical_Fi0(ph)%data(1:3,1:3,me)
      phase_mechanical_F(ph)%data(1:3,1:3,me)  = phase_mechanical_F0(ph)%data(1:3,1:3,me)

    enddo
  enddo; enddo


! initialize plasticity
  allocate(plasticState(phases%length))
  allocate(phase_plasticity(phases%length),source = PLASTICITY_undefined_ID)
  allocate(phase_localPlasticity(phases%length),   source=.true.)

  call plastic_init()

  do ph = 1, phases%length
    phase_elasticityInstance(ph) = count(phase_elasticity(1:ph) == phase_elasticity(ph))
  enddo

  num_crystallite => config_numerics%get('crystallite',defaultVal=emptyDict)

  select case(num_crystallite%get_asString('integrator',defaultVal='FPI'))

    case('FPI')
      integrateState => integrateStateFPI

    case('Euler')
      integrateState => integrateStateEuler

    case('AdaptiveEuler')
      integrateState => integrateStateAdaptiveEuler

    case('RK4')
      integrateState => integrateStateRK4

    case('RKCK45')
      integrateState => integrateStateRKCK45

    case default
     call IO_error(301,ext_msg='integrator')

  end select


  call eigendeformation_init(phases)


end subroutine mechanical_init


!--------------------------------------------------------------------------------------------------
!> @brief returns the 2nd Piola-Kirchhoff stress tensor and its tangent with respect to
!> the elastic and intermediate deformation gradients using Hooke's law
!--------------------------------------------------------------------------------------------------
subroutine phase_hooke_SandItsTangents(S, dS_dFe, dS_dFi, &
                                              Fe, Fi, ph, me)

  integer, intent(in) :: &
    ph, &
    me
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
    d, &                                                                                            !< counter in degradation loop
    i, j

  C = math_66toSym3333(phase_homogenizedC(ph,me))

  DegradationLoop: do d = 1, phase_NstiffnessDegradations(ph)
    degradationType: select case(phase_stiffnessDegradation(d,ph))
      case (STIFFNESS_DEGRADATION_damage_ID) degradationType
        C = C * damage_phi(ph,me)**2
    end select degradationType
  enddo DegradationLoop

  E = 0.5_pReal*(matmul(transpose(Fe),Fe)-math_I3)                                                  !< Green-Lagrange strain in unloaded configuration
  S = math_mul3333xx33(C,matmul(matmul(transpose(Fi),E),Fi))                                        !< 2PK stress in lattice configuration in work conjugate with GL strain pulled back to lattice configuration

  do i =1, 3;do j=1,3
    dS_dFe(i,j,1:3,1:3) = matmul(Fe,matmul(matmul(Fi,C(i,j,1:3,1:3)),transpose(Fi)))                !< dS_ij/dFe_kl = C_ijmn * Fi_lm * Fi_on * Fe_ko
    dS_dFi(i,j,1:3,1:3) = 2.0_pReal*matmul(matmul(E,Fi),C(i,j,1:3,1:3))                             !< dS_ij/dFi_kl = C_ijln * E_km * Fe_mn
  enddo; enddo

end subroutine phase_hooke_SandItsTangents


module subroutine mechanical_results(group,ph)

  character(len=*), intent(in) :: group
  integer,          intent(in) :: ph

  if (phase_plasticity(ph) /= PLASTICITY_NONE_ID) &
    call results_closeGroup(results_addGroup(group//'plastic/'))

  select case(phase_plasticity(ph))

    case(PLASTICITY_ISOTROPIC_ID)
      call plastic_isotropic_results(ph,group//'plastic/')

    case(PLASTICITY_PHENOPOWERLAW_ID)
      call plastic_phenopowerlaw_results(ph,group//'plastic/')

    case(PLASTICITY_KINEHARDENING_ID)
      call plastic_kinehardening_results(ph,group//'plastic/')

    case(PLASTICITY_DISLOTWIN_ID)
      call plastic_dislotwin_results(ph,group//'plastic/')

    case(PLASTICITY_DISLOTUNGSTEN_ID)
      call plastic_dislotungsten_results(ph,group//'plastic/')

    case(PLASTICITY_NONLOCAL_ID)
      call plastic_nonlocal_results(ph,group//'plastic/')

  end select

  call crystallite_results(group,ph)

end subroutine mechanical_results


!--------------------------------------------------------------------------------------------------
!> @brief calculation of stress (P) with time integration based on a residuum in Lp and
!> intermediate acceleration of the Newton-Raphson correction
!--------------------------------------------------------------------------------------------------
function integrateStress(F,subFp0,subFi0,Delta_t,co,ip,el) result(broken)

  real(pReal), dimension(3,3), intent(in) :: F,subFp0,subFi0
  real(pReal),                 intent(in) :: Delta_t
  integer, intent(in)::         el, &                                                               ! element index
                                      ip, &                                                         ! integration point index
                                      co                                                            ! grain index

  real(pReal), dimension(3,3)::       Fp_new, &                                                     ! plastic deformation gradient at end of timestep
                                      invFp_new, &                                                  ! inverse of Fp_new
                                      invFp_current, &                                              ! inverse of Fp_current
                                      Lpguess, &                                                    ! current guess for plastic velocity gradient
                                      Lpguess_old, &                                                ! known last good guess for plastic velocity gradient
                                      Lp_constitutive, &                                            ! plastic velocity gradient resulting from constitutive law
                                      residuumLp, &                                                 ! current residuum of plastic velocity gradient
                                      residuumLp_old, &                                             ! last residuum of plastic velocity gradient
                                      deltaLp, &                                                    ! direction of next guess
                                      Fi_new, &                                                     ! gradient of intermediate deformation stages
                                      invFi_new, &
                                      invFi_current, &                                              ! inverse of Fi_current
                                      Liguess, &                                                    ! current guess for intermediate velocity gradient
                                      Liguess_old, &                                                ! known last good guess for intermediate velocity gradient
                                      Li_constitutive, &                                            ! intermediate velocity gradient resulting from constitutive law
                                      residuumLi, &                                                 ! current residuum of intermediate velocity gradient
                                      residuumLi_old, &                                             ! last residuum of intermediate velocity gradient
                                      deltaLi, &                                                    ! direction of next guess
                                      Fe, &                                                         ! elastic deformation gradient
                                      S, &                                                          ! 2nd Piola-Kirchhoff Stress in plastic (lattice) configuration
                                      A, &
                                      B, &
                                      temp_33
  real(pReal), dimension(9) ::        temp_9                                                        ! needed for matrix inversion by LAPACK
  integer,     dimension(9) ::        devNull_9                                                     ! needed for matrix inversion by LAPACK
  real(pReal), dimension(9,9) ::      dRLp_dLp, &                                                   ! partial derivative of residuum (Jacobian for Newton-Raphson scheme)
                                      dRLi_dLi                                                      ! partial derivative of residuumI (Jacobian for Newton-Raphson scheme)
  real(pReal), dimension(3,3,3,3)::   dS_dFe, &                                                     ! partial derivative of 2nd Piola-Kirchhoff stress
                                      dS_dFi, &
                                      dFe_dLp, &                                                    ! partial derivative of elastic deformation gradient
                                      dFe_dLi, &
                                      dFi_dLi, &
                                      dLp_dFi, &
                                      dLi_dFi, &
                                      dLp_dS, &
                                      dLi_dS
  real(pReal)                         steplengthLp, &
                                      steplengthLi, &
                                      atol_Lp, &
                                      atol_Li, &
                                      devNull
  integer                             NiterationStressLp, &                                         ! number of stress integrations
                                      NiterationStressLi, &                                         ! number of inner stress integrations
                                      ierr, &                                                       ! error indicator for LAPACK
                                      o, &
                                      p, &
                                      ph, &
                                      me, &
                                      jacoCounterLp, &
                                      jacoCounterLi                                                 ! counters to check for Jacobian update
  logical :: error,broken


  broken = .true.

  ph = material_phaseAt(co,el)
  me = material_phaseMemberAt(co,ip,el)

  call plastic_dependentState(co,ip,el)

  Lpguess = phase_mechanical_Lp(ph)%data(1:3,1:3,me)                                              ! take as first guess
  Liguess = phase_mechanical_Li(ph)%data(1:3,1:3,me)                                              ! take as first guess

  call math_invert33(invFp_current,devNull,error,subFp0)
  if (error) return ! error
  call math_invert33(invFi_current,devNull,error,subFi0)
  if (error) return ! error

  A = matmul(F,invFp_current)                                                                       ! intermediate tensor needed later to calculate dFe_dLp

  jacoCounterLi  = 0
  steplengthLi   = 1.0_pReal
  residuumLi_old = 0.0_pReal
  Liguess_old    = Liguess

  NiterationStressLi = 0
  LiLoop: do
    NiterationStressLi = NiterationStressLi + 1
    if (NiterationStressLi>num%nStress) return ! error

    invFi_new = matmul(invFi_current,math_I3 - Delta_t*Liguess)
    Fi_new    = math_inv33(invFi_new)

    jacoCounterLp  = 0
    steplengthLp   = 1.0_pReal
    residuumLp_old = 0.0_pReal
    Lpguess_old    = Lpguess

    NiterationStressLp = 0
    LpLoop: do
      NiterationStressLp = NiterationStressLp + 1
      if (NiterationStressLp>num%nStress) return ! error

      B  = math_I3 - Delta_t*Lpguess
      Fe = matmul(matmul(A,B), invFi_new)
      call phase_hooke_SandItsTangents(S, dS_dFe, dS_dFi, &
                                        Fe, Fi_new, ph, me)

      call plastic_LpAndItsTangents(Lp_constitutive, dLp_dS, dLp_dFi, &
                                         S, Fi_new, ph,me)

      !* update current residuum and check for convergence of loop
      atol_Lp = max(num%rtol_crystalliteStress * max(norm2(Lpguess),norm2(Lp_constitutive)), &      ! absolute tolerance from largest acceptable relative error
                    num%atol_crystalliteStress)                                                     ! minimum lower cutoff
      residuumLp = Lpguess - Lp_constitutive

      if (any(IEEE_is_NaN(residuumLp))) then
        return ! error
      elseif (norm2(residuumLp) < atol_Lp) then                                                     ! converged if below absolute tolerance
        exit LpLoop
      elseif (NiterationStressLp == 1 .or. norm2(residuumLp) < norm2(residuumLp_old)) then          ! not converged, but improved norm of residuum (always proceed in first iteration)...
        residuumLp_old = residuumLp                                                                 ! ...remember old values and...
        Lpguess_old    = Lpguess
        steplengthLp   = 1.0_pReal                                                                  ! ...proceed with normal step length (calculate new search direction)
      else                                                                                          ! not converged and residuum not improved...
        steplengthLp = num%subStepSizeLp * steplengthLp                                             ! ...try with smaller step length in same direction
        Lpguess      = Lpguess_old &
                     + deltaLp * stepLengthLp
        cycle LpLoop
      endif

      calculateJacobiLi: if (mod(jacoCounterLp, num%iJacoLpresiduum) == 0) then
        jacoCounterLp = jacoCounterLp + 1

        do o=1,3; do p=1,3
          dFe_dLp(o,1:3,p,1:3) = - Delta_t * A(o,p)*transpose(invFi_new)                            ! dFe_dLp(i,j,k,l) = -Delta_t * A(i,k) invFi(l,j)
        enddo; enddo
        dRLp_dLp = math_eye(9) &
                 - math_3333to99(math_mul3333xx3333(math_mul3333xx3333(dLp_dS,dS_dFe),dFe_dLp))
        temp_9 = math_33to9(residuumLp)
        call dgesv(9,1,dRLp_dLp,9,devNull_9,temp_9,9,ierr)                                          ! solve dRLp/dLp * delta Lp = -res for delta Lp
        if (ierr /= 0) return ! error
        deltaLp = - math_9to33(temp_9)
      endif calculateJacobiLi

      Lpguess = Lpguess &
              + deltaLp * steplengthLp
    enddo LpLoop

    call phase_LiAndItsTangents(Li_constitutive, dLi_dS, dLi_dFi, &
                                       S, Fi_new, ph,me)

    !* update current residuum and check for convergence of loop
    atol_Li = max(num%rtol_crystalliteStress * max(norm2(Liguess),norm2(Li_constitutive)), &        ! absolute tolerance from largest acceptable relative error
                  num%atol_crystalliteStress)                                                       ! minimum lower cutoff
    residuumLi = Liguess - Li_constitutive
    if (any(IEEE_is_NaN(residuumLi))) then
      return ! error
    elseif (norm2(residuumLi) < atol_Li) then                                                       ! converged if below absolute tolerance
      exit LiLoop
    elseif (NiterationStressLi == 1 .or. norm2(residuumLi) < norm2(residuumLi_old)) then            ! not converged, but improved norm of residuum (always proceed in first iteration)...
      residuumLi_old = residuumLi                                                                   ! ...remember old values and...
      Liguess_old    = Liguess
      steplengthLi   = 1.0_pReal                                                                    ! ...proceed with normal step length (calculate new search direction)
    else                                                                                            ! not converged and residuum not improved...
      steplengthLi = num%subStepSizeLi * steplengthLi                                               ! ...try with smaller step length in same direction
      Liguess      = Liguess_old &
                   + deltaLi * steplengthLi
      cycle LiLoop
    endif

    calculateJacobiLp: if (mod(jacoCounterLi, num%iJacoLpresiduum) == 0) then
      jacoCounterLi = jacoCounterLi + 1

      temp_33 = matmul(matmul(A,B),invFi_current)
      do o=1,3; do p=1,3
        dFe_dLi(1:3,o,1:3,p) = -Delta_t*math_I3(o,p)*temp_33                                        ! dFe_dLp(i,j,k,l) = -Delta_t * A(i,k) invFi(l,j)
        dFi_dLi(1:3,o,1:3,p) = -Delta_t*math_I3(o,p)*invFi_current
      enddo; enddo
      do o=1,3; do p=1,3
        dFi_dLi(1:3,1:3,o,p) = matmul(matmul(Fi_new,dFi_dLi(1:3,1:3,o,p)),Fi_new)
      enddo; enddo
      dRLi_dLi  = math_eye(9) &
                - math_3333to99(math_mul3333xx3333(dLi_dS,  math_mul3333xx3333(dS_dFe, dFe_dLi) &
                                                          + math_mul3333xx3333(dS_dFi, dFi_dLi)))  &
                - math_3333to99(math_mul3333xx3333(dLi_dFi, dFi_dLi))
      temp_9 = math_33to9(residuumLi)
      call dgesv(9,1,dRLi_dLi,9,devNull_9,temp_9,9,ierr)                                            ! solve dRLi/dLp * delta Li = -res for delta Li
      if (ierr /= 0) return ! error
      deltaLi = - math_9to33(temp_9)
    endif calculateJacobiLp

    Liguess = Liguess &
            + deltaLi * steplengthLi
  enddo LiLoop

  invFp_new = matmul(invFp_current,B)
  call math_invert33(Fp_new,devNull,error,invFp_new)
  if (error) return ! error

  phase_mechanical_P(ph)%data(1:3,1:3,me)  = matmul(matmul(F,invFp_new),matmul(S,transpose(invFp_new)))
  phase_mechanical_S(ph)%data(1:3,1:3,me)  = S
  phase_mechanical_Lp(ph)%data(1:3,1:3,me) = Lpguess
  phase_mechanical_Li(ph)%data(1:3,1:3,me) = Liguess
  phase_mechanical_Fp(ph)%data(1:3,1:3,me) = Fp_new / math_det33(Fp_new)**(1.0_pReal/3.0_pReal)    ! regularize
  phase_mechanical_Fi(ph)%data(1:3,1:3,me) = Fi_new
  phase_mechanical_Fe(ph)%data(1:3,1:3,me) = matmul(matmul(F,invFp_new),invFi_new)
  broken = .false.

end function integrateStress


!--------------------------------------------------------------------------------------------------
!> @brief integrate stress, state with adaptive 1st order explicit Euler method
!> using Fixed Point Iteration to adapt the stepsize
!--------------------------------------------------------------------------------------------------
function integrateStateFPI(F_0,F,subFp0,subFi0,subState0,Delta_t,co,ip,el) result(broken)

  real(pReal), intent(in),dimension(3,3) :: F_0,F,subFp0,subFi0
  real(pReal), intent(in),dimension(:)   :: subState0
  real(pReal), intent(in) :: Delta_t
  integer, intent(in) :: &
    el, &                                                                                            !< element index in element loop
    ip, &                                                                                            !< integration point index in ip loop
    co                                                                                               !< grain index in grain loop
  logical :: &
    broken

  integer :: &
    NiterationState, &                                                                              !< number of iterations in state loop
    ph, &
    me, &
    sizeDotState
  real(pReal) :: &
    zeta
  real(pReal), dimension(phase_plasticity_maxSizeDotState) :: &
    r                                                                                               ! state residuum
  real(pReal), dimension(phase_plasticity_maxSizeDotState,2) :: &
    dotState


  ph = material_phaseAt(co,el)
  me = material_phaseMemberAt(co,ip,el)

  broken = plastic_dotState(Delta_t, co,ip,el,ph,me)
  if(broken) return

  sizeDotState = plasticState(ph)%sizeDotState
  plasticState(ph)%state(1:sizeDotState,me) = subState0 &
                                            + plasticState(ph)%dotState (1:sizeDotState,me) * Delta_t
  dotState(1:sizeDotState,2) = 0.0_pReal

  iteration: do NiterationState = 1, num%nState

    if(nIterationState > 1) dotState(1:sizeDotState,2) = dotState(1:sizeDotState,1)
    dotState(1:sizeDotState,1) = plasticState(ph)%dotState(:,me)

    broken = integrateStress(F,subFp0,subFi0,Delta_t,co,ip,el)
    if(broken) exit iteration

    broken = plastic_dotState(Delta_t, co,ip,el,ph,me)
    if(broken) exit iteration

    zeta = damper(plasticState(ph)%dotState(:,me),dotState(1:sizeDotState,1),&
                                                  dotState(1:sizeDotState,2))
    plasticState(ph)%dotState(:,me) = plasticState(ph)%dotState(:,me) * zeta &
                                    + dotState(1:sizeDotState,1) * (1.0_pReal - zeta)
    r(1:sizeDotState) = plasticState(ph)%state    (1:sizeDotState,me) &
                      - subState0 &
                      - plasticState(ph)%dotState (1:sizeDotState,me) * Delta_t
    plasticState(ph)%state(1:sizeDotState,me) = plasticState(ph)%state(1:sizeDotState,me) &
                                              - r(1:sizeDotState)
    if (converged(r(1:sizeDotState),plasticState(ph)%state(1:sizeDotState,me),plasticState(ph)%atol(1:sizeDotState))) then
      broken = plastic_deltaState(ph,me)
      exit iteration
    endif

  enddo iteration


  contains

  !--------------------------------------------------------------------------------------------------
  !> @brief calculate the damping for correction of state and dot state
  !--------------------------------------------------------------------------------------------------
  real(pReal) pure function damper(current,previous,previous2)

  real(pReal), dimension(:), intent(in) ::&
    current, previous, previous2

  real(pReal) :: dot_prod12, dot_prod22

  dot_prod12 = dot_product(current  - previous,  previous - previous2)
  dot_prod22 = dot_product(previous - previous2, previous - previous2)
  if ((dot_product(current,previous) < 0.0_pReal .or. dot_prod12 < 0.0_pReal) .and. dot_prod22 > 0.0_pReal) then
    damper = 0.75_pReal + 0.25_pReal * tanh(2.0_pReal + 4.0_pReal * dot_prod12 / dot_prod22)
  else
    damper = 1.0_pReal
  endif

  end function damper

end function integrateStateFPI


!--------------------------------------------------------------------------------------------------
!> @brief integrate state with 1st order explicit Euler method
!--------------------------------------------------------------------------------------------------
function integrateStateEuler(F_0,F,subFp0,subFi0,subState0,Delta_t,co,ip,el) result(broken)

  real(pReal), intent(in),dimension(3,3) :: F_0,F,subFp0,subFi0
  real(pReal), intent(in),dimension(:)   :: subState0
  real(pReal), intent(in) :: Delta_t
  integer, intent(in) :: &
    el, &                                                                                            !< element index in element loop
    ip, &                                                                                            !< integration point index in ip loop
    co                                                                                               !< grain index in grain loop
  logical :: &
    broken

  integer :: &
    ph, &
    me, &
    sizeDotState


  ph = material_phaseAt(co,el)
  me = material_phaseMemberAt(co,ip,el)

  broken = plastic_dotState(Delta_t, co,ip,el,ph,me)
  if(broken) return

  sizeDotState = plasticState(ph)%sizeDotState
  plasticState(ph)%state(1:sizeDotState,me) = subState0 &
                                            + plasticState(ph)%dotState(1:sizeDotState,me) * Delta_t

  broken = plastic_deltaState(ph,me)
  if(broken) return

  broken = integrateStress(F,subFp0,subFi0,Delta_t,co,ip,el)

end function integrateStateEuler


!--------------------------------------------------------------------------------------------------
!> @brief integrate stress, state with 1st order Euler method with adaptive step size
!--------------------------------------------------------------------------------------------------
function integrateStateAdaptiveEuler(F_0,F,subFp0,subFi0,subState0,Delta_t,co,ip,el) result(broken)

  real(pReal), intent(in),dimension(3,3) :: F_0,F,subFp0,subFi0
  real(pReal), intent(in),dimension(:)   :: subState0
  real(pReal), intent(in) :: Delta_t
  integer, intent(in) :: &
    el, &                                                                                            !< element index in element loop
    ip, &                                                                                            !< integration point index in ip loop
    co                                                                                               !< grain index in grain loop
  logical :: &
    broken

  integer :: &
    ph, &
    me, &
    sizeDotState
  real(pReal), dimension(phase_plasticity_maxSizeDotState) :: residuum_plastic


  ph = material_phaseAt(co,el)
  me = material_phaseMemberAt(co,ip,el)

  broken = plastic_dotState(Delta_t, co,ip,el,ph,me)
  if(broken) return

  sizeDotState = plasticState(ph)%sizeDotState

  residuum_plastic(1:sizeDotState) = - plasticState(ph)%dotstate(1:sizeDotState,me) * 0.5_pReal * Delta_t
  plasticState(ph)%state(1:sizeDotState,me) = subState0 &
                                            + plasticState(ph)%dotstate(1:sizeDotState,me) * Delta_t

  broken = plastic_deltaState(ph,me)
  if(broken) return

  broken = integrateStress(F,subFp0,subFi0,Delta_t,co,ip,el)
  if(broken) return

  broken = plastic_dotState(Delta_t, co,ip,el,ph,me)
  if(broken) return

  broken = .not. converged(residuum_plastic(1:sizeDotState) + 0.5_pReal * plasticState(ph)%dotState(:,me) * Delta_t, &
                           plasticState(ph)%state(1:sizeDotState,me), &
                           plasticState(ph)%atol(1:sizeDotState))

end function integrateStateAdaptiveEuler


!---------------------------------------------------------------------------------------------------
!> @brief Integrate state (including stress integration) with the classic Runge Kutta method
!---------------------------------------------------------------------------------------------------
function integrateStateRK4(F_0,F,subFp0,subFi0,subState0,Delta_t,co,ip,el) result(broken)

  real(pReal), intent(in),dimension(3,3) :: F_0,F,subFp0,subFi0
  real(pReal), intent(in),dimension(:)   :: subState0
  real(pReal), intent(in) :: Delta_t
  integer, intent(in) :: co,ip,el
  logical :: broken

  real(pReal), dimension(3,3), parameter :: &
    A = reshape([&
      0.5_pReal, 0.0_pReal, 0.0_pReal, &
      0.0_pReal, 0.5_pReal, 0.0_pReal, &
      0.0_pReal, 0.0_pReal, 1.0_pReal],&
      shape(A))
  real(pReal), dimension(3), parameter :: &
    C = [0.5_pReal, 0.5_pReal, 1.0_pReal]
  real(pReal), dimension(4), parameter :: &
    B = [1.0_pReal/6.0_pReal, 1.0_pReal/3.0_pReal, 1.0_pReal/3.0_pReal, 1.0_pReal/6.0_pReal]


  broken = integrateStateRK(F_0,F,subFp0,subFi0,subState0,Delta_t,co,ip,el,A,B,C)

end function integrateStateRK4


!---------------------------------------------------------------------------------------------------
!> @brief Integrate state (including stress integration) with the Cash-Carp method
!---------------------------------------------------------------------------------------------------
function integrateStateRKCK45(F_0,F,subFp0,subFi0,subState0,Delta_t,co,ip,el) result(broken)

  real(pReal), intent(in),dimension(3,3) :: F_0,F,subFp0,subFi0
  real(pReal), intent(in),dimension(:)   :: subState0
  real(pReal), intent(in) :: Delta_t
  integer, intent(in) :: co,ip,el
  logical :: broken

  real(pReal), dimension(5,5), parameter :: &
    A = reshape([&
      1._pReal/5._pReal,       .0_pReal,             .0_pReal,               .0_pReal,                  .0_pReal, &
      3._pReal/40._pReal,      9._pReal/40._pReal,   .0_pReal,               .0_pReal,                  .0_pReal, &
      3_pReal/10._pReal,       -9._pReal/10._pReal,  6._pReal/5._pReal,      .0_pReal,                  .0_pReal, &
      -11._pReal/54._pReal,    5._pReal/2._pReal,    -70.0_pReal/27.0_pReal, 35.0_pReal/27.0_pReal,     .0_pReal, &
      1631._pReal/55296._pReal,175._pReal/512._pReal,575._pReal/13824._pReal,44275._pReal/110592._pReal,253._pReal/4096._pReal],&
      shape(A))
  real(pReal), dimension(5), parameter :: &
    C = [0.2_pReal, 0.3_pReal, 0.6_pReal, 1.0_pReal, 0.875_pReal]
  real(pReal), dimension(6), parameter :: &
    B = &
      [37.0_pReal/378.0_pReal, .0_pReal, 250.0_pReal/621.0_pReal, &
      125.0_pReal/594.0_pReal, .0_pReal, 512.0_pReal/1771.0_pReal], &
    DB = B - &
      [2825.0_pReal/27648.0_pReal,    .0_pReal,                18575.0_pReal/48384.0_pReal,&
      13525.0_pReal/55296.0_pReal, 277.0_pReal/14336.0_pReal,  1._pReal/4._pReal]


  broken = integrateStateRK(F_0,F,subFp0,subFi0,subState0,Delta_t,co,ip,el,A,B,C,DB)

end function integrateStateRKCK45


!--------------------------------------------------------------------------------------------------
!> @brief Integrate state (including stress integration) with an explicit Runge-Kutta method or an
!! embedded explicit Runge-Kutta method
!--------------------------------------------------------------------------------------------------
function integrateStateRK(F_0,F,subFp0,subFi0,subState0,Delta_t,co,ip,el,A,B,C,DB) result(broken)

  real(pReal), intent(in),dimension(3,3) :: F_0,F,subFp0,subFi0
  real(pReal), intent(in),dimension(:)   :: subState0
  real(pReal), intent(in) :: Delta_t
  real(pReal), dimension(:,:), intent(in) :: A
  real(pReal), dimension(:),   intent(in) :: B, C
  real(pReal), dimension(:),   intent(in), optional :: DB
  integer, intent(in) :: &
    el, &                                                                                            !< element index in element loop
    ip, &                                                                                            !< integration point index in ip loop
    co                                                                                               !< grain index in grain loop
  logical :: broken

  integer :: &
    stage, &                                                                                        ! stage index in integration stage loop
    n, &
    ph, &
    me, &
    sizeDotState
  real(pReal), dimension(phase_plasticity_maxSizeDotState,size(B)) :: plastic_RKdotState


  ph = material_phaseAt(co,el)
  me = material_phaseMemberAt(co,ip,el)

  broken = plastic_dotState(Delta_t,co,ip,el,ph,me)
  if(broken) return

  sizeDotState = plasticState(ph)%sizeDotState

  do stage = 1, size(A,1)

    plastic_RKdotState(1:sizeDotState,stage) = plasticState(ph)%dotState(:,me)
    plasticState(ph)%dotState(:,me) = A(1,stage) * plastic_RKdotState(1:sizeDotState,1)

    do n = 2, stage
      plasticState(ph)%dotState(:,me) = plasticState(ph)%dotState(:,me) &
                                      + A(n,stage) * plastic_RKdotState(1:sizeDotState,n)
    enddo

    plasticState(ph)%state(1:sizeDotState,me) = subState0 &
                                              + plasticState(ph)%dotState (1:sizeDotState,me) * Delta_t

    broken = integrateStress(F_0 + (F - F_0) * Delta_t * C(stage),subFp0,subFi0,Delta_t * C(stage),co,ip,el)
    if(broken) exit

    broken = plastic_dotState(Delta_t*C(stage),co,ip,el,ph,me)
    if(broken) exit

  enddo
  if(broken) return


  plastic_RKdotState(1:sizeDotState,size(B)) = plasticState (ph)%dotState(:,me)
  plasticState(ph)%dotState(:,me) = matmul(plastic_RKdotState(1:sizeDotState,1:size(B)),B)
  plasticState(ph)%state(1:sizeDotState,me) = subState0 &
                                            + plasticState(ph)%dotState (1:sizeDotState,me) * Delta_t

  if(present(DB)) &
    broken = .not. converged(matmul(plastic_RKdotState(1:sizeDotState,1:size(DB)),DB) * Delta_t, &
                             plasticState(ph)%state(1:sizeDotState,me), &
                             plasticState(ph)%atol(1:sizeDotState))

  if(broken) return

  broken = plastic_deltaState(ph,me)
  if(broken) return

  broken = integrateStress(F,subFp0,subFi0,Delta_t,co,ip,el)

end function integrateStateRK


!--------------------------------------------------------------------------------------------------
!> @brief writes crystallite results to HDF5 output file
!--------------------------------------------------------------------------------------------------
subroutine crystallite_results(group,ph)

  character(len=*), intent(in) :: group
  integer,          intent(in) :: ph

  integer :: ou
  real(pReal), allocatable, dimension(:,:)   :: selected_rotations
  character(len=:), allocatable              :: structureLabel


    call results_closeGroup(results_addGroup(group//'/mechanics/'))

    do ou = 1, size(output_constituent(ph)%label)

      select case (output_constituent(ph)%label(ou))
        case('F')
          call results_writeDataset(group//'/mechanics/',phase_mechanical_F(ph)%data,'F',&
                                   'deformation gradient','1')
        case('F_e')
          call results_writeDataset(group//'/mechanics/',phase_mechanical_Fe(ph)%data,'F_e',&
                                   'elastic deformation gradient','1')
        case('F_p')
          call results_writeDataset(group//'/mechanics/',phase_mechanical_Fp(ph)%data,'F_p', &
                                   'plastic deformation gradient','1')
        case('F_i')
          call results_writeDataset(group//'/mechanics/',phase_mechanical_Fi(ph)%data,'F_i', &
                                   'inelastic deformation gradient','1')
        case('L_p')
          call results_writeDataset(group//'/mechanics/',phase_mechanical_Lp(ph)%data,'L_p', &
                                   'plastic velocity gradient','1/s')
        case('L_i')
          call results_writeDataset(group//'/mechanics/',phase_mechanical_Li(ph)%data,'L_i', &
                                   'inelastic velocity gradient','1/s')
        case('P')
          call results_writeDataset(group//'/mechanics/',phase_mechanical_P(ph)%data,'P', &
                                   'First Piola-Kirchhoff stress','Pa')
        case('S')
          call results_writeDataset(group//'/mechanics/',phase_mechanical_S(ph)%data,'S', &
                                   'Second Piola-Kirchhoff stress','Pa')
        case('O')
          select case(lattice_structure(ph))
            case(lattice_ISO_ID)
              structureLabel = 'aP'
            case(lattice_FCC_ID)
              structureLabel = 'cF'
            case(lattice_BCC_ID)
              structureLabel = 'cI'
            case(lattice_BCT_ID)
              structureLabel = 'tI'
            case(lattice_HEX_ID)
              structureLabel = 'hP'
            case(lattice_ORT_ID)
              structureLabel = 'oP'
          end select
          selected_rotations = select_rotations(crystallite_orientation,ph)
          call results_writeDataset(group//'/mechanics/',selected_rotations,output_constituent(ph)%label(ou),&
                                   'crystal orientation as quaternion','q_0 (q_1 q_2 q_3)')
          call results_addAttribute('Lattice',structureLabel,group//'/mechanics/'//output_constituent(ph)%label(ou))
      end select
    enddo


  contains

!--------------------------------------------------------------------------------------------------
!> @brief select rotations for output
!--------------------------------------------------------------------------------------------------
  function select_rotations(dataset,ph)

    integer, intent(in) :: ph
    type(rotation), dimension(:,:,:), intent(in) :: dataset
    real(pReal), allocatable, dimension(:,:) :: select_rotations
    integer :: el,ip,co,j

    allocate(select_rotations(4,count(material_phaseAt==ph)*homogenization_maxNconstituents*discretization_nIPs))

    j=0
    do el = 1, size(material_phaseAt,2)
      do ip = 1, discretization_nIPs
        do co = 1, size(material_phaseAt,1)                                                          !ToDo: this needs to be changed for varying Ngrains
           if (material_phaseAt(co,el) == ph) then
             j = j + 1
             select_rotations(1:4,j) = dataset(co,ip,el)%asQuaternion()
           endif
        enddo
      enddo
   enddo

 end function select_rotations

end subroutine crystallite_results


!--------------------------------------------------------------------------------------------------
!> @brief Wind homog inc forward.
!--------------------------------------------------------------------------------------------------
module subroutine mechanical_windForward(ph,me)

  integer, intent(in) :: ph, me


  phase_mechanical_Fp0(ph)%data(1:3,1:3,me) = phase_mechanical_Fp(ph)%data(1:3,1:3,me)
  phase_mechanical_Fi0(ph)%data(1:3,1:3,me) = phase_mechanical_Fi(ph)%data(1:3,1:3,me)
  phase_mechanical_F0(ph)%data(1:3,1:3,me)  = phase_mechanical_F(ph)%data(1:3,1:3,me)
  phase_mechanical_Li0(ph)%data(1:3,1:3,me) = phase_mechanical_Li(ph)%data(1:3,1:3,me)
  phase_mechanical_Lp0(ph)%data(1:3,1:3,me) = phase_mechanical_Lp(ph)%data(1:3,1:3,me)
  phase_mechanical_S0(ph)%data(1:3,1:3,me)  = phase_mechanical_S(ph)%data(1:3,1:3,me)

  plasticState(ph)%State0(:,me) = plasticState(ph)%state(:,me)

end subroutine mechanical_windForward


!--------------------------------------------------------------------------------------------------
!> @brief Forward data after successful increment.
! ToDo: Any guessing for the current states possible?
!--------------------------------------------------------------------------------------------------
module subroutine mechanical_forward()

  integer :: ph


  do ph = 1, size(plasticState)
    phase_mechanical_Fi0(ph) = phase_mechanical_Fi(ph)
    phase_mechanical_Fp0(ph) = phase_mechanical_Fp(ph)
    phase_mechanical_F0(ph)  = phase_mechanical_F(ph)
    phase_mechanical_Li0(ph) = phase_mechanical_Li(ph)
    phase_mechanical_Lp0(ph) = phase_mechanical_Lp(ph)
    phase_mechanical_S0(ph)  = phase_mechanical_S(ph)
    plasticState(ph)%state0 = plasticState(ph)%state
  enddo

end subroutine mechanical_forward



!--------------------------------------------------------------------------------------------------
!> @brief returns the homogenize elasticity matrix
!> ToDo: homogenizedC66 would be more consistent
!--------------------------------------------------------------------------------------------------
module function phase_homogenizedC(ph,me) result(C)

  real(pReal), dimension(6,6) :: C
  integer,      intent(in)    :: ph, me

  plasticType: select case (phase_plasticity(ph))
    case (PLASTICITY_DISLOTWIN_ID) plasticType
     C = plastic_dislotwin_homogenizedC(ph,me)
    case default plasticType
     C = lattice_C66(1:6,1:6,ph)
  end select plasticType

end function phase_homogenizedC


!--------------------------------------------------------------------------------------------------
!> @brief calculate stress (P)
!--------------------------------------------------------------------------------------------------
module function crystallite_stress(dt,co,ip,el) result(converged_)

  real(pReal), intent(in) :: dt
  integer, intent(in) :: &
    co, &
    ip, &
    el
  logical :: converged_

  real(pReal) :: &
    formerSubStep
  integer :: &
    ph, me, sizeDotState
  logical :: todo
  real(pReal) :: subFrac,subStep
  real(pReal), dimension(3,3) :: &
    subFp0, &
    subFi0, &
    subLp0, &
    subLi0, &
    subF0, &
    subF
  real(pReal), dimension(:), allocatable :: subState0


  ph = material_phaseAt(co,el)
  me = material_phaseMemberAt(co,ip,el)
  sizeDotState = plasticState(ph)%sizeDotState

  subLi0 = phase_mechanical_Li0(ph)%data(1:3,1:3,me)
  subLp0 = phase_mechanical_Lp0(ph)%data(1:3,1:3,me)
  subState0 = plasticState(ph)%State0(:,me)

  if (damageState(ph)%sizeState > 0) &
    damageState(ph)%subState0(:,me) = damageState(ph)%state0(:,me)

  subFp0 = phase_mechanical_Fp0(ph)%data(1:3,1:3,me)
  subFi0 = phase_mechanical_Fi0(ph)%data(1:3,1:3,me)
  subF0  = phase_mechanical_F0(ph)%data(1:3,1:3,me)
  subFrac = 0.0_pReal
  subStep = 1.0_pReal/num%subStepSizeCryst
  todo = .true.
  converged_ = .false.                                                      ! pretend failed step of 1/subStepSizeCryst

  todo = .true.
  cutbackLooping: do while (todo)

    if (converged_) then
      formerSubStep = subStep
      subFrac = subFrac + subStep
      subStep = min(1.0_pReal - subFrac, num%stepIncreaseCryst * subStep)

      todo = subStep > 0.0_pReal                        ! still time left to integrate on?

      if (todo) then
        subF0  = subF
        subLp0 = phase_mechanical_Lp(ph)%data(1:3,1:3,me)
        subLi0 = phase_mechanical_Li(ph)%data(1:3,1:3,me)
        subFp0 = phase_mechanical_Fp(ph)%data(1:3,1:3,me)
        subFi0 = phase_mechanical_Fi(ph)%data(1:3,1:3,me)
        subState0 = plasticState(ph)%state(:,me)
        if (damageState(ph)%sizeState > 0) &
          damageState(ph)%subState0(:,me) = damageState(ph)%state(:,me)

      endif
!--------------------------------------------------------------------------------------------------
!  cut back (reduced time and restore)
    else
      subStep       = num%subStepSizeCryst * subStep
      phase_mechanical_Fp(ph)%data(1:3,1:3,me) = subFp0
      phase_mechanical_Fi(ph)%data(1:3,1:3,me) = subFi0
      phase_mechanical_S(ph)%data(1:3,1:3,me) = phase_mechanical_S0(ph)%data(1:3,1:3,me)          ! why no subS0 ? is S0 of any use?
      if (subStep < 1.0_pReal) then                                                                 ! actual (not initial) cutback
        phase_mechanical_Lp(ph)%data(1:3,1:3,me) = subLp0
        phase_mechanical_Li(ph)%data(1:3,1:3,me) = subLi0
      endif
      plasticState(ph)%state(:,me) = subState0
      if (damageState(ph)%sizeState > 0) &
        damageState(ph)%state(:,me) = damageState(ph)%subState0(:,me)

      todo = subStep > num%subStepMinCryst                          ! still on track or already done (beyond repair)
    endif

!--------------------------------------------------------------------------------------------------
!  prepare for integration
    if (todo) then
      subF = subF0 &
           + subStep * (phase_mechanical_F(ph)%data(1:3,1:3,me) - phase_mechanical_F0(ph)%data(1:3,1:3,me))
      phase_mechanical_Fe(ph)%data(1:3,1:3,me) = matmul(subF,math_inv33(matmul(phase_mechanical_Fi(ph)%data(1:3,1:3,me), &
                                                                               phase_mechanical_Fp(ph)%data(1:3,1:3,me))))
      converged_ = .not. integrateState(subF0,subF,subFp0,subFi0,subState0(1:sizeDotState),subStep * dt,co,ip,el)
      converged_ = converged_ .and. .not. integrateDamageState(subStep * dt,co,ip,el)
    endif

  enddo cutbackLooping

end function crystallite_stress


!--------------------------------------------------------------------------------------------------
!> @brief Restore data after homog cutback.
!--------------------------------------------------------------------------------------------------
module subroutine mechanical_restore(ce,includeL)

  integer, intent(in) :: ce
  logical, intent(in) :: &
    includeL                                                                                        !< protect agains fake cutback

  integer :: &
    co, ph, me


  do co = 1,homogenization_Nconstituents(material_homogenizationAt2(ce))
    ph = material_phaseAt2(co,ce)
    me = material_phaseMemberAt2(co,ce)
    if (includeL) then
      phase_mechanical_Lp(ph)%data(1:3,1:3,me) = phase_mechanical_Lp0(ph)%data(1:3,1:3,me)
      phase_mechanical_Li(ph)%data(1:3,1:3,me) = phase_mechanical_Li0(ph)%data(1:3,1:3,me)
    endif                                                                                           ! maybe protecting everything from overwriting makes more sense

    phase_mechanical_Fp(ph)%data(1:3,1:3,me)   = phase_mechanical_Fp0(ph)%data(1:3,1:3,me)
    phase_mechanical_Fi(ph)%data(1:3,1:3,me)   = phase_mechanical_Fi0(ph)%data(1:3,1:3,me)
    phase_mechanical_S(ph)%data(1:3,1:3,me)    = phase_mechanical_S0(ph)%data(1:3,1:3,me)

    plasticState(ph)%state(:,me) = plasticState(ph)%State0(:,me)
  enddo

end subroutine mechanical_restore

!--------------------------------------------------------------------------------------------------
!> @brief Calculate tangent (dPdF).
!--------------------------------------------------------------------------------------------------
module function phase_mechanical_dPdF(dt,co,ce) result(dPdF)

  real(pReal), intent(in) :: dt
  integer, intent(in) :: &
    co, &                                                                                            !< counter in constituent loop
    ce
  real(pReal), dimension(3,3,3,3) :: dPdF

  integer :: &
    o, &
    p, ph, me
  real(pReal), dimension(3,3)     ::   devNull, &
                                       invSubFp0,invSubFi0,invFp,invFi, &
                                       temp_33_1, temp_33_2, temp_33_3
  real(pReal), dimension(3,3,3,3) ::   dSdFe, &
                                       dSdF, &
                                       dSdFi, &
                                       dLidS, &                                                     ! tangent in lattice configuration
                                       dLidFi, &
                                       dLpdS, &
                                       dLpdFi, &
                                       dFidS, &
                                       dFpinvdF, &
                                       rhs_3333, &
                                       lhs_3333, &
                                       temp_3333
  real(pReal), dimension(9,9)::        temp_99
  logical :: error


  ph = material_phaseAt2(co,ce)
  me = material_phaseMemberAt2(co,ce)

  call phase_hooke_SandItsTangents(devNull,dSdFe,dSdFi, &
                                          phase_mechanical_Fe(ph)%data(1:3,1:3,me), &
                                          phase_mechanical_Fi(ph)%data(1:3,1:3,me),ph,me)
  call phase_LiAndItsTangents(devNull,dLidS,dLidFi, &
                                     phase_mechanical_S(ph)%data(1:3,1:3,me), &
                                     phase_mechanical_Fi(ph)%data(1:3,1:3,me), &
                                     ph,me)

  invFp = math_inv33(phase_mechanical_Fp(ph)%data(1:3,1:3,me))
  invFi = math_inv33(phase_mechanical_Fi(ph)%data(1:3,1:3,me))
  invSubFp0 = math_inv33(phase_mechanical_Fp0(ph)%data(1:3,1:3,me))
  invSubFi0 = math_inv33(phase_mechanical_Fi0(ph)%data(1:3,1:3,me))

  if (sum(abs(dLidS)) < tol_math_check) then
    dFidS = 0.0_pReal
  else
    lhs_3333 = 0.0_pReal; rhs_3333 = 0.0_pReal
    do o=1,3; do p=1,3
      lhs_3333(1:3,1:3,o,p) = lhs_3333(1:3,1:3,o,p) &
                            + matmul(invSubFi0,dLidFi(1:3,1:3,o,p)) * dt
      lhs_3333(1:3,o,1:3,p) = lhs_3333(1:3,o,1:3,p) &
                            + invFi*invFi(p,o)
      rhs_3333(1:3,1:3,o,p) = rhs_3333(1:3,1:3,o,p) &
                            - matmul(invSubFi0,dLidS(1:3,1:3,o,p)) * dt
    enddo; enddo
    call math_invert(temp_99,error,math_3333to99(lhs_3333))
    if (error) then
      call IO_warning(warning_ID=600, &
                      ext_msg='inversion error in analytic tangent calculation')
      dFidS = 0.0_pReal
    else
      dFidS = math_mul3333xx3333(math_99to3333(temp_99),rhs_3333)
    endif
    dLidS = math_mul3333xx3333(dLidFi,dFidS) + dLidS
  endif

  call plastic_LpAndItsTangents(devNull,dLpdS,dLpdFi, &
                                             phase_mechanical_S(ph)%data(1:3,1:3,me), &
                                             phase_mechanical_Fi(ph)%data(1:3,1:3,me),ph,me)
  dLpdS = math_mul3333xx3333(dLpdFi,dFidS) + dLpdS

!--------------------------------------------------------------------------------------------------
! calculate dSdF
  temp_33_1 = transpose(matmul(invFp,invFi))
  temp_33_2 = matmul(phase_mechanical_F(ph)%data(1:3,1:3,me),invSubFp0)
  temp_33_3 = matmul(matmul(phase_mechanical_F(ph)%data(1:3,1:3,me),invFp), invSubFi0)

  do o=1,3; do p=1,3
    rhs_3333(p,o,1:3,1:3)  = matmul(dSdFe(p,o,1:3,1:3),temp_33_1)
    temp_3333(1:3,1:3,p,o) = matmul(matmul(temp_33_2,dLpdS(1:3,1:3,p,o)), invFi) &
                           + matmul(temp_33_3,dLidS(1:3,1:3,p,o))
  enddo; enddo
  lhs_3333 = math_mul3333xx3333(dSdFe,temp_3333) * dt &
           + math_mul3333xx3333(dSdFi,dFidS)

  call math_invert(temp_99,error,math_eye(9)+math_3333to99(lhs_3333))
  if (error) then
    call IO_warning(warning_ID=600, &
                    ext_msg='inversion error in analytic tangent calculation')
    dSdF = rhs_3333
  else
    dSdF = math_mul3333xx3333(math_99to3333(temp_99),rhs_3333)
  endif

!--------------------------------------------------------------------------------------------------
! calculate dFpinvdF
  temp_3333 = math_mul3333xx3333(dLpdS,dSdF)
  do o=1,3; do p=1,3
    dFpinvdF(1:3,1:3,p,o) = - matmul(invSubFp0, matmul(temp_3333(1:3,1:3,p,o),invFi)) * dt
  enddo; enddo

!--------------------------------------------------------------------------------------------------
! assemble dPdF
  temp_33_1 = matmul(phase_mechanical_S(ph)%data(1:3,1:3,me),transpose(invFp))
  temp_33_2 = matmul(phase_mechanical_F(ph)%data(1:3,1:3,me),invFp)
  temp_33_3 = matmul(temp_33_2,phase_mechanical_S(ph)%data(1:3,1:3,me))

  dPdF = 0.0_pReal
  do p=1,3
    dPdF(p,1:3,p,1:3) = transpose(matmul(invFp,temp_33_1))
  enddo
  do o=1,3; do p=1,3
    dPdF(1:3,1:3,p,o) = dPdF(1:3,1:3,p,o) &
                      + matmul(matmul(phase_mechanical_F(ph)%data(1:3,1:3,me),dFpinvdF(1:3,1:3,p,o)),temp_33_1) &
                      + matmul(matmul(temp_33_2,dSdF(1:3,1:3,p,o)),transpose(invFp)) &
                      + matmul(temp_33_3,transpose(dFpinvdF(1:3,1:3,p,o)))
  enddo; enddo

end function phase_mechanical_dPdF


module subroutine mechanical_restartWrite(groupHandle,ph)

  integer(HID_T), intent(in) :: groupHandle
  integer, intent(in) :: ph


  call HDF5_write(groupHandle,plasticState(ph)%state,'omega')
  call HDF5_write(groupHandle,phase_mechanical_Fi(ph)%data,'F_i')
  call HDF5_write(groupHandle,phase_mechanical_Li(ph)%data,'L_i')
  call HDF5_write(groupHandle,phase_mechanical_Lp(ph)%data,'L_p')
  call HDF5_write(groupHandle,phase_mechanical_Fp(ph)%data,'F_p')
  call HDF5_write(groupHandle,phase_mechanical_S(ph)%data,'S')
  call HDF5_write(groupHandle,phase_mechanical_F(ph)%data,'F')

end subroutine mechanical_restartWrite


module subroutine mechanical_restartRead(groupHandle,ph)

  integer(HID_T), intent(in) :: groupHandle
  integer, intent(in) :: ph


  call HDF5_read(groupHandle,plasticState(ph)%state0,'omega')
  call HDF5_read(groupHandle,phase_mechanical_Fi0(ph)%data,'F_i')
  call HDF5_read(groupHandle,phase_mechanical_Li0(ph)%data,'L_i')
  call HDF5_read(groupHandle,phase_mechanical_Lp0(ph)%data,'L_p')
  call HDF5_read(groupHandle,phase_mechanical_Fp0(ph)%data,'F_p')
  call HDF5_read(groupHandle,phase_mechanical_S0(ph)%data,'S')
  call HDF5_read(groupHandle,phase_mechanical_F0(ph)%data,'F')

end subroutine mechanical_restartRead


!----------------------------------------------------------------------------------------------
!< @brief Get first Piola-Kichhoff stress (for use by non-mech physics)
!----------------------------------------------------------------------------------------------
module function mechanical_S(ph,me) result(S)

  integer, intent(in) :: ph,me
  real(pReal), dimension(3,3) :: S


  S = phase_mechanical_S(ph)%data(1:3,1:3,me)

end function mechanical_S


!----------------------------------------------------------------------------------------------
!< @brief Get plastic velocity gradient (for use by non-mech physics)
!----------------------------------------------------------------------------------------------
module function mechanical_L_p(ph,me) result(L_p)

  integer, intent(in) :: ph,me
  real(pReal), dimension(3,3) :: L_p


  L_p = phase_mechanical_Lp(ph)%data(1:3,1:3,me)

end function mechanical_L_p


!----------------------------------------------------------------------------------------------
!< @brief Get deformation gradient (for use by homogenization)
!----------------------------------------------------------------------------------------------
module function phase_mechanical_getF(co,ce) result(F)

  integer, intent(in) :: co, ce
  real(pReal), dimension(3,3) :: F


  F = phase_mechanical_F(material_phaseAt2(co,ce))%data(1:3,1:3,material_phaseMemberAt2(co,ce))

end function phase_mechanical_getF


!----------------------------------------------------------------------------------------------
!< @brief Get elastic deformation gradient (for use by non-mech physics)
!----------------------------------------------------------------------------------------------
module function mechanical_F_e(ph,me) result(F_e)

  integer, intent(in) :: ph,me
  real(pReal), dimension(3,3) :: F_e


  F_e = phase_mechanical_Fe(ph)%data(1:3,1:3,me)

end function mechanical_F_e



!----------------------------------------------------------------------------------------------
!< @brief Get second Piola-Kichhoff stress (for use by homogenization)
!----------------------------------------------------------------------------------------------
module function phase_mechanical_getP(co,ce) result(P)

  integer, intent(in) :: co, ce
  real(pReal), dimension(3,3) :: P


  P = phase_mechanical_P(material_phaseAt2(co,ce))%data(1:3,1:3,material_phaseMemberAt2(co,ce))

end function phase_mechanical_getP


! setter for homogenization
module subroutine phase_mechanical_setF(F,co,ce)

  real(pReal), dimension(3,3), intent(in) :: F
  integer, intent(in) :: co, ce


  phase_mechanical_F(material_phaseAt2(co,ce))%data(1:3,1:3,material_phaseMemberAt2(co,ce)) = F

end subroutine phase_mechanical_setF


end submodule mechanical
