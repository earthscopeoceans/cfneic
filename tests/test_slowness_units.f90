program test_slowness_units

use ttak135, only: earth_radius_km, slw, slwS

implicit none

integer :: failures

failures = 0

call check_case('P upward', slw(0.10,10.0), &
  -sin(atan(0.10/max(0.001,10.0)))/5.8, .true.)
call check_case('P Pg', slw(1.00,10.0), 1.0/5.8, .false.)
call check_case('S upward', slwS(0.10,10.0), &
  -sin(atan(0.10/max(0.001,10.0)))/3.46, .true.)
call check_case('S Sg', slwS(1.00,10.0), 1.0/3.46, .false.)

if(failures.gt.0) then
  write(*,'(i0,a)') failures,' slowness unit checks failed'
  stop 1
endif

write(*,'(a)') 'slowness unit checks passed'

contains

subroutine check_case(name, raw_slowness, expected_per_km, expect_negative)

character(len=*), intent(in) :: name
real*4, intent(in) :: raw_slowness, expected_per_km
logical, intent(in) :: expect_negative
real*4 :: per_km, unit_factor
real*4, parameter :: per_km_tolerance = 1.0e-5
real*4, parameter :: factor_tolerance = 1.0e-2

per_km = raw_slowness/earth_radius_km
unit_factor = raw_slowness/expected_per_km

write(*,'(a,1x,a,1x,f12.6,1x,a,1x,f12.8,1x,a,1x,f12.3)') &
  trim(name),'raw=',raw_slowness,'per_km=',per_km,'factor=',unit_factor

if(expect_negative .and. raw_slowness.ge.0.0) then
  write(*,'(a,a)') 'FAIL sign: ',trim(name)
  failures = failures+1
endif

if((.not.expect_negative) .and. raw_slowness.le.0.0) then
  write(*,'(a,a)') 'FAIL sign: ',trim(name)
  failures = failures+1
endif

if(abs(per_km-expected_per_km).gt.per_km_tolerance) then
  write(*,'(a,a)') 'FAIL seconds/km conversion: ',trim(name)
  failures = failures+1
endif

if(abs(unit_factor-earth_radius_km).gt.factor_tolerance) then
  write(*,'(a,a)') 'FAIL raw seconds/radian factor: ',trim(name)
  failures = failures+1
endif

end subroutine check_case

end program test_slowness_units
