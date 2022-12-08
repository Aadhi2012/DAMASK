!--------------------------------------------------------------------------------------------------
!> @author Martin Diehl, KU Leuven
!> @brief Tabular representation of variable data.
!--------------------------------------------------------------------------------------------------
module tables
  use prec
  use IO
  use YAML_parse
  use YAML_types

  implicit none(type,external)
  private

  type, public :: tTable
    real(pReal), dimension(:), allocatable :: x,y
    contains
    procedure, public :: at => eval
  end type tTable

  interface table
    module procedure table_from_values
    module procedure table_from_dict
  end interface table

  public :: &
    table, &
    tables_init

contains


!--------------------------------------------------------------------------------------------------
!> @brief Run self-test.
!--------------------------------------------------------------------------------------------------
subroutine tables_init()

  print'(/,1x,a)', '<<<+-  tables init  -+>>>'; flush(IO_STDOUT)

  call selfTest()

end subroutine tables_init


!--------------------------------------------------------------------------------------------------
!> @brief Initialize a table from values.
!--------------------------------------------------------------------------------------------------
function table_from_values(x,y) result(t)

  real(pReal), dimension(:), intent(in) :: x,y
  type(tTable) :: t


  if (min(size(x),size(y))< 1) call IO_error(603,ext_msg='no data specified')
  if (size(x) /= size(y))      call IO_error(603,ext_msg='non-matching shape of tabulated data')
  if (size(x) /=1) then
    if (any(x(1:size(x)-1) -x(2:size(x)) > 0.0_pReal)) &
                               call IO_error(603,ext_msg='ordinate data does not increase monotonically')
  end if

  t%x = x
  t%y = y

end function table_from_values


!--------------------------------------------------------------------------------------------------
!> @brief Initialize a table from a dictionary with values.
!--------------------------------------------------------------------------------------------------
function table_from_dict(dict,x_label,y_label) result(t)

  type(tDict), intent(in) :: dict
  character(len=*), intent(in) :: x_label, y_label
  type(tTable) :: t


  t = tTable(dict%get_as1dFloat(x_label),dict%get_as1dFloat(y_label))

end function table_from_dict


!--------------------------------------------------------------------------------------------------
!> @brief Evaluate a table.
!--------------------------------------------------------------------------------------------------
pure function eval(self,x) result(y)

  class(tTable), intent(in) :: self
  real(pReal), intent(in) :: x
  real(pReal) :: y

  integer :: i


  if (size(self%x) == 1) then
    y = self%x(1)
  else
    i = max(1,min(findloc(self%x<x,.true.,dim=1,back=.true.),size(self%x)-1))
    y = self%y(i) &
      + (self%y(i) - self%y(i+1))/(self%x(i) - self%x(i+1)) * (x - self%x(i))
  end if

end function eval


!--------------------------------------------------------------------------------------------------
!> @brief Check correctness of table functionality.
!--------------------------------------------------------------------------------------------------
subroutine selfTest()

  type(tTable) :: t
  real(pReal), dimension(*), parameter :: &
    x = real([1.,2.,3.,4.],pReal), &
    y = real([1.,2.,2.,1.],pReal), &
    x_eval = real([0.,.5,1.,1.5,2.,2.5,3.,3.5,4.,4.5,5.],pReal), &
    y_true = real([0.,.5,1.,1.5,2.,2. ,2.,1.5,1.,.5, 0.],pReal)
  integer :: i
  type(tDict), pointer :: dict
  type(tList), pointer :: l_x, l_y
  real(pReal) :: r


  call random_number(r)
  r = r-0.5_pReal
  t = table(x+r,y)
  do i = 1, size(x_eval)
    if (dNeq(y_true(i),t%at(x_eval(i)+r),1.0e-9_pReal)) error stop 'table eval/values'
  end do


  l_x => YAML_parse_str_asList('[1, 2, 3, 4]'//IO_EOL)
  l_y => YAML_parse_str_asList('[1, 2, 2, 1]'//IO_EOL)
  allocate(dict)
  call dict%set('t',l_x)
  call dict%set('T',l_y)
  t = table(dict,'t','T')
  do i = 1, size(x_eval)
    if (dNeq(y_true(i),t%at(x_eval(i)))) error stop 'table eval/dict'
  end do

end subroutine selfTest

end module tables
