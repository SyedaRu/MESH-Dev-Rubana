!>
!> Description:
!>  Subroutine to read structure locations and configurations from
!>  file. Structures shared by SA_MESH are accessible by
!>  'sa_mesh_variables'. Other structures are accessible by their
!>  respecitve process module(s).
!>
!> Input:
!*  shd: Basin shed object, containing information about the grid
!*      definition read from MESH_drainage_database.r2c.
!>
subroutine read_basin_structures(shd)

    use strings
    use sa_mesh_variables
    use sa_mesh_utilities
    use model_dates
    use txt_io

    implicit none

    !> Input variables.
    type(ShedGridParams) :: shd

    !> Local variables.
    integer iun, ierr, iskip, ijday1, ijday2, n, i
    character(len = DEFAULT_LINE_LENGTH) fname, line

    !> Return if routing routines are disabled.
    if (.not. ro%RUNCHNL) return

    !> Streamflow gauge locations.

    !> Initialize the time-series.
    fms%stmg%qomeas%iyear = ic%start%year
    fms%stmg%qomeas%ijday = ic%start%jday
    fms%stmg%qomeas%ihour = ic%start%hour
    fms%stmg%qomeas%imins = ic%start%mins

    !> Read the configuration from file.
    fname = fms%stmg%qomeas%fls%fname
    iun = fms%stmg%qomeas%fls%iun
    select case (lowercase(fms%stmg%qomeas%fls%ffmt))
        case ('tb0')
            fname = trim(adjustl(fname)) // '.tb0'
            call read_streamflow_tb0(shd, iun, fname)
        case default
            fname = trim(adjustl(fname)) // '.txt'
            call read_streamflow_txt(shd, iun, fname)
    end select

    !> If locations exist.
    if (fms%stmg%n > 0) then

        !> Print to status file.
        call print_echo_txt(trim(fname))

        !> Find the x-y cell coordinate of the location.
        fms%stmg%meta%iy = int((fms%stmg%meta%y - shd%yOrigin)/shd%yDelta) + 1
        fms%stmg%meta%jx = int((fms%stmg%meta%x - shd%xOrigin)/shd%xDelta) + 1

        !> Find the RANK of the location.
        fms%stmg%meta%rnk = 0
        do i = 1, fms%stmg%n
            do n = 1, shd%NA
                if (fms%stmg%meta%jx(i) == shd%xxx(n) .and. fms%stmg%meta%iy(i) == shd%yyy(n)) fms%stmg%meta%rnk(i) = n
            end do
        end do

        !> Print a message if any location is missing RANK (outside the basin).
        if (minval(fms%stmg%meta%rnk) == 0) then
            call print_error('Streamflow gauge(s) are outside the basin.')
            call print_message_detail(line)
            write(line, 1001) 'GAUGE', 'Y', 'IY', 'X', 'JX'
            call print_message_detail(line)
            do i = 1, fms%stmg%n
                if (fms%stmg%meta%rnk(i) == 0) then
                    write(line, 1001) i, fms%stmg%meta%y(i), fms%stmg%meta%iy(i), fms%stmg%meta%x(i), fms%stmg%meta%jx(i)
                    call print_message_detail(line)
                end if
            end do
            call stop_program()
        end if

        !> Skip records in the file the 'now' time-step.
        call Julian_Day_ID(fms%stmg%qomeas%iyear, fms%stmg%qomeas%ijday, ijday1)
        call Julian_Day_ID(ic%start%year, ic%start%jday, ijday2)
        if (ijday2 < ijday1) then
            call print_warning('The first record occurs after the simulation start date.')
            call print_message('This may cause channels to initialize with no storage.')
            write(line, "(i5, i4)") fms%stmg%qomeas%iyear, fms%stmg%qomeas%ijday
            write(line, 1002) 'First record occurs on:', trim(line)
            call print_message_detail(line)
            write(line, "(i5, i4)") ic%start%year, ic%start%jday
            write(line, 1002) 'Simulation start date:', trim(line)
            call print_message_detail(line)
        end if
        iskip = (ijday2 - ijday1)*24/fms%stmg%qomeas%dts
        if (iskip > 0) then
            write(line, 1000) iskip
            call print_message_detail('Skipping ' // trim(adjustl(line)) // ' records.')
            ierr = read_records_txt(iun, fms%stmg%qomeas%val, iskip)
            if (ierr /= 0) then
                call print_warning('Reached end of file.')
            end if
        end if

        !> Read the first record, then reposition to the first record.
        ierr = read_records_txt(iun, fms%stmg%qomeas%val)
        if (ierr /= 0) fms%stmg%qomeas%val = 0.0
        backspace(iun)

        !> Warn if the initial value is zero.
        if (any(fms%stmg%qomeas%val == 0.0)) then
            call print_warning('The measured value at the simulation start date is zero.')
            call print_message('This may cause channels to initialize with no storage.')
        end if

        !> Print a summary of locations to file.
        write(line, 1000) fms%stmg%n
        call print_message_detail('Number of streamflow gauges: ' // trim(adjustl(line)))
        if (DIAGNOSEMODE) then
            write(line, 1001) 'GAUGE', 'IY', 'JX', 'DA (km/km2)', 'RANK'
            call print_message_detail(line)
            do i = 1, fms%stmg%n
                write(line, 1001) i, fms%stmg%meta%iy(i), fms%stmg%meta%jx(i), shd%DA(fms%stmg%meta%rnk(i)), &
                    fms%stmg%meta%rnk(i)
                call print_message_detail(line)
            end do
            call print_message('')
        end if
    end if

    !> Reservoir outlet locations.

    !> File unit and name.
    fname = fms%rsvr%rlsmeas%fls%fname
    iun = fms%rsvr%rlsmeas%fls%iun

    !> Read location from file if reaches exist.
    if (any(shd%IREACH > 0)) then

        !> Initialize time-series.
        fms%rsvr%rlsmeas%iyear = ic%start%year
        fms%rsvr%rlsmeas%ijday = ic%start%jday
        fms%rsvr%rlsmeas%ihour = ic%start%hour
        fms%rsvr%rlsmeas%imins = ic%start%mins

        !> Read from file.
        select case (lowercase(fms%rsvr%rlsmeas%fls%ffmt))
            case ('tb0')
                fname = trim(adjustl(fname)) // '.tb0'
                call read_reservoir_tb0(shd, iun, fname)
            case default
                fname = trim(adjustl(fname)) // '.txt'
                call read_reservoir_txt(shd, iun, fname, 2)
        end select
    else
        fms%rsvr%n = 0
    end if

    !> Print an error if no reservoirs are defined but reaches exist from the drainage database file.
    if (maxval(shd%IREACH) /= fms%rsvr%n) then
        call print_error('The number of reservoirs does not match between the drainage database (IREACH) ' // &
            'and in: ' // trim(adjustl(fname)))
        write(line, 1000) maxval(shd%IREACH)
        call print_message_detail('Maximum IREACH the drainage database: ' // trim(adjustl(line)))
        write(line, 1000) fms%rsvr%n
        call print_message_detail('Number of reservoirs read from file: ' // trim(adjustl(line)))
        call stop_program()
    end if

    !> If locations exist.
    if (fms%rsvr%n > 0) then

        !> Print to status file.
        call print_echo_txt(trim(fname))

        !> Find the x-y cell coordinate of the location.
        fms%rsvr%meta%iy = int((fms%rsvr%meta%y - shd%yOrigin)/shd%yDelta) + 1
        fms%rsvr%meta%jx = int((fms%rsvr%meta%x - shd%xOrigin)/shd%xDelta) + 1

        !> Find the RANK of the location.
        fms%rsvr%meta%rnk = 0
        do i = 1, fms%rsvr%n
            do n = 1, shd%NAA
                if (fms%rsvr%meta%jx(i) == shd%xxx(n) .and. fms%rsvr%meta%iy(i) == shd%yyy(n)) fms%rsvr%meta%rnk(i) = n
            end do
        end do

        !> Print an error if any location has no RANK (is outside the basin).
        if (minval(fms%rsvr%meta%rnk) == 0) then
            call print_error('Reservoir outlet(s) are outside the basin.')
            write(line, 1001) 'OUTLET', 'Y', 'IY', 'X', 'JX'
            call print_message_detail(line)
            do i = 1, fms%rsvr%n
                if (fms%rsvr%meta%rnk(i) == 0) then
                    write(line, 1001) i, fms%rsvr%meta%y(i), fms%rsvr%meta%iy(i), fms%rsvr%meta%x(i), fms%rsvr%meta%jx(i)
                    call print_message_detail(line)
                end if
            end do
            call stop_program()
        end if

        !> Print an error if any outlet location has no REACH.
        ierr = 0
        do i = 1, fms%rsvr%n
            if (fms%rsvr%meta%rnk(i) > 0) then
                if (shd%IREACH(fms%rsvr%meta%rnk(i)) /= i) then
                    if (ierr == 0) then
                        call print_error('Mis-match between IREACH and reservoir IDs.')
                        write(line, 1001) 'RANK', 'IREACH', 'EXPECTING'
                        call print_message(line)
                    end if
                    write(line, 1001) fms%rsvr%meta%rnk(i), shd%IREACH(fms%rsvr%meta%rnk(i)), i
                    call print_message(line)
                    ierr = 1
                end if
            end if
        end do
        if (ierr /= 0) call stop_program()

        !> Initialize reservoir release values if such a type of reservoir has been defined.
        if (count(fms%rsvr%rls%b1 == 0.0) > 0) then

            !> Re-allocate release values to the number of controlled reservoirs.
            if (fms%rsvr%rlsmeas%readmode /= 'n') then
                deallocate(fms%rsvr%rlsmeas%val)
                allocate(fms%rsvr%rlsmeas%val(count(fms%rsvr%rls%b1 == 0.0)))
                fms%rsvr%rlsmeas%val = 0.0
            end if

            !> Skips records to present in file.
            call Julian_Day_ID(fms%rsvr%rlsmeas%iyear, fms%rsvr%rlsmeas%ijday, ijday1)
            call Julian_Day_ID(ic%start%year, ic%start%jday, ijday2)
            if (ijday2 < ijday1) then
                call print_error('The first record occurs after the simulation start date.')
                call print_message( &
                    'The record must start on or after the simulation start date when controlled reservoirs are active.')
                write(line, "(i5, i4)") fms%rsvr%rlsmeas%iyear, fms%rsvr%rlsmeas%ijday
                write(line, 1002) 'First record occurs on:', trim(line)
                call print_message_detail(line)
                write(line, "(i5, i4)") ic%start%year, ic%start%jday
                write(line, 1002) 'Simulation start date:', trim(line)
                call print_message_detail(line)
                call stop_program()
            end if
            iskip = (ijday2 - ijday1)*24/fms%rsvr%rlsmeas%dts
            if (iskip > 0) then
                write(line, 1000) iskip
                call print_message_detail('Skipping ' // trim(adjustl(line)) // ' records.')
                ierr = read_records_txt(iun, fms%rsvr%rlsmeas%val, iskip)
                if (ierr /= 0) then
                    call print_error('Reached end of file.')
                    call stop_program()
                end if
            end if

            !> Read the first record, then reposition to the first record.
            !> Stop if no releases exist.
            ierr = read_records_txt(iun, fms%rsvr%rlsmeas%val)
            if (ierr /= 0) then
                call print_error('Reached end of file.')
                call stop_program()
            end if
            backspace(iun)
        end if

        !> Print a summary of locations to file.
        write(line, 1000) fms%rsvr%n
        call print_message_detail('Number of reservoir outlets: ' // trim(adjustl(line)))
        if (DIAGNOSEMODE) then
            write(line, 1001) 'OUTLET', 'IY', 'JX', 'RANK'
            call print_message_detail(line)
            do i = 1, fms%rsvr%n
                write(line, 1001) i, fms%rsvr%meta%iy(i), fms%rsvr%meta%jx(i), fms%rsvr%meta%rnk(i)
                call print_message_detail(line)
            end do
            call print_message('')
        end if
    end if

    !> Format statements.
1000    format(i10)
1001    format(9999(g15.6, 1x))
1002    format(a29, 1x, g13.2)

end subroutine
