module save_basin_output

    !> For: type(energy_balance).
    use MODEL_OUTPUT

    implicit none

    private update_water_balance, save_water_balance

    !> Global types.

    !> For basin water balance.

    type BasinWaterBalance
        real, dimension(:), allocatable :: PRE, EVAP, ROF, ROFO, ROFS, ROFB, STG_INI, STG_FIN
    end type

    type, extends(BasinWaterBalance) :: BasinWaterStorage
        real, dimension(:), allocatable :: RCAN, SNCAN, SNO, WSNO, PNDW
        real, dimension(:, :), allocatable :: LQWS, FRWS
    end type

    type BasinOutput
        type(BasinWaterStorage), dimension(:), allocatable :: wb
    end type

    !> Local type instances.

    type(BasinOutput), save, private :: bno

    !> Indices for basin average output.
    !* IKEY_ACC: Accumulated over the run (per time-step).
    !* IKEY_MIN: Min. index of the basin averages (used in the allocation of the variables).
    !* IKEY_MAX: Max. number of indices (used in the allocation of the variables).
    !* IKEY_DLY: Daily average.
    !* IKEY_MLY: Monthly average.
    !* IKEY_HLY: Hourly average.
    !*(IKEY_SSL: Seasonal average.)
    integer, private :: IKEY_ACC = 1, IKEY_DLY = 2, IKEY_MLY = 3, IKEY_HLY = 4, IKEY_TSP = 5, NKEY = 5

    type(energy_balance) :: eb_out

    contains

    !> Global routines.

    subroutine run_save_basin_output_init(shd, fls, ts, cm, wb, eb, sp, stfl, rrls)

        use sa_mesh_shared_variabletypes
        use sa_mesh_shared_variables
        use FLAGS
        use model_files_variabletypes
        use model_files_variables
        use model_dates
        use climate_forcing
        use model_output_variabletypes
        use MODEL_OUTPUT

        type(ShedGridParams) :: shd
        type(fl_ids) :: fls
        type(dates_model) :: ts
        type(clim_info) :: cm
        type(water_balance) :: wb
        type(energy_balance) :: eb
        type(soil_statevars) :: sp
        type(streamflow_hydrograph) :: stfl
        type(reservoir_release) :: rrls

        !> Local variables for formatting headers for the output files.
        character(20) IGND_CHAR
        character(500) WRT_900_FMT, WRT_900_2, WRT_900_3, WRT_900_4

        !> Local variables.
        integer NAA, NSL, ikey, ii, i, j, iun, ierr

        !> Return if basin output has been disabled.
        if (BASINBALANCEOUTFLAG == 0) return

        !> Allocate and zero variables for accumulations.
        NAA = shd%NAA
        NSL = shd%lc%IGND
        allocate(bno%wb(NKEY))
        do ikey = 1, NKEY
            allocate(bno%wb(ikey)%PRE(NAA), bno%wb(ikey)%EVAP(NAA), bno%wb(ikey)%ROF(NAA), &
                     bno%wb(ikey)%ROFO(NAA), bno%wb(ikey)%ROFS(NAA), bno%wb(ikey)%ROFB(NAA), &
                     bno%wb(ikey)%RCAN(NAA), bno%wb(ikey)%SNCAN(NAA), &
                     bno%wb(ikey)%SNO(NAA), bno%wb(ikey)%WSNO(NAA), bno%wb(ikey)%PNDW(NAA), &
                     bno%wb(ikey)%LQWS(NAA, NSL), bno%wb(ikey)%FRWS(NAA, NSL), &
                     bno%wb(ikey)%STG_INI(NAA), bno%wb(ikey)%STG_FIN(NAA))
            bno%wb(ikey)%PRE = 0.0
            bno%wb(ikey)%EVAP = 0.0
            bno%wb(ikey)%ROF = 0.0
            bno%wb(ikey)%ROFO = 0.0
            bno%wb(ikey)%ROFS = 0.0
            bno%wb(ikey)%ROFB = 0.0
            bno%wb(ikey)%RCAN = 0.0
            bno%wb(ikey)%SNCAN = 0.0
            bno%wb(ikey)%SNO = 0.0
            bno%wb(ikey)%WSNO = 0.0
            bno%wb(ikey)%PNDW = 0.0
            bno%wb(ikey)%LQWS = 0.0
            bno%wb(ikey)%FRWS = 0.0
            bno%wb(ikey)%STG_INI = 0.0
        end do
        allocate(eb_out%HFS(2:2), eb_out%QEVP(2:2), eb_out%GFLX(2:2, NSL))
        eb_out%QEVP = 0.0
        eb_out%HFS = 0.0

        !> Create a header that accounts for the proper number of soil layers.
        WRT_900_2 = 'LQWS'
        WRT_900_3 = 'FRWS'
        WRT_900_4 = 'ALWS'
        do j = 1, NSL
            write(IGND_CHAR, '(i1)') j
            if (j < NSL) then
                WRT_900_2 = trim(adjustl(WRT_900_2)) // trim(adjustl(IGND_CHAR)) // ',LQWS'
                WRT_900_3 = trim(adjustl(WRT_900_3)) // trim(adjustl(IGND_CHAR)) // ',FRWS'
                WRT_900_4 = trim(adjustl(WRT_900_4)) // trim(adjustl(IGND_CHAR)) // ',ALWS'
            else
                WRT_900_2 = trim(adjustl(WRT_900_2)) // trim(adjustl(IGND_CHAR)) // ','
                WRT_900_3 = trim(adjustl(WRT_900_3)) // trim(adjustl(IGND_CHAR)) // ','
                WRT_900_4 = trim(adjustl(WRT_900_4)) // trim(adjustl(IGND_CHAR)) // ','
            end if
        end do !> j = 1, NSL
        WRT_900_FMT = 'PREACC,EVAPACC,ROFACC,ROFOACC,' // &
                      'ROFSACC,ROFBACC,PRE,EVAP,ROF,ROFO,ROFS,ROFB,SNCAN,RCAN,SNO,WSNO,PNDW,' // &
                      trim(adjustl(WRT_900_2)) // &
                      trim(adjustl(WRT_900_3)) // &
                      trim(adjustl(WRT_900_4)) // &
                      'LQWS,FRWS,ALWS,STG,DSTG,DSTGACC'

        !> Daily.
        if (btest(BASINAVGWBFILEFLAG, 0)) then
            open(fls%fl(mfk%f900)%iun, &
                 file = './' // trim(fls%GENDIR_OUT) // '/' // trim(adjustl(fls%fl(mfk%f900)%fn)), &
                 iostat = ierr)
            write(fls%fl(mfk%f900)%iun, '(a)') 'DAY,YEAR,' // trim(adjustl(WRT_900_FMT))
        end if

        !> Monthly.
        if (btest(BASINAVGWBFILEFLAG, 1)) then
            open(902, file = './' // trim(fls%GENDIR_OUT) // '/Basin_average_water_balance_Monthly.csv')
            write(902, '(a)') 'DAY,YEAR,' // trim(adjustl(WRT_900_FMT))
        end if

        !> Hourly.
        if (btest(BASINAVGWBFILEFLAG, 2)) then
            open(903, file = './' // trim(fls%GENDIR_OUT) // '/Basin_average_water_balance_Hourly.csv')
            write(903, '(a)') 'DAY,YEAR,HOUR,' // trim(adjustl(WRT_900_FMT))
        end if

        !> Per time-step.
        if (btest(BASINAVGWBFILEFLAG, 3)) then
            open(904, file = './' // trim(fls%GENDIR_OUT) // '/Basin_average_water_balance_ts.csv')
            write(904, '(a)') 'DAY,YEAR,HOUR,MINS,' // trim(adjustl(WRT_900_FMT))
        end if

        !> Open CSV output files for the energy balance and write the header.
        open(901, file = './' // trim(fls%GENDIR_OUT) // '/Basin_average_energy_balance.csv')
        write(901, '(a)') 'DAY,YEAR,HFS,QEVP'

        !> Calculate initial storage and aggregate through neighbouring cells.
        do ikey = 1, NKEY
            bno%wb(ikey)%STG_INI = wb%RCAN + wb%SNCAN + wb%SNO + wb%WSNO + wb%PNDW + sum(wb%LQWS, 2) + sum(wb%FRWS, 2)
        end do
        do i = 1, shd%NAA - 1
            ii = shd%NEXT(i)
            do ikey = 1, NKEY
                bno%wb(ikey)%STG_INI(ii) = bno%wb(ikey)%STG_INI(ii) + bno%wb(ikey)%STG_INI(i)
            end do
        end do

        !> Read initial variables values from file.
        if (RESUMEFLAG == 4 .or. RESUMEFLAG == 5) then

            !> Open the resume file.
            iun = fls%fl(mfk%f883)%iun
            open(iun, file = trim(adjustl(fls%fl(mfk%f883)%fn)) // '.basin_output', status = 'old', action = 'read', &
                 form = 'unformatted', access = 'sequential', iostat = ierr)
!todo: condition for ierr.

            !> Basin totals for the water balance.
            read(iun)
            read(iun)
            read(iun)
            read(iun)
            read(iun)
            read(iun)
            read(iun)
            read(iun)
            read(iun)
            read(iun)
            read(iun)
            read(iun)
            read(iun)
            read(iun)

            !> Other accumulators for the water balance.
            do i = 1, NKEY
                read(iun) bno%wb(i)%PRE(shd%NAA)
                read(iun) bno%wb(i)%EVAP(shd%NAA)
                read(iun) bno%wb(i)%ROF(shd%NAA)
                read(iun) bno%wb(i)%ROFO(shd%NAA)
                read(iun) bno%wb(i)%ROFS(shd%NAA)
                read(iun) bno%wb(i)%ROFB(shd%NAA)
                read(iun) bno%wb(i)%RCAN(shd%NAA)
                read(iun) bno%wb(i)%SNCAN(shd%NAA)
                read(iun) bno%wb(i)%SNO(shd%NAA)
                read(iun) bno%wb(i)%WSNO(shd%NAA)
                read(iun) bno%wb(i)%PNDW(shd%NAA)
                read(iun) bno%wb(i)%LQWS(shd%NAA, :)
                read(iun) bno%wb(i)%FRWS(shd%NAA, :)
                read(iun) bno%wb(i)%STG_INI(shd%NAA)
            end do

            !> Energy balance.
            read(iun) eb_out%QEVP
            read(iun) eb_out%HFS

            !> Close the file to free the unit.
            close(iun)

        end if !(RESUMEFLAG == 4 .or. RESUMEFLAG == 5) then

    end subroutine

    subroutine run_save_basin_output(shd, fls, ts, cm, wb, eb, sp, stfl, rrls)

        use sa_mesh_shared_variabletypes
        use sa_mesh_shared_variables
        use FLAGS
        use model_files_variabletypes
        use model_files_variables
        use model_dates
        use climate_forcing
        use model_output_variabletypes
        use MODEL_OUTPUT

        !> Input variables.
        type(ShedGridParams) :: shd
        type(fl_ids) :: fls
        type(dates_model) :: ts
        type(clim_info) :: cm
        type(water_balance) :: wb
        type(energy_balance) :: eb
        type(soil_statevars) :: sp
        type(streamflow_hydrograph) :: stfl
        type(reservoir_release) :: rrls

        !> Local variables.
        integer nmth, ndy
        real dnar

        !> Return if basin output has been disabled.
        if (BASINBALANCEOUTFLAG == 0) return

        !> Update the water balance.
        call update_water_balance(shd, wb, shd%NAA, shd%lc%IGND)

        !> Hourly (wb): IKEY_HLY
        if (mod(ic%ts_hourly, 3600/ic%dts) == 0 .and. btest(BASINAVGWBFILEFLAG, 2)) then
!todo: change this to pass the index of the file object.
            call save_water_balance(shd, fls, 903, 3600, shd%NAA, IKEY_HLY)
        end if

        !> Daily (wb, eb): IKEY_DLY
        if (mod(ic%ts_daily, 86400/ic%dts) == 0) then
            if (btest(BASINAVGWBFILEFLAG, 0)) call save_water_balance(shd, fls, fls%fl(mfk%f900)%iun, 86400, shd%NAA, IKEY_DLY)

            !> Energy balance.
            dnar = wb%basin_area
            write(901, "(i4,',', i5,',', 999(e12.5,','))") &
                  ic%now%jday, ic%now%year, &
                  eb_out%HFS(IKEY_DLY)/dnar, &
                  eb_out%QEVP(IKEY_DLY)/dnar
        end if

        !> Monthly (wb): IKEY_MLY
        if (mod(ic%ts_daily, 86400/ic%dts) == 0 .and. btest(BASINAVGWBFILEFLAG, 1)) then

            !> Determine the next day in the month.
            call Julian2MonthDay((ic%now%jday + 1), ic%now%year, nmth, ndy)

            !> Write-out if the next day will be a new month (current day is the last of the month).
            if (ndy == 1 .or. (ic%now%jday + 1) > leap_year(ic%now%year)) then
                call Julian2MonthDay(ic%now%jday, ic%now%year, nmth, ndy)
                call save_water_balance(shd, fls, 902, (86400*ndy), shd%NAA, IKEY_MLY)
            end if
        end if

        !> Time-step (wb): IKEY_TSP
        if (btest(BASINAVGWBFILEFLAG, 3)) call save_water_balance(shd, fls, 904, ic%dts, shd%NAA, IKEY_TSP)

    end subroutine

    subroutine run_save_basin_output_finalize(fls, shd, cm, wb, eb, sv, stfl, rrls)

        use mpi_shared_variables
        use model_files_variabletypes
        use model_files_variables
        use sa_mesh_shared_variabletypes
        use model_dates
        use climate_forcing
        use model_output_variabletypes
        use MODEL_OUTPUT

        type(fl_ids) :: fls
        type(ShedGridParams) :: shd
        type(clim_info) :: cm
        type(water_balance) :: wb
        type(energy_balance) :: eb
        type(soil_statevars) :: sv
        type(streamflow_hydrograph) :: stfl
        type(reservoir_release) :: rrls

        !> Local variables.
        integer iout, i, ierr, iun

        !> Return if not the head node.
        if (ipid /= 0) return

        !> Return if basin output has been disabled.
        if (BASINBALANCEOUTFLAG == 0) return

        !> Save the current state of the variables.
        if (SAVERESUMEFLAG == 4 .or. SAVERESUMEFLAG == 5) then

            !> Open the resume file.
            iun = fls%fl(mfk%f883)%iun
            open(iun, file = trim(adjustl(fls%fl(mfk%f883)%fn)) // '.basin_output', status = 'replace', action = 'write', &
                 form = 'unformatted', access = 'sequential', iostat = ierr)
!todo: condition for ierr.

            !> Basin totals for the water balance.
            write(iun) bno%wb(IKEY_ACC)%PRE(shd%NAA)
            write(iun) bno%wb(IKEY_ACC)%EVAP(shd%NAA)
            write(iun) bno%wb(IKEY_ACC)%ROF(shd%NAA)
            write(iun) bno%wb(IKEY_ACC)%ROFO(shd%NAA)
            write(iun) bno%wb(IKEY_ACC)%ROFS(shd%NAA)
            write(iun) bno%wb(IKEY_ACC)%ROFB(shd%NAA)
            write(iun) bno%wb(IKEY_ACC)%LQWS(shd%NAA, :)
            write(iun) bno%wb(IKEY_ACC)%FRWS(shd%NAA, :)
            write(iun) bno%wb(IKEY_ACC)%RCAN(shd%NAA)
            write(iun) bno%wb(IKEY_ACC)%SNCAN(shd%NAA)
            write(iun) bno%wb(IKEY_ACC)%SNO(shd%NAA)
            write(iun) bno%wb(IKEY_ACC)%WSNO(shd%NAA)
            write(iun) bno%wb(IKEY_ACC)%PNDW(shd%NAA)
            write(iun) bno%wb(IKEY_ACC)%STG_INI(shd%NAA)

            !> Other accumulators for the water balance.
            do i = 1, NKEY
                write(iun) bno%wb(i)%PRE(shd%NAA)
                write(iun) bno%wb(i)%EVAP(shd%NAA)
                write(iun) bno%wb(i)%ROF(shd%NAA)
                write(iun) bno%wb(i)%ROFO(shd%NAA)
                write(iun) bno%wb(i)%ROFS(shd%NAA)
                write(iun) bno%wb(i)%ROFB(shd%NAA)
                write(iun) bno%wb(i)%RCAN(shd%NAA)
                write(iun) bno%wb(i)%SNCAN(shd%NAA)
                write(iun) bno%wb(i)%SNO(shd%NAA)
                write(iun) bno%wb(i)%WSNO(shd%NAA)
                write(iun) bno%wb(i)%PNDW(shd%NAA)
                write(iun) bno%wb(i)%LQWS(shd%NAA, :)
                write(iun) bno%wb(i)%FRWS(shd%NAA, :)
                write(iun) bno%wb(i)%STG_INI(shd%NAA)
            end do

            !> Energy balance.
            write(iun) eb_out%QEVP
            write(iun) eb_out%HFS

            !> Close the file to free the unit.
            close(iun)

        end if !(SAVERESUMEFLAG == 4 .or. SAVERESUMEFLAG == 5) then

    end subroutine

    !> Local routines.

    subroutine update_water_balance(shd, wb, naa, nsl)

        !> For 'shd' variable.
        use sa_mesh_shared_variabletypes

        !> For 'wb' variable.
        use model_output_variabletypes
    
        !> Input variables.
        type(ShedGridParams), intent(in) :: shd
        type(water_balance), intent(in) :: wb
        integer, intent(in) :: naa, nsl

        !> Local variables.
        real, dimension(naa) :: PRE, EVAP, ROF, ROFO, ROFS, ROFB, RCAN, SNCAN, SNO, WSNO, PNDW
        real, dimension(naa, nsl) :: LQWS, FRWS
        integer ikey, ii, i

        !> Accumulate variables and aggregate through neighbouring cells.
        PRE = wb%PRE
        EVAP = wb%EVAP
        ROF = wb%ROF
        ROFO = wb%ROFO
        ROFS = wb%ROFS
        ROFB = wb%ROFB
        RCAN = wb%RCAN
        SNCAN = wb%SNCAN
        SNO = wb%SNO
        WSNO = wb%WSNO
        PNDW = wb%PNDW
        LQWS = wb%LQWS
        FRWS = wb%FRWS

        !> Aggregate through neighbouring cells.
        do i = 1, shd%NAA - 1
            ii = shd%NEXT(i)
            PRE(ii) = PRE(ii) + PRE(i)
            EVAP(ii) = EVAP(ii) + EVAP(i)
            ROF(ii) = ROF(ii) + ROF(i)
            ROFO(ii) = ROFO(ii) + ROFO(i)
            ROFS(ii) = ROFS(ii) + ROFS(i)
            ROFB(ii) = ROFB(ii) + ROFB(i)
            RCAN(ii) = RCAN(ii) + RCAN(i)
            SNCAN(ii) = SNCAN(ii) + SNCAN(i)
            SNO(ii) = SNO(ii) + SNO(i)
            WSNO(ii) = WSNO(ii) + WSNO(i)
            PNDW(ii) = PNDW(ii) + PNDW(i)
            LQWS(ii, :) = LQWS(ii, :) + LQWS(i, :)
            FRWS(ii, :) = FRWS(ii, :) + FRWS(i, :)
        end do

        !> Update run total.
        do ikey = 1, NKEY
            bno%wb(ikey)%PRE = bno%wb(ikey)%PRE + PRE
            bno%wb(ikey)%EVAP = bno%wb(ikey)%EVAP + EVAP
            bno%wb(ikey)%ROF = bno%wb(ikey)%ROF + ROF
            bno%wb(ikey)%ROFO = bno%wb(ikey)%ROFO + ROFO
            bno%wb(ikey)%ROFS = bno%wb(ikey)%ROFS + ROFS
            bno%wb(ikey)%ROFB = bno%wb(ikey)%ROFB + ROFB
            bno%wb(ikey)%RCAN = bno%wb(ikey)%RCAN + RCAN
            bno%wb(ikey)%SNCAN = bno%wb(ikey)%SNCAN + SNCAN
            bno%wb(ikey)%SNO = bno%wb(ikey)%SNO + SNO
            bno%wb(ikey)%WSNO = bno%wb(ikey)%WSNO + WSNO
            bno%wb(ikey)%PNDW = bno%wb(ikey)%PNDW + PNDW
            bno%wb(ikey)%LQWS = bno%wb(ikey)%LQWS + LQWS
            bno%wb(ikey)%FRWS = bno%wb(ikey)%FRWS + FRWS
        end do

    end subroutine

    subroutine save_water_balance(shd, fls, fik, dts, ina, ikdts)

        use sa_mesh_shared_variabletypes
        use sa_mesh_shared_variables
        use model_files_variabletypes
        use model_files_variables
        use model_dates

        !> Input variables.
        type(ShedGridParams) :: shd
        type(fl_ids) :: fls
        integer fik
        integer dts, ina, ikdts

        !> Local variables.
        integer NSL, j
        real dnar, dnts

        !> Contributing drainage area.
        dnar = shd%DA(ina)/((shd%AL/1000.0)**2)

        !> Denominator for time-step averaged variables.
        dnts = real(dts/ic%dts)

        !> Time-average storage components.
        bno%wb(ikdts)%RCAN = bno%wb(ikdts)%RCAN/dnts
        bno%wb(ikdts)%SNCAN = bno%wb(ikdts)%SNCAN/dnts
        bno%wb(ikdts)%SNO = bno%wb(ikdts)%SNO/dnts
        bno%wb(ikdts)%WSNO = bno%wb(ikdts)%WSNO/dnts
        bno%wb(ikdts)%PNDW = bno%wb(ikdts)%PNDW/dnts
        bno%wb(ikdts)%LQWS = bno%wb(ikdts)%LQWS/dnts
        bno%wb(ikdts)%FRWS = bno%wb(ikdts)%FRWS/dnts

        !> Calculate storage for the period.
        bno%wb(ikdts)%STG_FIN = sum(bno%wb(ikdts)%LQWS, 2) + sum(bno%wb(ikdts)%FRWS, 2) + &
                                bno%wb(ikdts)%RCAN + bno%wb(ikdts)%SNCAN + bno%wb(ikdts)%SNO + &
                                bno%wb(ikdts)%WSNO + bno%wb(ikdts)%PNDW

        !> Calculate storage for the run.
        bno%wb(IKEY_ACC)%STG_FIN = (sum(bno%wb(IKEY_ACC)%LQWS, 2) + sum(bno%wb(IKEY_ACC)%FRWS, 2) + &
                                    bno%wb(IKEY_ACC)%RCAN + bno%wb(IKEY_ACC)%SNCAN + &
                                    bno%wb(IKEY_ACC)%SNO + bno%wb(IKEY_ACC)%WSNO + bno%wb(IKEY_ACC)%PNDW) &
                                   /ic%ts_count

        !> Write the time-stamp for the period.
!todo: change this to the unit attribute of the file object.
        write(fik, "(i4, ',')", advance = 'no') ic%now%jday
        write(fik, "(i5, ',')", advance = 'no') ic%now%year
        if (dts < 86400) write(fik, "(i3, ',')", advance = 'no') ic%now%hour
        if (dts < 3600) write(fik, "(i3, ',')", advance = 'no') ic%now%mins

        !> Write the water balance to file.
        NSL = shd%lc%IGND
        write(fik, "(999(e14.6, ','))") &
            bno%wb(IKEY_ACC)%PRE(ina)/dnar, bno%wb(IKEY_ACC)%EVAP(ina)/dnar, bno%wb(IKEY_ACC)%ROF(ina)/dnar, &
            bno%wb(IKEY_ACC)%ROFO(ina)/dnar, bno%wb(IKEY_ACC)%ROFS(ina)/dnar, bno%wb(IKEY_ACC)%ROFB(ina)/dnar, &
            bno%wb(ikdts)%PRE(ina)/dnar, bno%wb(ikdts)%EVAP(ina)/dnar, bno%wb(ikdts)%ROF(ina)/dnar, &
            bno%wb(ikdts)%ROFO(ina)/dnar, bno%wb(ikdts)%ROFS(ina)/dnar, bno%wb(ikdts)%ROFB(ina)/dnar, &
            bno%wb(ikdts)%SNCAN(ina)/dnar, bno%wb(ikdts)%RCAN(ina)/dnar, &
            bno%wb(ikdts)%SNO(ina)/dnar, bno%wb(ikdts)%WSNO(ina)/dnar, &
            bno%wb(ikdts)%PNDW(ina)/dnar, &
            (bno%wb(ikdts)%LQWS(ina, j)/dnar, j = 1, NSL), &
            (bno%wb(ikdts)%FRWS(ina, j)/dnar, j = 1, NSL), &
            ((bno%wb(ikdts)%LQWS(ina, j) + bno%wb(ikdts)%FRWS(ina, j))/dnar, j = 1, NSL), &
            sum(bno%wb(ikdts)%LQWS(ina, :))/dnar, &
            sum(bno%wb(ikdts)%FRWS(ina, :))/dnar, &
            (sum(bno%wb(ikdts)%LQWS(ina, :)) + sum(bno%wb(ikdts)%FRWS(ina, :)))/dnar, &
            bno%wb(ikdts)%STG_FIN(ina)/dnar, &
            (bno%wb(ikdts)%STG_FIN(ina) - bno%wb(ikdts)%STG_INI(ina))/dnar, &
            (bno%wb(IKEY_ACC)%STG_FIN(ina) - bno%wb(IKEY_ACC)%STG_INI(ina))/dnar

        !> Update the final storage.
        bno%wb(ikdts)%STG_INI = bno%wb(ikdts)%STG_FIN

        !> Reset the accumulation for time-averaged output.
        bno%wb(ikdts)%PRE = 0.0
        bno%wb(ikdts)%EVAP = 0.0
        bno%wb(ikdts)%ROF = 0.0
        bno%wb(ikdts)%ROFO = 0.0
        bno%wb(ikdts)%ROFS = 0.0
        bno%wb(ikdts)%ROFB = 0.0
        bno%wb(ikdts)%RCAN = 0.0
        bno%wb(ikdts)%SNCAN = 0.0
        bno%wb(ikdts)%SNO = 0.0
        bno%wb(ikdts)%WSNO = 0.0
        bno%wb(ikdts)%PNDW = 0.0
        bno%wb(ikdts)%LQWS = 0.0
        bno%wb(ikdts)%FRWS = 0.0

    end subroutine

end module
