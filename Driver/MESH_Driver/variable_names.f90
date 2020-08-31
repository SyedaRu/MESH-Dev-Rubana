module variable_names

    implicit none

    !> Meteorology/climatology variables.
    character(len = 10), parameter :: VN_FSIN = 'FSIN'
    character(len = 10), parameter :: VN_FSVH = 'FSVH'
    character(len = 10), parameter :: VN_FSIH = 'FSIH'
    character(len = 10), parameter :: VN_FSDIR = 'FSDIR'
    character(len = 10), parameter :: VN_FSDFF = 'FSDFF'
    character(len = 10), parameter :: VN_FSOUT = 'FSOUT'
    character(len = 10), parameter :: VN_FLIN = 'FLIN'
    character(len = 10), parameter :: VN_FLOUT = 'FLOUT'
    character(len = 10), parameter :: VN_TA = 'TA'
    character(len = 10), parameter :: VN_QA = 'QA'
    character(len = 10), parameter :: VN_PRES = 'PRES'
    character(len = 10), parameter :: VN_UV = 'UV'
    character(len = 10), parameter :: VN_WDIR = 'WDIR'
    character(len = 10), parameter :: VN_UU = 'UU'
    character(len = 10), parameter :: VN_VV = 'VV'
    character(len = 10), parameter :: VN_PRE = 'PRE'
    character(len = 10), parameter :: VN_PRERN = 'PRERN'
    character(len = 10), parameter :: VN_PRESNO = 'PRESNO'
    character(len = 10), parameter :: VN_PREC = 'PREC'
    character(len = 10), parameter :: VN_PRECRN = 'PRECRN'
    character(len = 10), parameter :: VN_PRECSNO = 'PRECSNO'

    !> Canopy variables.
    character(len = 10), parameter :: VN_RCAN = 'RCAN'
    character(len = 10), parameter :: VN_SNCAN = 'SNCAN'
    character(len = 10), parameter :: VN_CMAS = 'CMAS'
    character(len = 10), parameter :: VN_TCAN = 'TCAN'
    character(len = 10), parameter :: VN_GRO = 'GRO'

    !> Snow variables.
    character(len = 10), parameter :: VN_SNO = 'SNO'
    character(len = 10), parameter :: VN_RHOSNO = 'RHOSNO'
    character(len = 10), parameter :: VN_ZSNO = 'ZSNO'
    character(len = 10), parameter :: VN_FSNO = 'FSNO'
    character(len = 10), parameter :: VN_WSNO = 'WSNO'
    character(len = 10), parameter :: VN_TSNO = 'TSNO'
    character(len = 10), parameter :: VN_ROFSNO = 'ROFSNO'

    !> Surface variables.
    character(len = 10), parameter :: VN_ALBT = 'ALBT'
    character(len = 10), parameter :: VN_ALVS = 'ALVS'
    character(len = 10), parameter :: VN_ALIR = 'ALIR'
    character(len = 10), parameter :: VN_GTE = 'GTE'
    character(len = 10), parameter :: VN_ZPND = 'ZPND'
    character(len = 10), parameter :: VN_PNDW = 'PNDW'
    character(len = 10), parameter :: VN_TPND = 'TPND'
    character(len = 10), parameter :: VN_PEVP = 'PEVP'
    character(len = 10), parameter :: VN_EVAP = 'EVAP'
    character(len = 10), parameter :: VN_EVPB = 'EVPB'
    character(len = 10), parameter :: VN_ARRD = 'ARRD'
    character(len = 10), parameter :: VN_ROFO = 'ROFO'
    character(len = 10), parameter :: VN_QE = 'QE'
    character(len = 10), parameter :: VN_QH = 'QH'
    character(len = 10), parameter :: VN_GZERO = 'GZERO'

    !> Subsurface/soil variables.
    character(len = 10), parameter :: VN_THLQ = 'THLQ'
    character(len = 10), parameter :: VN_THIC = 'THIC'
    character(len = 10), parameter :: VN_LQWS = 'LQWS'
    character(len = 10), parameter :: VN_FZWS = 'FZWS'
    character(len = 10), parameter :: VN_ALWS = 'ALWS'
    character(len = 10), parameter :: VN_TBAR = 'TBAR'
    character(len = 10), parameter :: VN_GFLX = 'GFLX'
    character(len = 10), parameter :: VN_ROFS = 'ROFS'
    character(len = 10), parameter :: VN_ROFB = 'ROFB'

    !> Groundwater/lower zone storage variables.
    character(len = 10), parameter :: VN_RCHG = 'RCHG'
    character(len = 10), parameter :: VN_LZS = 'LZS'
    character(len = 10), parameter :: VN_DZS = 'DZS'

    !> Diagnostic variables.
    character(len = 10), parameter :: VN_STGE = 'STGE'
    character(len = 10), parameter :: VN_DSTGE = 'DSTGE'
    character(len = 10), parameter :: VN_STGW = 'STGW'
    character(len = 10), parameter :: VN_DSTGW = 'DSTGW'

    !> Routing variables.
    character(len = 10), parameter :: VN_RFF = 'RFF'
    character(len = 10), parameter :: VN_ROF = 'ROF'
    character(len = 10), parameter :: VN_QI = 'QI'
    character(len = 10), parameter :: VN_QO = 'QO'
    character(len = 10), parameter :: VN_STGCH = 'STGCH'
    character(len = 10), parameter :: VN_ZLVL = 'ZLVL'

end module
