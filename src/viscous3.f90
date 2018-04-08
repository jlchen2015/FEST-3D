module viscous
  !-----------------------------------------------------------------
  ! The viscous module contains the viscous flux calculations and 
  ! the boundary conditions to be imposed
  !-----------------------------------------------------------------
#include "error.inc"
  use global     , only: FILE_NAME_LENGTH
  use global_vars, only : imx
  use global_vars, only : jmx
  use global_vars, only : kmx
  use global_vars, only : grid_x
  use global_vars, only : grid_y
  use global_vars, only : grid_z

  use global_vars, only : xnx, xny, xnz !face unit normal x
  use global_vars, only : ynx, yny, ynz !face unit normal y
  use global_vars, only : znx, zny, znz !face unit normal z
  use global_vars, only : xA, yA, zA    !face area
  use global_vars, only : vol => volume
  use geometry   , only : CellCenter
  
  use global_vars, only : process_id
  use global_vars, only : gm
  use global_vars, only : n_var
  use global_vars, only : R_gas
  use global_vars, only : mu_ref
  use global_vars, only : T_ref
  use global_vars, only : Pr
  use global_vars, only : tPr
  use global_vars, only : Sutherland_temp
  use global_vars, only : density
  use global_vars, only : x_speed
  use global_vars, only : y_speed
  use global_vars, only : z_speed
  use global_vars, only : pressure
  use global_vars, only : tk
  use global_vars, only : tw
  use global_vars, only : tkl
  use global_vars, only : gradu_x
  use global_vars, only : gradu_y
  use global_vars, only : gradu_z
  use global_vars, only : gradv_x
  use global_vars, only : gradv_y
  use global_vars, only : gradv_z
  use global_vars, only : gradw_x
  use global_vars, only : gradw_y
  use global_vars, only : gradw_z
  use global_vars, only : gradT_x
  use global_vars, only : gradT_y
  use global_vars, only : gradT_z
  use global_vars, only : gradtk_x
  use global_vars, only : gradtk_y
  use global_vars, only : gradtk_z
  use global_vars, only : gradtw_x
  use global_vars, only : gradtw_y
  use global_vars, only : gradtw_z
  use global_vars, only : gradtkl_x
  use global_vars, only : gradtkl_y
  use global_vars, only : gradtkl_z
  use global_vars, only : mu
  use global_vars, only : mu_t
  use global_vars, only : kkl_mu
  use global_vars, only : sst_mu
  use global_vars, only : turbulence
  use global_sst , only : sst_F1
  use global_sst , only : sigma_k1
  use global_sst , only : sigma_k2
  use global_sst , only : sigma_w1
  use global_sst , only : sigma_w2
  use global_kkl , only : sigma_k
  use global_kkl , only : sigma_phi
  use utils      , only : alloc, dealloc, dmsg
  use string
  implicit none
  private

  public :: compute_viscous_fluxes

  contains

    subroutine compute_viscous_fluxes(F, G, H)

        implicit none
        real, dimension(:, :, :, :), pointer :: F, G, H

        call compute_viscous_fluxes_laminar(F, 'x')
        call compute_viscous_fluxes_laminar(G, 'y')
        !if(kmx==2)then
        !  continue
        !else
          call compute_viscous_fluxes_laminar(H, 'z')
        !end if
        
        select case(trim(turbulence))
          case('none')
            !do nothing
            continue

          case('sst')
            call compute_viscous_fluxes_sst(F, 'x')
            call compute_viscous_fluxes_sst(G, 'y')
            !if(kmx==2)then
            !  continue
            !else
              call compute_viscous_fluxes_sst(H, 'z')
            !end if
          case('kkl')
            call compute_viscous_fluxes_kkl(F, 'x')
            call compute_viscous_fluxes_kkl(G, 'y')
            !if(kmx==2)then
            !  continue
            !else
              call compute_viscous_fluxes_kkl(H, 'z')
            !end if
          case DEFAULT
            Fatal_error
        end select


            if (any(isnan(G))) then
              Fatal_error
            end if
            if (any(isnan(F))) then
              Fatal_error
            end if
            if (any(isnan(H))) then
              Fatal_error
            end if

    end subroutine compute_viscous_fluxes

    subroutine compute_viscous_fluxes_laminar(F, direction)
      implicit none
      character(len=*), intent(in) :: direction ! face direction
      real, dimension(:, :, :, :), pointer, intent(inout) :: F ! flux array
      ! local variables
      real :: dudx, dudy, dudz
      real :: dvdx, dvdy, dvdz
      real :: dwdx, dwdy, dwdz
      real :: dTdx, dTdy, dTdz
      real :: d_LR
      real :: T_RE
      real :: T_LE
      real :: K_heat, Qx, Qy, Qz
      real :: mu_f
      real :: mut_f
      real :: total_mu
      real :: delx
      real :: dely
      real :: delz
      real :: delu
      real :: delv
      real :: delw
      real :: delT
      real :: Tau_xx
      real :: Tau_xy
      real :: Tau_xz
      real :: Tau_yx
      real :: Tau_yy
      real :: Tau_yz
      real :: Tau_zx
      real :: Tau_zy
      real :: Tau_zz
      real :: nx
      real :: ny
      real :: nz
      real :: area
      real :: uface
      real :: vface
      real :: wface
      real, dimension(:, :, :), pointer :: fA
      real, dimension(:, :, :), pointer :: fnx
      real, dimension(:, :, :), pointer :: fny
      real, dimension(:, :, :), pointer :: fnz
      integer :: i, j, k
      integer :: ii, jj, kk

      !--------------------------------------------------------------------
      ! select Direction
      !--------------------------------------------------------------------
      select case(trim(direction))
        case('x')
          ii  =  1
          jj  =  0
          kk  =  0
          fnx => xnx
          fny => xny
          fnz => xnz
          fA(-2:imx+3, -2:jmx+2, -2:kmx+2)   => xA

        case('y')
          ii  =  0
          jj  =  1
          kk  =  0
          fnx => ynx
          fny => yny
          fnz => ynz
          fA(-2:imx+2, -2:jmx+3, -2:kmx+2)   => yA

        case('z')
          ii  =  0
          jj  =  0
          kk  =  1
          fnx => znx
          fny => zny
          fnz => znz
          fA(-2:imx+2, -2:jmx+2, -2:kmx+3)   => zA

        case Default
          Fatal_error

      end select


      !---------------------------------------------------------------------
      ! Calculating the fluxes at the faces
      !--------------------------------------------------------------------
      do k = 1, kmx - 1 + kk
       do j = 1, jmx - 1 + jj
        do i = 1, imx - 1 + ii

          !--- FACE Gradients ---!
          ! distance between cell center of adjacent cell for the i,j,k face
          delx = CellCenter(i, j, k, 1) - CellCenter(i-ii, j-jj, k-kk, 1)
          dely = CellCenter(i, j, k, 2) - CellCenter(i-ii, j-jj, k-kk, 2)
          delz = CellCenter(i, j, k, 3) - CellCenter(i-ii, j-jj, k-kk, 3)

          d_LR = delx*delx + dely*dely + delz*delz

          ! Finding the temperature of left and right element to the face i,j,k
          T_LE = pressure(i-ii, j-jj, k-kk) / (density(i-ii, j-jj, k-kk) * R_gas)
          T_RE = pressure(i, j, k) / (density(i, j, k) * R_gas)

          ! difference in state across face
          delu = x_speed(i, j, k) - x_speed(i-ii, j-jj, k-kk)
          delv = y_speed(i, j, k) - y_speed(i-ii, j-jj, k-kk)
          delw = z_speed(i, j, k) - z_speed(i-ii, j-jj, k-kk)
          delT = T_RE - T_LE

          dudx = delu * delx / d_LR
          dudy = delu * dely / d_LR
          dudz = delu * delz / d_LR

          dvdx = delv * delx / d_LR
          dvdy = delv * dely / d_LR
          dvdz = delv * delz / d_LR

          dwdx = delw * delx / d_LR
          dwdy = delw * dely / d_LR
          dwdz = delw * delz / d_LR

          dTdx = delT * delx / d_LR
          dTdy = delT * dely / d_LR
          dTdz = delT * delz / d_LR
          !--- end of gradient calculation ---!

          mu_f  = 0.5*(mu(i-ii, j-jj, k-kk) + mu(i,j,k))
          if(trim(turbulence)/='none') then
            mut_f = 0.5*(mu_t(i-ii, j-jj, k-kk) + mu_t(i, j, k))
          else
            mut_f = 0.0 
          end if

          ! effective viscosity
          total_mu = mu_f + mut_f

          ! Using lambda = -2 * mu / 3
          ! diagonal terms of stress tensor
          Tau_xx = 2. * total_mu * (dudx - ((dudx + dvdy + dwdz) / 3.)) 
          Tau_yy = 2. * total_mu * (dvdy - ((dudx + dvdy + dwdz) / 3.)) 
          Tau_zz = 2. * total_mu * (dwdz - ((dudx + dvdy + dwdz) / 3.)) 
          ! off diagonal symmetrical part of stress tensor
          Tau_xy = total_mu * (dvdx + dudy)
          Tau_xz = total_mu * (dwdx + dudz)
          Tau_yz = total_mu * (dwdy + dvdz)
          Tau_yx = Tau_xy
          Tau_zx = Tau_xz
          Tau_zy = Tau_yz

          ! Pr: Prandtl Number and tPr: Turbulent Prandtl number
          ! Qx, Qy, Qz: Conduction fluxes
          K_heat = (mu_f/Pr + mut_f/tPr)* gm * R_gas / (gm - 1)
          Qx = K_heat*dTdx
          Qy = K_heat*dTdy
          Qz = K_heat*dTdz

          ! calling some element from memory and keep them handy for calculation
          nx    = fnx(i,j,k)
          ny    = fny(i,j,k)
          nz    = fnz(i,j,k)
          area  =  fA(i,j,k)
          uface = 0.5 * (x_speed(i-ii, j-jj, k-kk) + x_speed(i, j, k))
          vface = 0.5 * (y_speed(i-ii, j-jj, k-kk) + y_speed(i, j, k))
          wface = 0.5 * (z_speed(i-ii, j-jj, k-kk) + z_speed(i, j, k))

          ! adding viscous fluxes to stored convective flux
          F(i, j, k, 2) = F(i, j, k, 2) - ((Tau_xx*nx + Tau_xy*ny + Tau_xz*nz)*area)
          F(i, j, k, 3) = F(i, j, k, 3) - ((Tau_yx*nx + Tau_yy*ny + Tau_yz*nz)*area)
          F(i, j, k, 4) = F(i, j, k, 4) - ((Tau_zx*nx + Tau_zy*ny + Tau_zz*nz)*area)
         
          ! Energy flux
          ! (TijVj + Qi)ni
          F(i, j, k, 5) = F(i, j, k, 5) - (area * ( &
                          ((Tau_xx*uface + Tau_xy*vface + Tau_xz*wface + Qx)*nx) + &
                          ((Tau_yx*uface + Tau_yy*vface + Tau_yz*wface + Qy)*ny) + &
                          ((Tau_zx*uface + Tau_zy*vface + Tau_zz*wface + Qz)*nz) ) )
          
         
        end do
       end do
      end do

    end subroutine compute_viscous_fluxes_laminar


    subroutine compute_viscous_fluxes_sst(F, direction)
      implicit none
      character(len=*), intent(in) :: direction ! face direction
      real, dimension(:, :, :, :), pointer, intent(inout) :: F ! flux array
      ! local variables
      real :: tkface
      real :: rhoface
      real :: d_LR
      real :: mu_f
      real :: mut_f
      real :: total_mu
      real :: delx
      real :: dely
      real :: delz
      real :: deltk
      real :: deltw
      real :: Tau_xx
      real :: Tau_yy
      real :: Tau_zz
      real :: nx
      real :: ny
      real :: nz
      real :: area
      real, dimension(:, :, :), pointer :: fA
      real, dimension(:, :, :), pointer :: fnx
      real, dimension(:, :, :), pointer :: fny
      real, dimension(:, :, :), pointer :: fnz
      integer :: i, j, k
      integer :: ii, jj, kk
      !--- sst variable requirement ---!
      real :: dtkdx, dtkdy, dtkdz, dtwdx, dtwdy, dtwdz
      real ::  F1
      real ::  sigma_kf
      real ::  sigma_wf

      !--------------------------------------------------------------------
      ! select Direction
      !--------------------------------------------------------------------
      select case(trim(direction))
        case('x')
          ii  =  1
          jj  =  0
          kk  =  0
          fnx => xnx
          fny => xny
          fnz => xnz
          fA(-2:imx+3, -2:jmx+2, -2:kmx+2)   => xA

        case('y')
          ii  =  0
          jj  =  1
          kk  =  0
          fnx => ynx
          fny => yny
          fnz => ynz
          fA(-2:imx+2, -2:jmx+3, -2:kmx+2)   => yA

        case('z')
          ii  =  0
          jj  =  0
          kk  =  1
          fnx => znx
          fny => zny
          fnz => znz
          fA(-2:imx+2, -2:jmx+2, -2:kmx+3)   => zA

        case Default
          Fatal_error

      end select


      !---------------------------------------------------------------------
      ! Calculating the turbulent viscous fluxes at the faces
      !--------------------------------------------------------------------
      do k = 1, kmx - 1 + kk
       do j = 1, jmx - 1 + jj
        do i = 1, imx - 1 + ii

          !--- FACE Gradients ---!
          ! distance between cell center of adjacent cell for the i,j,k face
          delx = CellCenter(i, j, k, 1) - CellCenter(i-ii, j-jj, k-kk, 1)
          dely = CellCenter(i, j, k, 2) - CellCenter(i-ii, j-jj, k-kk, 2)
          delz = CellCenter(i, j, k, 3) - CellCenter(i-ii, j-jj, k-kk, 3)

          d_LR = delx*delx + dely*dely + delz*delz

          ! difference in state across face
          deltk = tk(i, j, k) - tk(i-ii, j-jj, k-kk)
          deltw = tw(i, j, k) - tw(i-ii, j-jj, k-kk)

          dtkdx       =  deltk * delx / d_LR
          dtkdy       =  deltk * dely / d_LR
          dtkdz       =  deltk * delz / d_LR

          dtwdx       =  deltw * delx / d_LR
          dtwdy       =  deltw * dely / d_LR
          dtwdz       =  deltw * delz / d_LR
          ! ---end of gradient of calculation  ----!

          mu_f     = 0.5*(    mu(i-ii, j-jj, k-kk) +     mu(i, j, k))
          mut_f    = 0.5*(sst_mu(i-ii, j-jj, k-kk) + sst_mu(i, j, k))
          F1       = 0.5*(sst_F1(i-ii, j-jj, k-kk) + sst_F1(i, j, k))
          sigma_kf = sigma_k1*F1 + sigma_k2*(1.0 - F1)
          sigma_wf = sigma_w1*F1 + sigma_w2*(1.0 - F1)

          total_mu = mu_f + mut_f
          rhoface  = 0.5 * (density(i-ii, j-jj, k-kk) + density(i, j, k))
          tkface   = 0.5 * (     tk(i-ii, j-jj, k-kk) +      tk(i, j, k))
          ! k in reynolds stress
          Tau_xx = -2.0*rhoface*tkface/3.0
          Tau_yy = Tau_xx
          Tau_zz = Tau_xx

          ! calling some element from memory and keep them handy for calculation
          nx    = fnx(i,j,k)
          ny    = fny(i,j,k)
          nz    = fnz(i,j,k)
          area  =  fA(i,j,k)

          ! adding viscous fluxes to stored convective flux
          F(i, j, k, 2) = F(i, j, k, 2) - (Tau_xx * nx * area)
          F(i, j, k, 3) = F(i, j, k, 3) - (Tau_yy * ny * area)
          F(i, j, k, 4) = F(i, j, k, 4) - (Tau_zz * nz * area)
          F(i, j, k, 5) = F(i, j, k, 5) - (area*((mu_f + sigma_kf*mut_f)*(dtkdx*nx + dtkdy*ny + dtkdz*nz)))
          F(i, j, k, 6) = F(i, j, k, 6) - (area*((mu_f + sigma_kf*mut_f)*(dtkdx*nx + dtkdy*ny + dtkdz*nz)))
          F(i, j, k, 7) = F(i, j, k, 7) - (area*((mu_f + sigma_wf*mut_f)*(dtwdx*nx + dtwdy*ny + dtwdz*nz)))
         
        end do
       end do
      end do
    end subroutine compute_viscous_fluxes_sst


    subroutine compute_viscous_fluxes_kkl(F, direction)
      implicit none
      character(len=*), intent(in) :: direction ! face direction
      real, dimension(:, :, :, :), pointer, intent(inout) :: F ! flux array
      ! local variables
      real :: tkface
      real :: rhoface
      real :: d_LR
      real :: mu_f
      real :: mut_f
      real :: total_mu
      real :: delx
      real :: dely
      real :: delz
      real :: deltk
      real :: deltkl
      real :: Tau_xx
      real :: Tau_yy
      real :: Tau_zz
      real :: nx
      real :: ny
      real :: nz
      real :: area
      real, dimension(:, :, :), pointer :: fA
      real, dimension(:, :, :), pointer :: fnx
      real, dimension(:, :, :), pointer :: fny
      real, dimension(:, :, :), pointer :: fnz
      integer :: i, j, k
      integer :: ii, jj, kk
      !--- kkl variable requirement  ---!
      real :: dtkdx, dtkdy, dtkdz
      real :: dtkldx, dtkldy, dtkldz



      !--------------------------------------------------------------------
      ! select Direction
      !--------------------------------------------------------------------
      select case(trim(direction))
        case('x')
          ii  =  1
          jj  =  0
          kk  =  0
          fnx => xnx
          fny => xny
          fnz => xnz
          fA(-2:imx+3, -2:jmx+2, -2:kmx+2)   => xA

        case('y')
          ii  =  0
          jj  =  1
          kk  =  0
          fnx => ynx
          fny => yny
          fnz => ynz
          fA(-2:imx+2, -2:jmx+3, -2:kmx+2)   => yA

        case('z')
          ii  =  0
          jj  =  0
          kk  =  1
          fnx => znx
          fny => zny
          fnz => znz
          fA(-2:imx+2, -2:jmx+2, -2:kmx+3)   => zA

        case Default
          Fatal_error

      end select


      !---------------------------------------------------------------------
      ! Calculating the turbulent viscous fluxes at the faces
      !--------------------------------------------------------------------
      do k = 1, kmx - 1 + kk
       do j = 1, jmx - 1 + jj
        do i = 1, imx - 1 + ii

          !--- FACE Gradients ---!
          ! distance between cell center of adjacent cell for the i,j,k face
          delx = CellCenter(i, j, k, 1) - CellCenter(i-ii, j-jj, k-kk, 1)
          dely = CellCenter(i, j, k, 2) - CellCenter(i-ii, j-jj, k-kk, 2)
          delz = CellCenter(i, j, k, 3) - CellCenter(i-ii, j-jj, k-kk, 3)

          d_LR = delx*delx + dely*dely + delz*delz

          ! difference in state across face
          deltk  =  tk(i, j, k) -  tk(i-ii, j-jj, k-kk)
          deltkl = tkl(i, j, k) - tkl(i-ii, j-jj, k-kk)

          dtkdx  =  deltk  * delx / d_LR
          dtkdy  =  deltk  * dely / d_LR
          dtkdz  =  deltk  * delz / d_LR

          dtkldx =  deltkl * delx / d_LR
          dtkldy =  deltkl * dely / d_LR
          dtkldz =  deltkl * delz / d_LR
          !--- end of gradient calculation ---!

          mu_f     = 0.5*(    mu(i-ii, j-jj, k-kk) +     mu(i, j, k))
          mut_f    = 0.5*(kkl_mu(i-ii, j-jj, k-kk) + kkl_mu(i, j, k))

          total_mu = mu_f + mut_f
          rhoface  = 0.5 * (density(i-ii, j-jj, k-kk) + density(i, j, k))
          tkface   = 0.5 * (     tk(i-ii, j-jj, k-kk) +      tk(i, j, k))
          ! k in reynolds stress
          Tau_xx = -2.0*rhoface*tkface/3.0
          Tau_yy = Tau_xx
          Tau_zz = Tau_xx

          ! calling some element from memory and keep them handy for calculation
          nx    = fnx(i,j,k)
          ny    = fny(i,j,k)
          nz    = fnz(i,j,k)
          area  =  fA(i,j,k)

          ! adding viscous fluxes to stored convective flux
          F(i, j, k, 2) = F(i, j, k, 2) - (Tau_xx * nx * area)
          F(i, j, k, 3) = F(i, j, k, 3) - (Tau_yy * ny * area)
          F(i, j, k, 4) = F(i, j, k, 4) - (Tau_zz * nz * area)
          F(i, j, k, 5) = F(i, j, k, 5) - (area*((mu_f + sigma_k*mut_f)*(dtkdx*nx + dtkdy*ny + dtkdz*nz)))
          F(i, j, k, 6) = F(i, j, k, 6) - (area*((mu_f + sigma_k*mut_f)*(dtkdx*nx + dtkdy*ny + dtkdz*nz)))
          F(i, j, k, 7) = F(i, j, k, 7) - (area*((mu_f + sigma_phi*mut_f)*(dtkldx*nx + dtkldy*ny + dtkldz*nz)))
         
        end do
       end do
      end do

    end subroutine compute_viscous_fluxes_kkl

end module viscous