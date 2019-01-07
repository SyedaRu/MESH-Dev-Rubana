subroutine READ_RUN_OPTIONS(fls, shd, cm)

    use mpi_module
    use strings
    use model_files_variables
    use sa_mesh_common
    use model_dates
    use climate_forcing
    use output_files

    use FLAGS
    use save_basin_output, only: BASINAVGWBFILEFLAG, BASINAVGEBFILEFLAG, STREAMFLOWOUTFLAG, REACHOUTFLAG
    use RUNCLASS36_variables
    use RUNCLASS36_save_output
    use RUNSVS113_variables
    use baseflow_module
    use cropland_irrigation_variables
    use WF_ROUTE_config
    use rte_module
    use SA_RTE_module, only: SA_RTE_flgs
    use SIMSTATS_config, only: mtsflg
    use PBSM_module

    implicit none

    !> Input variables.
    type(fl_ids) fls
    type(ShedGridParams) shd
    type(CLIM_INFO) cm

    !> Local variables.
    integer CONFLAGS, IROVAL, iun, nargs, n, j, i, ierr
    character(len = DEFAULT_LINE_LENGTH) line
    character(len = DEFAULT_FIELD_LENGTH), dimension(50) :: args

    !>
    !> SET RUN OPTIONS
    !> READ THE RUN_OPTIONS.INI INPUT FILE TO SET OR RESET ANY CONTROL
    !> FLAGS AND READ THE GRID OUTPUT DIRECTORIES.
    !>
    !>    * IF IDISP = 0, VEGETATION DISPLACEMENT HEIGHTS ARE IGNORED,
    !>    * BECAUSE THE ATMOSPHERIC MODEL CONSIDERS THESE TO BE PART OF THE
    !>    * "TERRAIN".
    !>    * IF IDISP = 1, VEGETATION DISPLACEMENT HEIGHTS ARE CALCULATED.
    IDISP = 1

    !>    * IF IZREF = 1, THE BOTTOM OF THE ATMOSPHERIC MODEL IS TAKEN TO
    !>    * LIE AT THE GROUND SURFACE.
    !>    * IF IZREF = 2, THE BOTTOM OF THE ATMOSPHERIC MODEL IS TAKEN TO
    !>    * LIE AT THE LOCAL ROUGHNESS HEIGHT.
    IZREF = 1

    !>    * IF ISLFD = 0, DRCOEF IS CALLED FOR SURFACE STABILITY
    !>    * CORRECTIONS AND THE ORIGINAL GCM SET OF SCREEN-LEVEL DIAGNOSTIC
    !>    * CALCULATIONS IS DONE.
    !>    * IF ISLFD = 1, DRCOEF IS CALLED FOR SURFACE STABILITY
    !>    * CORRECTIONS AND SLDIAG IS CALLED FOR SCREEN-LEVEL DIAGNOSTIC
    !>    * CALCULATIONS.
    !>    * IF ISLFD = 2, FLXSURFZ IS CALLED FOR SURFACE STABILITY
    !>    * CORRECTIONS AND DIASURF IS CALLED FOR SCREEN-LEVEL DIAGNOSTIC
    !>    * CALCULATIONS.
    ISLFD = 2

    !>    * IF IPCP = 1, THE RAINFALL-SNOWFALL CUTOFF IS TAKEN TO LIE AT
    !>    * 0 dC.
    !>    * IF IPCP = 2, A LINEAR PARTITIONING OF PRECIPITATION BETWEEEN
    !>    * RAINFALL AND SNOWFALL IS DONE BETWEEN 0 dC AND 2 dC.
    !>    * IF IPCP = 3, RAINFALL AND SNOWFALL ARE PARTITIONED ACCORDING TO
    !>    * A POLYNOMIAL CURVE BETWEEN 0 dC AND 6 dC.
    !>    * IF IPCP=4, THE RAINFALL, SNOWFALL AND TOTAL PRECIPITATION RATES
    !>    * ARE READ IN DIRECTLY.
    IPCP = 1

    !>    * ITC, ITCG AND ITG ARE SWITCHES TO CHOOSE THE ITERATION SCHEME
    !>    * TO BE USED IN CALCULATING THE CANOPY OR GROUND SURFACE
    !>    * TEMPERATURE RESPECTIVELY.  IF THE SWITCH IS SET TO 1, A
    !>    * COMBINATION OF SECANT AND BISECTION METHODS IS USED; IF TO 2,
    !>    * THE NEWTON-RAPHSON METHOD IS USED.
    ITC = 2
    ITCG = 2
    ITG = 2

    !>    * IF IWF = 0, ONLY OVERLAND FLOW AND BASEFLOW ARE MODELLED, AND
    !>    * THE GROUND SURFACE SLOPE IS NOT MODELLED.
    !>    * IF IWF = 1, THE MODIFIED CALCULATIONS OF OVERLAND
    !>    * FLOW AND INTERFLOW ARE PERFORMED.
    !>    * IF IWF = 2, SAME AS IWF = 0 EXCEPT THAT OVERLAND FLOW IS
    !>    * MODELLED AS FILL AND SPILL PROCESS FROM A SERIES OF POTHOLES.
    !>    * DEFAULT VALUE IS 1.
    RUNCLASS36_flgs%INTERFLOWFLAG = 1

    !>    * IF IPAI, IHGT, IALC, IALS AND IALG ARE ZERO, THE VALUES OF
    !>    * LEAF ARE INDEX, VEGETATION HEIGHT, CANOPY ALBEDO, SNOW ALBEDO
    !>    * AND SOIL ALBEDO RESPECTIVELY CALCULATED BY CLASS ARE USED.
    !>    * IF ANY OF THESE SWITCHES IS SET TO 1, THE VALUE OF THE
    !>    * CORRESPONDING PARAMETER CALCULATED BY CLASS IS OVERRIDDEN BY
    !>    * A USER-SUPPLIED INPUT VALUE.
    IPAI = 0
    IHGT = 0
    IALC = 0
    IALS = 0
    IALG = 0

    !>    * ICTEMMOD IS SET TO 1 IF CLASS IS BEING RUN IN CONJUNCTION WITH
    !>    * THE CANADIAN TERRESTRIAL ECOSYSTEM MODEL "CTEM"; OTHERWISE
    !>    * ICTEMMOD IS SET TO 0.
    ICTEMMOD = 0

    !> DAN * IF RELFLG = 0, ANY CONFIGURATION FILE IS READ THAT MATCHES
    !> DAN * THE FILE NAME IN THE OPEN STATEMENT.
    !> DAN * IF RELFLG = 1, ONLY CONFIGURATION FILES WHOSE VERSION MATCHES
    !> DAN * THE RELEASE OF MESH_DRIVER ARE READ.  THE PROGRAM STOPS IF THE
    !> DAN * TWO STRINGS DO NOT MATCH.
    !> DAN * THIS FLAG IS NOT APPLICABLE TO RUN_OPTIONS.INI, WHERE THIS FLAG
    !> DAN * MAY BE RESET).
    RELFLG = 1

    !* SAVE/RESUMEFLAG: Saves or resume states from file.
    !>  Legacy options:
    !>      - 0: Disabled (new option: none).
    !>      - 1: Not supported.
    !>      - 2: Not supported.
    !>      - 3: CLASS prognostic states in binary sequential format (new option: seq only class).
    !>      - 4: All resume variables in binary sequential format (new option: seq).
    !>      - 5: All prognostic states in binary sequential format (new option: seq only states).
    !>  Options:
    !>      - none: Save and resume no states to and from file (default).
    !>  File format options (enables SAVERESUMEFLAG):
    !>      - txt: In text format.
    !>      - seq: Sequential binary format.
    !>      - csv: From CSV by GRU.
    !>      - r2c: From r2c by grid.
    !>  Output frequency options (default is only at the end of the run):
    !>      - monthly: Before the beginning of the next month.
    !>      - yearly: Before the beginning of the next year.
    RESUMEFLAG = 'none'
    SAVERESUMEFLAG = 'none'

    !> SOIL INITIALIZATION  FLAG - DEFAULT = STOP SIMULATION IF SUM OF SOIL PERCENTAGES EXCEEDS 100%
    !> If SOILINIFLAG is 0, stop simulation if the sum of soil percentages is greater than 100%
    !> If SOILINIFLAG is 1, no adjustment to soil percentages even if the sum is greater than 100%
    !> If SOILINIFLAG is 2, adjust soil percentages in favor of sand
    !> If SOILINIFLAG is 3, adjust soil percentages in favor of clay
    !> If SOILINIFLAG is 4, adjust soil percentages proportionally
    !> If SOILINIFLAG is 5, directly read soil parameter values from soil.ini file.
    SOILINIFLAG = 0

    !> If OBJFNFLAG is 0 {DEFAULT} = SAE - SUM OF ABSOLUTE VALUE OF ERRORS
    !> If OBJFNFLAG is 1, SAESRT - SUM OF ABSOLUTE VALUE OF ERRORS AFTER SORTING
    !> If OBJFNFLAG is 2, SAEMSRT - SUM OF ABSOLUTE VALUE OF MOVING ERRORS AFTER SORTING
    !> If OBJFNFLAG is 3, NSE - MEAN NASH-SUTCLIFFE MODEL EFFICIENCY INDEX (+ve FOR MAXIMIZATION)
    !> IF OBJFNFLAG is 4, NSE - MEAN NASH-SUTFLIFFE MODEL EFFICIENCY INDEX (-ve FOR MINIMIZATION)
    OBJFNFLAG = 0

    WINDOWSIZEFLAG = 1
    WINDOWSPACINGFLAG = 1

    METRICSSTATSOUTFLAG = 1
    METRICSFILTEROBSFLAG = 1

    !> METRICSSPINUP specifies the starting day from which to calculate metrics.
    !> The starting day is relative to the beginning of the simulation; Day 1 is
    !> the first day of the simulation, regardless of the date or its Julian date
    !> in the year. If METRICSINCLUDESPINUP is set to 1, METRICSSPINUP is not used.
    METRICSSPINUP = 1

    !> If METRICSINCLUDESPINUP is set to 1 then metrics are calculated from the
    !> first day of the simulation (1:ndsim).
    !> If METRICSINCLUDESPINUP is set to 0 then metrics are calculated from
    !> METRICSSPINUP (METRICSSPINUP:ndsim).
    METRICSINCLUDESPINUP = 0

    !> If FROZENSOILINFILFLAG is 0, all snow melt infiltrates.
    !> If FROZENSOILINFILFLAG is 1, snow melt is partitioned to frozen soil infiltration
    !> and direct runoff based on the parameteric equation developed by Gray et al, 2001.
    FROZENSOILINFILFLAG = 0

    !* If SUBBASINFLAG is 1, calculations will only be done for grid squares that are
    !* in the watersheds of the locations listed in the streamflow files.
    !* If SUBBASINFLAG is 0, calculations will be made for all grid squares.
    SUBBASINFLAG = 0

    !* If R2COUTPUTFLAG is 1, R2C ascii file will be written for user specified
    !* variables.
    !* If R2COUTPUTFLAG is 2, R2C binary will be written for user specified
    !* variables (list of variables will be read from r2c_output.txt file).
    R2COUTPUTFLAG = 0

    !* If FROZENSOILINFILFLAG is 0, all snow melt infiltrates.
    !* If FROZENSOILINFILFLAG is 1, snow melt is partitioned to frozen soil infiltration
    !* and direct runoff based on the parameteric equation developed by Gray et al, 2001.
    FROZENSOILINFILFLAG = 0

    !* If LOCATIONFLAG is 0, gauge coordinates are read using 2I5 (Minutes) {Default}
    !* If LOCATIONFLAG is 1, gauge coordinates for BOTH MESH_input_streamflow.txt AND
    !*                       MESH_input_reservoir.txt are read using 2F7.1 (Minutes with 1 decimal)
    LOCATIONFLAG = 0

    !> FLAGS FOR GEOTHERMAL FLUX FOR THE BOTTOM OF THE LAST SOIL LAYER
    !* If GGEOFLAG is GT 0,  READ UNIQUE VALUE FROM MESH_ggeo.INI FILE
    GGEOFLAG = 0

    !> BASIN SWE OUTPUT FLAG
    !> If enabled, saves the SCA and SWE output files.
    !>     0 = Create no output.
    !>     1 = Save the SCA and SWE output files.
    BASINSWEOUTFLAG = 0

    !> The above parameter values are defaults, to change to a different
    !> value, use the MESH_input_run_options.ini file

    !> Open file and print an error if unable to open the file.
    call print_screen('READING: ' // trim(fls%fl(mfk%f53)%fn))
    iun = fls%fl(mfk%f53)%iun
    open(iun, file = fls%fl(mfk%f53)%fn, status = 'old', action = 'read', iostat = ierr)
    if (ierr /= 0) then
        ECHOTXTMODE = .false.
        call print_error('Unable to open file. Check if the file exists.')
        call program_abort()
    end if

    !> Begin reading the control flags.
    do i = 1, 3
        read(iun, *)
    end do
    read(iun, '(i5)') CONFLAGS

    !> Read and parse the control flags.
    if (CONFLAGS > 0) then

        !> Control flags are parsed by space.
        do i = 1, CONFLAGS

            !> Read and parse the entire line.
            call readline(iun, line, ierr)
            if (index(line, '#') > 2) line = line(1:index(line, '#') - 1)
            if (index(line, '!') > 2) line = line(1:index(line, '!') - 1)
            call compact(line)
            call parse(line, ' ', args, nargs)
            if (.not. nargs > 0) then
                write(line, FMT_GEN) i
                call print_screen('WARNING: Error reading control flag ' // trim(adjustl(line)), PAD_3)
                cycle
            end if

            !> Determine the control flag and parse additional arguments.
            select case (trim(adjustl(args(1))))

                case ('IDISP')
                    call value(args(2), IDISP, ierr)
                case ('IZREF')
                    call value(args(2), IZREF, ierr)
                case ('ISLFD')
                    call value(args(2), ISLFD, ierr)
                case ('IPCP')
                    call value(args(2), IPCP, ierr)
                case ('ITC')
                    call value(args(2), ITC, ierr)
                case ('ITCG')
                    call value(args(2), ITCG, ierr)
                case ('ITG')
                    call value(args(2), ITG, ierr)
                case ('IWF')
                    call value(args(2), RUNCLASS36_flgs%INTERFLOWFLAG, ierr)
                case ('IPAI')
                    call value(args(2), IPAI, ierr)
                case ('IHGT')
                    call value(args(2), IHGT, ierr)
                case ('IALC')
                    call value(args(2), IALC, ierr)
                case ('IALS')
                    call value(args(2), IALS, ierr)
                case ('IALG')
                    call value(args(2), IALG, ierr)
                case ('RESUMEFLAG')
                    RESUMEFLAG = adjustl(line)
                case ('SAVERESUMEFLAG')
                    SAVERESUMEFLAG = adjustl(line)

                !> Basin forcing time-step flag.
                case ('HOURLYFLAG')
                    call value(args(2), IROVAL, ierr)
                    if (ierr == 0) then
                        do j = 1, cm%nclim
                            cm%dat(j)%hf = IROVAL
                        end do
                    end if

                !> Model time-step.
                case ('TIMESTEPFLAG')
                    call value(args(2), ic%dtmins, ierr)
                    ic%dts = ic%dtmins*60

                case ('RELFLG')
                    call value(args(2), RELFLG, ierr)

                !> Message output options.
                case (PRINTSIMSTATUS_NAME, 'VERBOSEMODE')
                    call parse_options(PRINTSIMSTATUS_NAME, args(2:nargs))
                case (DIAGNOSEMODE_NAME)
                    call parse_options(DIAGNOSEMODE_NAME, args(2:nargs))
                case (ECHOTXTMODE_NAME, 'MODELINFOOUTFLAG')
                    call parse_options(ECHOTXTMODE_NAME, args(2:nargs))

                !> MPI OPTIONS
                case ('MPIUSEBARRIER')
                    call value(args(2), MPIUSEBARRIER, ierr)

                !> BASIN FORCING DATA OPTIONS
                !> Basin forcing data.
                case ('BASINFORCINGFLAG')
                    do j = 2, nargs
                        select case (lowercase(args(j)))
                            case ('met')
                                cm%dat(ck%FB)%factive = .false.
                                cm%dat(ck%FI)%factive = .false.
                                cm%dat(ck%RT)%factive = .false.
                                cm%dat(ck%TT)%factive = .false.
                                cm%dat(ck%UV)%factive = .false.
                                cm%dat(ck%P0)%factive = .false.
                                cm%dat(ck%HU)%factive = .false.
                                cm%dat(ck%MET)%ffmt = 6
                                cm%dat(ck%MET)%factive = .true.
                                exit
                        end select
                    end do
                case ('BASINSHORTWAVEFLAG')
                    call value(args(2), cm%dat(ck%FB)%ffmt, ierr)
                    if (ierr == 0) cm%dat(ck%FB)%factive = .true.
                    cm%dat(ck%FB)%id_var = 'FB'
                    if (cm%dat(ck%FB)%ffmt == 5) then
                        call value(args(3), cm%dat(ck%FB)%ffmt, ierr)
                        call value(args(4), cm%dat(ck%FB)%nblocks, ierr)
                    end if
                    do j = 3, nargs
                        if (len_trim(args(j)) > 3) then
                            if (args(j)(1:3) == 'hf=') then
                                call value(args(j)(4:), cm%dat(ck%FB)%hf, ierr)
                            end if
                        end if
                        if (len_trim(args(j)) > 4) then
                            if (args(j)(1:4) == 'nts=') then
                                call value(args(j)(5:), cm%dat(ck%FB)%nblocks, ierr)
                            end if
                        end if
                    end do
                case ('BASINLONGWAVEFLAG')
                    call value(args(2), cm%dat(ck%FI)%ffmt, ierr)
                    if (ierr == 0) cm%dat(ck%FI)%factive = .true.
                    cm%dat(ck%FI)%id_var = 'FI'
                    if (cm%dat(ck%FI)%ffmt == 5) then
                        call value(args(3), cm%dat(ck%FI)%ffmt, ierr)
                        call value(args(4), cm%dat(ck%FI)%nblocks, ierr)
                    end if
                    do j = 3, nargs
                        if (len_trim(args(j)) > 3) then
                            if (args(j)(1:3) == 'hf=') then
                                call value(args(j)(4:), cm%dat(ck%FI)%hf, ierr)
                            end if
                        end if
                        if (len_trim(args(j)) > 4) then
                            if (args(j)(1:4) == 'nts=') then
                                call value(args(j)(5:), cm%dat(ck%FI)%nblocks, ierr)
                            end if
                        end if
                    end do
                case ('BASINRAINFLAG')
                    call value(args(2), cm%dat(ck%RT)%ffmt, ierr)
                    if (ierr == 0) cm%dat(ck%RT)%factive = .true.
                    cm%dat(ck%RT)%id_var = 'RT'
                    if (cm%dat(ck%RT)%ffmt == 5) then
                        call value(args(3), cm%dat(ck%RT)%ffmt, ierr)
                        call value(args(4), cm%dat(ck%RT)%nblocks, ierr)
                    end if
                    do j = 3, nargs
                        if (len_trim(args(j)) > 3) then
                            if (args(j)(1:3) == 'hf=') then
                                call value(args(j)(4:), cm%dat(ck%RT)%hf, ierr)
                            end if
                        end if
                        if (len_trim(args(j)) > 4) then
                            if (args(j)(1:4) == 'nts=') then
                                call value(args(j)(5:), cm%dat(ck%RT)%nblocks, ierr)
                            end if
                        end if
                    end do
                case ('BASINTEMPERATUREFLAG')
                    call value(args(2), cm%dat(ck%TT)%ffmt, ierr)
                    if (ierr == 0) cm%dat(ck%TT)%factive = .true.
                    cm%dat(ck%TT)%id_var = 'TT'
                    if (cm%dat(ck%TT)%ffmt == 5) then
                        call value(args(3), cm%dat(ck%TT)%ffmt, ierr)
                        call value(args(4), cm%dat(ck%TT)%nblocks, ierr)
                    end if
                    do j = 3, nargs
                        if (len_trim(args(j)) > 3) then
                            if (args(j)(1:3) == 'hf=') then
                                call value(args(j)(4:), cm%dat(ck%TT)%hf, ierr)
                            end if
                        end if
                        if (len_trim(args(j)) > 4) then
                            if (args(j)(1:4) == 'nts=') then
                                call value(args(j)(5:), cm%dat(ck%TT)%nblocks, ierr)
                            end if
                        end if
                    end do
                case ('BASINWINDFLAG')
                    call value(args(2), cm%dat(ck%UV)%ffmt, ierr)
                    if (ierr == 0) cm%dat(ck%UV)%factive = .true.
                    cm%dat(ck%UV)%id_var = 'UV'
                    if (cm%dat(ck%UV)%ffmt == 5) then
                        call value(args(3), cm%dat(ck%UV)%ffmt, ierr)
                        call value(args(4), cm%dat(ck%UV)%nblocks, ierr)
                    end if
                    do j = 3, nargs
                        if (len_trim(args(j)) > 3) then
                            if (args(j)(1:3) == 'hf=') then
                                call value(args(j)(4:), cm%dat(ck%UV)%hf, ierr)
                            end if
                        end if
                        if (len_trim(args(j)) > 4) then
                            if (args(j)(1:4) == 'nts=') then
                                call value(args(j)(5:), cm%dat(ck%UV)%nblocks, ierr)
                            end if
                        end if
                    end do
                case ('BASINPRESFLAG')
                    call value(args(2), cm%dat(ck%P0)%ffmt, ierr)
                    if (ierr == 0) cm%dat(ck%P0)%factive = .true.
                    cm%dat(ck%P0)%id_var = 'P0'
                    if (cm%dat(ck%P0)%ffmt == 5) then
                        call value(args(3), cm%dat(ck%P0)%ffmt, ierr)
                        call value(args(4), cm%dat(ck%P0)%nblocks, ierr)
                    end if
                    do j = 3, nargs
                        if (len_trim(args(j)) > 3) then
                            if (args(j)(1:3) == 'hf=') then
                                call value(args(j)(4:), cm%dat(ck%P0)%hf, ierr)
                            end if
                        end if
                        if (len_trim(args(j)) > 4) then
                            if (args(j)(1:4) == 'nts=') then
                                call value(args(j)(5:), cm%dat(ck%P0)%nblocks, ierr)
                            end if
                        end if
                    end do
                case ('BASINHUMIDITYFLAG')
                    call value(args(2), cm%dat(ck%HU)%ffmt, ierr)
                    if (ierr == 0) cm%dat(ck%HU)%factive = .true.
                    cm%dat(ck%HU)%id_var = 'HU'
                    if (cm%dat(ck%HU)%ffmt == 5) then
                        call value(args(3), cm%dat(ck%HU)%ffmt, ierr)
                        call value(args(4), cm%dat(ck%HU)%nblocks, ierr)
                    end if
                    do j = 3, nargs
                        if (len_trim(args(j)) > 3) then
                            if (args(j)(1:3) == 'hf=') then
                                call value(args(j)(4:), cm%dat(ck%HU)%hf, ierr)
                            end if
                        end if
                        if (len_trim(args(j)) > 4) then
                            if (args(j)(1:4) == 'nts=') then
                                call value(args(j)(5:), cm%dat(ck%HU)%nblocks, ierr)
                            end if
                        end if
                    end do
                case ('BASINRUNOFFFLAG')
                case ('BASINRECHARGEFLAG')

                case ('STREAMFLOWFILEFLAG')
                    fms%stmg%qomeas%fls%ffmt = adjustl(args(2))
                case ('RESERVOIRFILEFLAG')
                    fms%rsvr%rlsmeas%fls%ffmt = adjustl(args(2))

                case ('SHDFILEFLAG')
                    SHDFILEFLAG = adjustl(line)

                case ('SOILINIFLAG')
                    call value(args(2), SOILINIFLAG, ierr)
                case ('NRSOILAYEREADFLAG')
                    call value(args(2), NRSOILAYEREADFLAG, ierr)
                case ('PREEMPTIONFLAG')
                    call value(args(2), mtsflg%PREEMPTIONFLAG, ierr)

                !> Interpolation flag for climate forcing data.
                case ('INTERPOLATIONFLAG')
                    call value(args(2), IROVAL, ierr)
                    if (ierr == 0) then
                        cm%dat(ck%FB)%ipflg = IROVAL
                        cm%dat(ck%FI)%ipflg = IROVAL
                        cm%dat(ck%RT)%ipflg = IROVAL
                        cm%dat(ck%TT)%ipflg = IROVAL
                        cm%dat(ck%UV)%ipflg = IROVAL
                        cm%dat(ck%P0)%ipflg = IROVAL
                        cm%dat(ck%HU)%ipflg = IROVAL
                    end if

                case ('SUBBASINFLAG')
                    call value(args(2), SUBBASINFLAG, ierr)
                case ('R2COUTPUTFLAG')
                    call value(args(2), R2COUTPUTFLAG, ierr)
                case ('OBJFNFLAG')
                    call value(args(2), OBJFNFLAG, ierr)
                case ('AUTOCALIBRATIONFLAG')
                    call value(args(2), mtsflg%AUTOCALIBRATIONFLAG, ierr)
                case ('WINDOWSIZEFLAG')
                    call value(args(2), WINDOWSIZEFLAG, ierr)
                case ('WINDOWSPACINGFLAG')
                    call value(args(2), WINDOWSPACINGFLAG, ierr)
                case ('METRICSSTATSOUTFLAG')
                    call value(args(2), METRICSSTATSOUTFLAG, ierr)
                case ('METRICSFILTEROBSFLAG')
                    call value(args(2), METRICSFILTEROBSFLAG, ierr)
                case ('METRICSSPINUP')
                    call value(args(2), METRICSSPINUP, ierr)
                    METRICSSPINUP = max(METRICSSPINUP, 1)
                case ('METRICSINCLUDESPINUP')
                    call value(args(2), METRICSINCLUDESPINUP, ierr)
                case ('FROZENSOILINFILFLAG')
                    call value(args(2), FROZENSOILINFILFLAG, ierr)
                case ('PRINTRFFR2CFILEFLAG')
                    call value(args(2), SA_RTE_flgs%PRINTRFFR2CFILEFLAG, ierr)
                    SA_RTE_flgs%PROCESS_ACTIVE = (SA_RTE_flgs%PRINTRFFR2CFILEFLAG == 1)
                case ('PRINTRCHR2CFILEFLAG')
                    call value(args(2), SA_RTE_flgs%PRINTRCHR2CFILEFLAG, ierr)
                    SA_RTE_flgs%PROCESS_ACTIVE = (SA_RTE_flgs%PRINTRCHR2CFILEFLAG == 1)
!+                case ('PRINTLKGR2CFILEFLAG')
!+                    call value(args(2), SA_RTE_flgs%PRINTLKGR2CFILEFLAG, ierr)
!+                    SA_RTE_flgs%PROCESS_ACTIVE = (SA_RTE_flgs%PRINTLKGR2CFILEFLAG == 1)
                case ('ICTEMMOD')
                    call value(args(2), ICTEMMOD, ierr)

                !> PBSM (blowing snow).
                case ('PBSMFLAG')
                    call PBSM_parse_flag(line)

                case ('LOCATIONFLAG')
                    call value(args(2), LOCATIONFLAG, ierr)
                case ('OUTFIELDSFLAG')
                    call value(args(2), OUTFIELDSFLAG, ierr)
                    fls_out%PROCESS_ACTIVE = .true.
                case ('GGEOFLAG')
                    call value(args(2), GGEOFLAG, ierr)

                !> Basin output files.
                case ('BASINBALANCEOUTFLAG')
                    call value(args(2), IROVAL, ierr)
                    if (IROVAL == 0) then
                        BASINAVGEBFILEFLAG = 'none'
                        BASINAVGWBFILEFLAG = 'none'
                    end if
                case ('BASINAVGEBFILEFLAG')
                    BASINAVGEBFILEFLAG = adjustl(line)
                case ('BASINAVGWBFILEFLAG')
                    BASINAVGWBFILEFLAG = adjustl(line)
                case ('STREAMFLOWOUTFLAG')
                    STREAMFLOWOUTFLAG = adjustl(line)
                case ('REACHOUTFLAG')
                    REACHOUTFLAG = adjustl(line)

                !> Time-averaged basin PEVP-EVAP and EVPB output.
                case ('BASINAVGEVPFILEFLAG')
                    BASINAVGEVPFILEFLAG = 0
                    do j = 2, nargs
                        select case (lowercase(args(j)))
                            case ('daily')
                                BASINAVGEVPFILEFLAG = BASINAVGEVPFILEFLAG + 1
                            case ('monthly')
                                BASINAVGEVPFILEFLAG = BASINAVGEVPFILEFLAG + 2
                            case ('hourly')
                                BASINAVGEVPFILEFLAG = BASINAVGEVPFILEFLAG + 4
                            case ('ts')
                                BASINAVGEVPFILEFLAG = BASINAVGEVPFILEFLAG + 8
                            case ('all')
                                BASINAVGEVPFILEFLAG = 1
                                BASINAVGEVPFILEFLAG = BASINAVGEVPFILEFLAG + 2
                                BASINAVGEVPFILEFLAG = BASINAVGEVPFILEFLAG + 4
                                BASINAVGEVPFILEFLAG = BASINAVGEVPFILEFLAG + 8
                                exit
                            case ('default')
                                BASINAVGEVPFILEFLAG = 1
                                exit
                            case ('none')
                                BASINAVGEVPFILEFLAG = 0
                                exit
                        end select
                    end do

                case ('BASINSWEOUTFLAG')
                    call value(args(2), BASINSWEOUTFLAG, ierr)

                !> BASEFLOW routing.
                case ('BASEFLOWFLAG')
                    call bflm_parse_flag(line)

                !> Reservoir Release function flag (Number of WF_B coefficients).
!?                    case ('RESVRELSWFB')
!?                        call value(args(2), WF_RTE_flgs%RESVRELSWFB, ierr)

                !> Cropland irrigation module.
                case ('CROPLANDIRRIGATION')
                    cifg%ts_flag = 0
                    do j = 2, nargs
                        select case (lowercase(args(j)))
                            case ('daily')
                                cifg%ts_flag = cifg%ts_flag + radix(civ%fk%KDLY)**civ%fk%KDLY
                            case ('hourly')
                                cifg%ts_flag = cifg%ts_flag + radix(civ%fk%KHLY)**civ%fk%KHLY
                            case ('ts')
                                cifg%ts_flag = cifg%ts_flag + radix(civ%fk%KTS)**civ%fk%KTS
                            case ('all')
                                cifg%ts_flag = radix(civ%fk%KDLY)**civ%fk%KDLY
                                cifg%ts_flag = cifg%ts_flag + radix(civ%fk%KHLY)**civ%fk%KHLY
                                cifg%ts_flag = cifg%ts_flag + radix(civ%fk%KTS)**civ%fk%KTS
                                exit
                            case ('default')
                                cifg%ts_flag = radix(civ%fk%KDLY)**civ%fk%KDLY
                                exit
                            case ('none')
                                cifg%ts_flag = 0
                                exit
                        end select
                    end do
                    cifg%PROCESS_ACTIVE = (cifg%ts_flag > 0)

                !> Run mode.
                case ('RUNMODE')
                    do j = 2, nargs
                        select case (lowercase(args(j)))
                            case ('runsvs')
                                RUNSVS113_flgs%PROCESS_ACTIVE = .true.
                                RUNCLASS36_flgs%PROCESS_ACTIVE = .false.
                            case ('runclass')
                                RUNCLASS36_flgs%PROCESS_ACTIVE = .true.
                                RUNSVS113_flgs%PROCESS_ACTIVE = .false.
                            case ('nolss')
                                RUNCLASS36_flgs%PROCESS_ACTIVE = .false.
                                RUNSVS113_flgs%PROCESS_ACTIVE = .false.
                                ro%RUNCLIM = .false.
                                ro%RUNBALWB = .false.
                                ro%RUNBALEB = .false.
                                ro%RUNTILE = .false.
                            case ('runrte')
                                WF_RTE_flgs%PROCESS_ACTIVE = .false.
                                rteflg%PROCESS_ACTIVE = .true.
                            case ('noroute')
                                WF_RTE_flgs%PROCESS_ACTIVE = .false.
                                rteflg%PROCESS_ACTIVE = .false.
                                ro%RUNCHNL = .false.
                                ro%RUNGRID = .false.
                            case ('default')
                                RUNCLASS36_flgs%PROCESS_ACTIVE = .true.
                                RUNSVS113_flgs%PROCESS_ACTIVE = .false.
                                WF_RTE_flgs%PROCESS_ACTIVE = .true.
                                rteflg%PROCESS_ACTIVE = .false.
                                exit
                            case ('diagnostic')
                                RUNCLASS36_flgs%PROCESS_ACTIVE = .false.
                                RUNSVS113_flgs%PROCESS_ACTIVE = .false.
                                WF_RTE_flgs%PROCESS_ACTIVE = .false.
                                rteflg%PROCESS_ACTIVE = .false.
                                exit
                        end select
                    end do

                !> INPUTPARAMSFORMFLAG
                case ('INPUTPARAMSFORMFLAG')
                    INPUTPARAMSFORM = adjustl(lowercase(line))

                !> Unrecognized flag.
                case default
                    call print_screen("WARNING: '" // trim(adjustl(args(1))) // "' is not recognized as a control flag.", PAD_3)
            end select

            !> Check for errors.
            if (ierr /= 0) then
                call print_screen("WARNING: Unable to parse the options of '" // trim(adjustl(args(1))) // "'.", PAD_3)
            end if
        end do
    end if

    !> Empty lines.
    do i = 1, 2
        read(iun, *)
    end do

    !> Output grid points.
    read(iun, '(i5)') WF_NUM_POINTS
    if (WF_NUM_POINTS > 10) then
        call print_screen('REMARK: The number of folders for CLASS output is greater than ten and will impact performance.', PAD_3)
    end if
    read (iun, *)
    if (WF_NUM_POINTS > 0 .and. RUNCLASS36_flgs%PROCESS_ACTIVE) then
        allocate(op%DIR_OUT(WF_NUM_POINTS), op%N_OUT(WF_NUM_POINTS), &
                 op%II_OUT(WF_NUM_POINTS), op%K_OUT(WF_NUM_POINTS), stat = ierr)
        if (ierr /= 0) then
            ECHOTXTMODE = .false.
            call print_error('Unable to allocate variables for CLASS output.')
            write(line, FMT_GEN) WF_NUM_POINTS
            call print_message_detail('Number of points: ' // trim(adjustl(line)))
            call program_abort()
        end if
        read(iun, *) (op%N_OUT(i), i = 1, WF_NUM_POINTS)
        read(iun, *) (op%II_OUT(i), i = 1, WF_NUM_POINTS)
        read(iun, *) (op%DIR_OUT(i), i = 1, WF_NUM_POINTS)
    else
        read(iun, *)
        read(iun, *)
        read(iun, *)
        allocate(op%DIR_OUT(1), op%N_OUT(1), op%II_OUT(1), op%K_OUT(1))
    end if

    !> Output folder for basin/high-level model output.
    read(iun, *)
    read(iun, *)
    read(iun, '(a10)') line
    call removesp(line)
    fls%GENDIR_OUT = adjustl(line)

    !> Simulation start and stop dates.
    read(iun, *)
    read(iun, *)
    read(iun, *) ic%start%year, ic%start%jday, ic%start%hour, ic%start%mins
    read(iun, *) ic%stop%year, ic%stop%jday, ic%stop%hour, ic%stop%mins

    !> Close the file.
    close(iun)

    return

end subroutine
