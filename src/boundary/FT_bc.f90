  !< Apply flow tangency boundary condition
module FT_bc
  !< Apply flow tangency boundary condition
  !--------------------------------------------
  use vartypes
!  use global_vars, only: qp
!  use global_vars, only: x_speed
!  use global_vars, only: y_speed
!  use global_vars, only: z_speed
!  use global_vars, only: imx
!  use global_vars, only: jmx
!  use global_vars, only: kmx
  use global_vars, only: xn
  use global_vars, only: yn
  use global_vars, only: zn

  use copy_bc   , only : copy3

  implicit none
  private

  public :: flow_tangency

  contains

    subroutine flow_tangency(qp, face, dims)
      !< Apply flow tangency boundary condition
      implicit none
      type(extent), intent(in) :: dims
      real, dimension(-2:dims%imx+2, -2:dims%jmx+2, -2:dims%kmx+2, 1:dims%n_var), intent(inout):: qp
      character(len=*), intent(in) :: face
      !< Face over which flow tangency condition has to be applied
      real :: dot1
      real :: dot2
      real :: dot3
      integer :: i
      integer :: j
      integer :: k
      integer :: imx, jmx, kmx

      imx = dims%imx
      jmx = dims%jmx
      kmx = dims%kmx

      select case(face)
        case("imin")
          do k=1,kmx-1
            do j=1,jmx-1
              dot1=sum(qp(1,j,k,2:4)*xn(1,j,k,1:3))
              dot2=sum(qp(2,j,k,2:4)*xn(1,j,k,1:3))
              dot3=sum(qp(3,j,k,2:4)*xn(1,j,k,1:3))
              qp( 0,j,k,2:4) = qp(1,j,k,2:4) - (2*dot1*xn(1,j,k,1:3))
              qp(-1,j,k,2:4) = qp(2,j,k,2:4) - (2*dot2*xn(1,j,k,1:3))
              qp(-2,j,k,2:4) = qp(3,j,k,2:4) - (2*dot3*xn(1,j,k,1:3))
            end do
          end do
        case("imax")
          do k=1,kmx-1
            do j=1,jmx-1
              dot1=sum(qp(imx-1,j,k,2:4)*xn(imx,j,k,1:3))
              dot2=sum(qp(imx-2,j,k,2:4)*xn(imx,j,k,1:3))
              dot3=sum(qp(imx-3,j,k,2:4)*xn(imx,j,k,1:3))
              qp(imx+0,j,k,2:4) = qp(imx-1,j,k,2:4) - (2*dot1*xn(imx,j,k,1:3))
              qp(imx+1,j,k,2:4) = qp(imx-2,j,k,2:4) - (2*dot2*xn(imx,j,k,1:3))
              qp(imx+2,j,k,2:4) = qp(imx-3,j,k,2:4) - (2*dot3*xn(imx,j,k,1:3))
            end do
          end do
        case ("jmin")
          do k=1,kmx-1
            do i=1,imx-1
              dot1=sum(qp(i,1,k,2:4)*yn(i,1,k,1:3))
              dot2=sum(qp(i,2,k,2:4)*yn(i,1,k,1:3))
              dot3=sum(qp(i,3,k,2:4)*yn(i,1,k,1:3))
              qp(i, 0,k,2:4) = qp(i,1,k,2:4) - (2*dot1*yn(i,1,k,1:3))
              qp(i,-1,k,2:4) = qp(i,2,k,2:4) - (2*dot2*yn(i,1,k,1:3))
              qp(i,-2,k,2:4) = qp(i,3,k,2:4) - (2*dot3*yn(i,1,k,1:3))
            end do
          end do
        case ("jmax")
          do k=1,kmx-1
            do i=1,imx-1
              dot1=sum(qp(i,jmx-1,k,2:4)*yn(i,jmx,k,1:3))
              dot2=sum(qp(i,jmx-2,k,2:4)*yn(i,jmx,k,1:3))
              dot3=sum(qp(i,jmx-3,k,2:4)*yn(i,jmx,k,1:3))
              qp(i,jmx+0,k,2:4) = qp(i,jmx-1,k,2:4) - (2*dot1*yn(i,jmx,k,1:3))
              qp(i,jmx+1,k,2:4) = qp(i,jmx-2,k,2:4) - (2*dot2*yn(i,jmx,k,1:3))
              qp(i,jmx+2,k,2:4) = qp(i,jmx-3,k,2:4) - (2*dot3*yn(i,jmx,k,1:3))
            end do
          end do
        case("kmin")
          do j=1,jmx-1
            do i=1,imx-1
              dot1=sum(qp(i,j,1,2:4)*zn(i,j,1,1:3))
              dot2=sum(qp(i,j,2,2:4)*zn(i,j,1,1:3))
              dot3=sum(qp(i,j,3,2:4)*zn(i,j,1,1:3))
              qp(i,j, 0,2:4) = qp(i,j,1,2:4) - (2*dot1*zn(i,j,1,1:3))
              qp(i,j,-1,2:4) = qp(i,j,2,2:4) - (2*dot2*zn(i,j,1,1:3))
              qp(i,j,-2,2:4) = qp(i,j,3,2:4) - (2*dot3*zn(i,j,1,1:3))
            end do
          end do
        case("kmax")
          do j=1,jmx-1
            do i=1,imx-1
              dot1=sum(qp(i,j,kmx-1,2:4)*zn(i,j,kmx,1:3))
              dot2=sum(qp(i,j,kmx-2,2:4)*zn(i,j,kmx,1:3))
              dot3=sum(qp(i,j,kmx-3,2:4)*zn(i,j,kmx,1:3))
              qp(i,j,kmx+0,2:4) = qp(i,j,kmx-1,2:4) - (2*dot1*zn(i,j,kmx,1:3))
              qp(i,j,kmx+1,2:4) = qp(i,j,kmx-2,2:4) - (2*dot2*zn(i,j,kmx,1:3))
              qp(i,j,kmx+2,2:4) = qp(i,j,kmx-3,2:4) - (2*dot3*zn(i,j,kmx,1:3))
            end do
          end do
      end select
    end subroutine flow_tangency

end module FT_bc
