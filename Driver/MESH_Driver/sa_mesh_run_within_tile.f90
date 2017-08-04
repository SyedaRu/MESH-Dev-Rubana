module sa_mesh_run_within_tile

    implicit none

!>>>irrigation
    real, save :: IRTOT
    real, dimension(:), allocatable, save :: IRSUM, IRALL, NEWPRE, OLDPRE, IRCAL
    real, dimension(:, :), allocatable, save :: IR, CHECK, LQSUM

    contains

    subroutine run_within_tile_init(shd, fls, ts, cm, wb, eb, sp, stfl, rrls)

        use mpi_shared_variables
        use sa_mesh_shared_parameters
        use sa_mesh_shared_variables
        use model_files_variables
        use model_dates
        use climate_forcing
        use model_output_variabletypes
        use MODEL_OUTPUT

        use RUNCLASS36_config
        use RUNSVS113_config
        use baseflow_module

        !> Cropland irrigation module.
        use cropland_irrigation_init, only: runci_init

        type(ShedGridParams) :: shd
        type(fl_ids) :: fls
        type(dates_model) :: ts
        type(clim_info) :: cm
        type(water_balance) :: wb
        type(energy_balance) :: eb
        type(soil_statevars) :: sp
        type(streamflow_hydrograph) :: stfl
        type(reservoir_release) :: rrls

        integer NML, NSL
        NML = shd%lc%NML
        NSL = shd%lc%IGND

        !> Irrigation
        allocate(IRSUM(NML), IRALL(NML), NEWPRE(NML), OLDPRE(NML), IRCAL(NML))
        allocate(IR(NML, NSL), CHECK(NML, NSL), LQSUM(NML, NSL))
        if (ipid == 0) then
            open(unit = 1981, file = "irrigation.csv")
            write(1981, 1010) 'YEAR', 'DAY', 'HOUR', 'MINS', 'IRCAL', 'IRSUM', 'IRTOT', 'OLDPRE', 'NEWPRE'
!            open(unit = 1950, file = "irrigation2.txt")
        end if

        call RUNCLASS36_init(shd, fls, ts, cm, wb, eb, sp, stfl, rrls)

        call RUNSVS113_init(shd, fls, ts, cm, wb, eb, sp)

        call LZS_init(shd, fls, ts, cm, wb, eb, sp, stfl, rrls)

        !> Cropland irrigation module.
        call runci_init(shd, fls)

1010    format(9999(g15.7e2, ','))

    end subroutine

    function run_within_tile(shd, fls, ts, cm, wb, eb, sp, stfl, rrls)

        use mpi_shared_variables
        use sa_mesh_shared_variables
        use sa_mesh_shared_parameters
        use model_files_variables
        use model_dates
        use climate_forcing
        use model_output_variabletypes
        use MODEL_OUTPUT

        use cropland_irrigation_within_tile, only: runci_within_tile
        use RUNCLASS36_module, only: RUNCLASS36_within_tile
        use RUNSVS113_module, only: RUNSVS113
        use WF_ROUTE_module, only: WF_ROUTE_within_tile
        use baseflow_module

        character(100) run_within_tile

        type(ShedGridParams) :: shd
        type(fl_ids) :: fls
        type(dates_model) :: ts
        type(clim_info) :: cm
        type(water_balance) :: wb
        type(energy_balance) :: eb
        type(soil_statevars) :: sp
        type(streamflow_hydrograph) :: stfl
        type(reservoir_release) :: rrls

        integer k, j

        stas%cnpy%pevp(il1:il2) = 0.0
        stas%sfc%evap(il1:il2) = 0.0
        stas%cnpy%evpb(il1:il2) = 0.0
        stas%sfc%qevp(il1:il2) = 0.0
        stas%sfc%hfs(il1:il2) = 0.0
        stas%sfc%rofo(il1:il2) = 0.0
        stas%sl%rofs(il1:il2) = 0.0
        stas%lzs%rofb(il1:il2) = 0.0

        run_within_tile = ''

!>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> irrigation uing soil moisture
    if (ipid /= 0 .or. izero == 0) then
!csfv%THFC(,) = field capacity
!csfv%GRKS(,) = Hydraulic conductivity of soil at saturation Ksat
!cpv%THLQ(,) or THLIQC = Liquid water content of soil layers under vegetation
!cpv%THIC(k, j)
!csfv%DELZW (,) or shd%lc%sl%DELZ permeable or soil layer thickness
!cfi%PRE or catv%RPRE,  wb%EVAP or cdv%QFS
!csfv%FCAN(,) Tile in grid/GRU
!FROOT(,) Fraction of water-accessing vegetation roots in soil layer
             IRSUM = 0.0
             IR = 0.0
             CHECK = 0.0
             LQSUM = 0.0
             IRALL = 0.0
             IRTOT = 0.0
             NEWPRE = 0.0
             OLDPRE = 0.0
             IRCAL = 0.0

             do k = il1, il2 !GRU -> loop for timestep
                IRALL(k) = 0.0   !initialization for each time step
                if (pm%tp%mid(k) == 9) then ! check irrDist GRU
!               ik = shd%lc%ILMOS(k) ! complete grid/all GRU
!                    do j = 1, shd%lc%IGND ! loop for each Soil layers
                     do j = 1, 3 ! loop for each Soil layers
                       CHECK(k,j) = 0.5*pm%slp%thfc(k,j) ! calculate 50% of field capacity
                       LQSUM(k,j) =  stas%sl%thlq(k, j) + stas%sl%thic(k, j) ! sum liquid and ice water content in soil
!                       LQSUM(k,j) =  stas%sl%thlq(k, j)
                        if (LQSUM(k,j) < CHECK(k,j))then ! check if sum of soil moisture is less than 50% of FC
                         IR(k,j) = (pm%slp%thfc(k,j) - LQSUM(k,j)) * stas%sl%delzw(k, j) ! calculate irrigation water for each permeable soil depth
!                        write(*, "('THFC, LQSUM, DELZW, IR, SoilLayer',4f8.4,i3)")csfv%THFC(k,j), LQSUM(k,j), csfv%DELZW(k, j), IR(k,j), j
                        else
                         IR(k,j) = 0.0
                        end if
                       IRALL(k) = IRALL(k) + IR(k,j) ! sum of complete soil depth
                    end do !soil layer
!                IRCAL(k) = (IRALL(k)*(1000.0/ic%dts)) - cm%dat(ck%RT)%GAT(k)
                IRCAL(k) = (IRALL(k)*(1000.0/ic%dts)) ! convert into mm/sec
                IRSUM(k) = max(IRCAL(k)- cm%dat(ck%RT)%GAT(k), 0.0) ! subtract current precipitation to calculate actual requirement if there is rain
                OLDPRE(k) = cm%dat(ck%RT)%GAT(k)
                cm%dat(ck%RT)%GAT(k) = cm%dat(ck%RT)%GAT(k) + IRSUM(k) ! add irrigation water into precipitation
                NEWPRE(k) = cm%dat(ck%RT)%GAT(k)
               end if ! check Crop GRU tile
!              IRTOT = sum(IRSUM)
              if (IRCAL(k) > 0.0) then
!               !do k = il1, il2
                !abstraction(shd%lc%ILMOS(k)) = abstraction(shd%lc%ILMOS(k)) + (IRCAL(k)*0.000001) ! convert to m3
                !end do
              end if
             end do ! GRU tile
!            write(1981, "('IRCAL, IRSUM,IRTOT, OLDPRE, NEWPRE',5f12.8)")sum(IRCAL),sum(IRSUM),IRTOT,sum(OLDPRE),sum(NEWPRE)

!            close(1981)

            !! if (ic%now%hour == 0) then
            !!  it's a new day
            !! else if (ic%now%hour == 23) then
            !!  it's the end of the day
            !! end if

        end if

!>>>>>>>>>>>>>>>>>>>>>>>> CALL to CLASS

        call RUNCLASS36_within_tile(shd, fls, ts, cm, wb, eb, sp, stfl, rrls)

        call RUNSVS113(shd, fls, ts, cm, wb, eb, sp)

!+        call LZS_within_tile(shd, fls, ts, cm, wb, eb, sp, stfl, rrls)

        run_within_tile = WF_ROUTE_within_tile(shd, stfl, rrls)
        if (len_Trim(run_within_tile) > 0) return

        !> Cropland irrigation module (PEVP).
        call runci_within_tile(shd, fls, cm)

        !> MPI exchange.
        call run_within_tile_mpi(shd, cm)

        if (ipid == 0) then
               IRTOT = sum(IRSUM)
               write(1981, 1010) &
                    ic%now%year,ic%now%jday,ic%now%hour,ic%now%mins, &
                    sum(IRCAL),sum(IRSUM),IRTOT,sum(OLDPRE),sum(NEWPRE)
!        if (sum(IRSUM) > 0.0) then
!              print "('IRCAL, IRSUM,IRTOT, OLDPRE, NEWPRE',4i4,5f12.8)", &
!                   ic%now%year,ic%now%jday,ic%now%hour,ic%now%mins, &
!                   sum(IRCAL),sum(IRSUM),IRTOT,sum(OLDPRE),sum(NEWPRE)
!        end if
        end if

        where (stas%cnpy%pevp(il1:il2) /= 0.0)
            stas%cnpy%evpb(il1:il2) = stas%sfc%evap(il1:il2)/stas%cnpy%pevp(il1:il2)
            stas%cnpy%arrd(il1:il2) = cm%dat(ck%RT)%GAT(il1:il2)/stas%cnpy%pevp(il1:il2)
        end where

        return

1010    format(9999(g15.7e2, ','))

    end function

    subroutine run_within_tile_mpi(shd, cm)

        !> For: MPI variables, barrier flag, il1:il2 parse utility
        use mpi_flags
        use mpi_shared_variables
        use mpi_module
        use mpi_utilities

        !> For: Model states, 'ic', 'cm'.
        use sa_mesh_shared_variables
        use model_dates
        use climate_forcing

        !> For: SAVERESUMEFLAG, RESUMEFLAG.
        use FLAGS

        !> For BASEFLOWFLAG.
!todo: Isolate this.
        use baseflow_module

        !> Input variables.
        type(ShedGridParams) :: shd
        type(clim_info) :: cm

        !> Local variables.
        integer ipid_recv, itag, ierrcode, istop, i, j, u, invars, iilen, ii1, ii2, ierr
        logical lstat
        integer, dimension(:), allocatable :: irqst
        integer, dimension(:, :), allocatable :: imstat

        !> Gather variables from parallel nodes.

        !> Send/receive process.
        itag = ic%ts_count*1000
        invars = 13 + 4*shd%lc%IGND

        !> Update the variable count per the active control flags.
        if (SAVERESUMEFLAG >= 3 .and. SAVERESUMEFLAG <= 5) invars = invars + 10 + 4

        !> BASEFLOWFLAG.
        if (lzsp%BASEFLOWFLAG > 0) then
            invars = invars + 1
            if (lzsp%BASEFLOWFLAG == 1) then
                invars = invars + 1
            end if
        end if

!>>>>>>>>>>>>>>>>>>>>>>>>> IRRIGATION NUMBER OF PARAMETERS FOR SEND/RECV <<<<<<<<<<<<< MPI
        invars = invars + 5
!<<<<<<<<<<<<<<<<<<<<<<<<<<

        if (inp > 1 .and. ipid /= 0) then

            !> Send data back to head-node.
            if (allocated(irqst)) deallocate(irqst)
            if (allocated(imstat)) deallocate(imstat)
            allocate(irqst(invars), imstat(mpi_status_size, invars))
            irqst = mpi_request_null

            i = 1
!-            call mpi_isend(cfi%PRE(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(stas%sfc%evap(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(stas%cnpy%pevp(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
!-            call mpi_isend(cdv%ROF(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(stas%sfc%rofo(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(stas%sl%rofs(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(stas%lzs%rofb(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(stas%cnpy%sncan(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(stas%cnpy%rcan(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(stas%sfc%zpnd(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(stas%sno%sno(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(stas%sno%fsno(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(stas%sno%wsno(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(stas%sfc%hfs(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(stas%sfc%qevp(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            do j = 1, shd%lc%IGND
                call mpi_isend(stas%sl%thlq(il1:il2, j), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_isend(stas%sl%thic(il1:il2, j), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_isend(stas%sl%gflx(il1:il2, j), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_isend(stas%sl%tbar(il1:il2, j), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            end do

            !> Send optional variables per the active control flags.
            if (SAVERESUMEFLAG >= 3 .and. SAVERESUMEFLAG <= 5) then
                call mpi_isend(stas%sno%albs(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_isend(stas%cnpy%cmai(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_isend(stas%cnpy%gro(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_isend(stas%cnpy%qac(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_isend(stas%sno%rhos(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_isend(stas%cnpy%tac(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_isend(stas%sl%tbas(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_isend(stas%cnpy%tcan(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_isend(stas%sfc%tpnd(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_isend(stas%sno%tsno(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                do j = 1, 4
                    call mpi_isend(stas%sfc%tsfs(il1:il2, j), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr)
                    i = i + 1
                end do
            end if !(SAVERESUMEFLAG >= 3 .and. SAVERESUMEFLAG <= 5) then

            !> BASEFLOWFLAG.
            if (lzsp%BASEFLOWFLAG > 0) then
                call mpi_isend(Wrchrg(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                if (lzsp%BASEFLOWFLAG == 1) then
                    call mpi_isend(Qb(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                end if
            end if

!>>>>>>>>>>>>>>>>>>>>>>>>> IRRIGATION PARAMETER LIST FOR SEND <<<<<<<<<<<<< MPI
            call mpi_isend(IRCAL(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(IRSUM(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(OLDPRE(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(cm%dat(ck%RT)%GAT(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
            call mpi_isend(NEWPRE(il1:il2), ilen, mpi_real, 0, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
!<<<<<<<<<<<<<<<<<<<<<<<<<<

            lstat = .false.
            do while (.not. lstat)
                call mpi_testall(invars, irqst, lstat, imstat, ierr)
            end do

!            print *, ipid, ' done sending'

        else if (inp > 1) then

            !> Receive data from worker nodes.
            if (allocated(irqst)) deallocate(irqst)
            if (allocated(imstat)) deallocate(imstat)
            allocate(irqst(invars), imstat(mpi_status_size, invars))

            !> Receive and assign variables.
            do u = 1, (inp - 1)

!                print *, 'initiating irecv for:', u, ' with ', itag

                irqst = mpi_request_null
                imstat = 0

                call mpi_split_nml(inp, izero, u, shd%lc%NML, shd%lc%ILMOS, ii1, ii2, iilen)

                i = 1
!-                call mpi_irecv(cfi%PRE(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(stas%sfc%evap(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(stas%cnpy%pevp(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
!-                call mpi_irecv(cdv%ROF(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(stas%sfc%rofo(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(stas%sl%rofs(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(stas%lzs%rofb(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(stas%cnpy%sncan(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(stas%cnpy%rcan(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(stas%sfc%zpnd(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(stas%sno%sno(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(stas%sno%fsno(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(stas%sno%wsno(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(stas%sfc%hfs(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(stas%sfc%qevp(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                do j = 1, shd%lc%IGND
                    call mpi_irecv(stas%sl%thlq(ii1:ii2, j), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr)
                    i = i + 1
                    call mpi_irecv(stas%sl%thic(ii1:ii2, j), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr)
                    i = i + 1
                    call mpi_irecv(stas%sl%gflx(ii1:ii2, j), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr)
                    i = i + 1
                    call mpi_irecv(stas%sl%tbar(ii1:ii2, j), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr)
                    i = i + 1
                end do

                !> Send optional variables per the active control flags.
                if (SAVERESUMEFLAG >= 3 .and. SAVERESUMEFLAG <= 5) then
                    call mpi_irecv(stas%sno%albs(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                    call mpi_irecv(stas%cnpy%cmai(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                    call mpi_irecv(stas%cnpy%gro(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                    call mpi_irecv(stas%cnpy%qac(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                    call mpi_irecv(stas%sno%rhos(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                    call mpi_irecv(stas%cnpy%tac(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                    call mpi_irecv(stas%sl%tbas(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                    call mpi_irecv(stas%cnpy%tcan(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                    call mpi_irecv(stas%sfc%tpnd(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                    call mpi_irecv(stas%sno%tsno(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                    do j = 1, 4
                        call mpi_irecv(stas%sfc%tsfs(ii1:ii2, j), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr)
                        i = i + 1
                    end do
                end if !(SAVERESUMEFLAG >= 3 .and. SAVERESUMEFLAG <= 5) then

                !> BASEFLOWFLAG.
                if (lzsp%BASEFLOWFLAG > 0) then
                    call mpi_irecv(Wrchrg(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                    if (lzsp%BASEFLOWFLAG == 1) then
                        call mpi_irecv(Qb(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                    end if
                end if

!>>>>>>>>>>>>>>>>>>>>>>>>> IRRIGATION PARAMETER LIST FOR RECV <<<<<<<<<<<<< MPI
                call mpi_irecv(IRCAL(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(IRSUM(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(OLDPRE(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(cm%dat(ck%RT)%GAT(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
                call mpi_irecv(NEWPRE(ii1:ii2), iilen, mpi_real, u, itag + i, mpi_comm_world, irqst(i), ierr); i = i + 1
!<<<<<<<<<<<<<<<<<<<<<<<<<<

                lstat = .false.
                do while (.not. lstat)
                    call mpi_testall(invars, irqst, lstat, imstat, ierr)
                end do

            end do !u = 1, (inp - 1)
!            print *, 'done receiving'

        end if !(inp > 1 .and. ipid /= 0) then

        if (inp > 1 .and. ic%ts_daily == MPIUSEBARRIER) call MPI_Barrier(MPI_COMM_WORLD, ierr)

    end subroutine

    subroutine run_within_tile_finalize(fls, shd, cm, wb, eb, sv, stfl, rrls)

        use model_files_variabletypes
        use sa_mesh_shared_variables
        use model_dates
        use climate_forcing
        use model_output_variabletypes
        use MODEL_OUTPUT

        use RUNCLASS36_config, only: RUNCLASS36_finalize
        use baseflow_module

        type(fl_ids) :: fls
        type(ShedGridParams) :: shd
        type(clim_info) :: cm
        type(water_balance) :: wb
        type(energy_balance) :: eb
        type(soil_statevars) :: sv
        type(streamflow_hydrograph) :: stfl
        type(reservoir_release) :: rrls

        call RUNCLASS36_finalize(fls, shd, cm, wb, eb, sv, stfl, rrls)

        call LZS_finalize(fls, shd)

    end subroutine

end module
