function cfg = SIO26_config()
    cfg.name        = 'SIO26';
    cfg.rawDataRoot = '/Volumes/group/Altimeter_data/SouthSIOPier';
    cfg.outputDir   = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.site        = 'SouthSIOPier';
    cfg.mop         = 'MOP511';
    cfg.latlon      = [32.8665, -117.2570];
    cfg.mopNumber   = 511;

    k = 0;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP511_6m_20251031';
    cfg.deployments(k).depth_m          = 6;
    cfg.deployments(k).altimeterFiles   = {'data/AltimeterData/20251031_211434_RANGELOGGER450kHz_ID_0130.log'};
    cfg.deployments(k).echosounderFiles = {};
    cfg.deployments(k).tz_offset_hours  = 8;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP511_6m_20251126';
    cfg.deployments(k).depth_m          = 6;
    cfg.deployments(k).altimeterFiles   = {'data/AltimeterData/20251126_091304_RANGELOGGER450kHz_ID_0207.log'};
    cfg.deployments(k).echosounderFiles = {};
    cfg.deployments(k).tz_offset_hours  = 8;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP511_6m_20260105';
    cfg.deployments(k).depth_m          = 6;
    cfg.deployments(k).altimeterFiles   = {'data/AltimeterData/20260105_103603_RANGELOGGER450kHz_ID_0130.log'};
    cfg.deployments(k).echosounderFiles = {};
    cfg.deployments(k).tz_offset_hours  = 8;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP511_6m_20260122';
    cfg.deployments(k).depth_m          = 6;
    cfg.deployments(k).altimeterFiles   = {'data/AltimeterData/20260122_103657_RANGELOGGER450kHz_ID_0207.log'};
    cfg.deployments(k).echosounderFiles = {};
    cfg.deployments(k).tz_offset_hours  = 8;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP511_6m_20260226';
    cfg.deployments(k).depth_m          = 6;
    cfg.deployments(k).altimeterFiles   = {'data/AltimeterData/20260226_214521_RANGELOGGER450kHz_ID_0130.log'};
    cfg.deployments(k).echosounderFiles = {};
    cfg.deployments(k).tz_offset_hours  = 7;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP511_6m_20260326';
    cfg.deployments(k).depth_m          = 6;
    cfg.deployments(k).altimeterFiles   = {'data/AltimeterData/20260326_232640_RANGELOGGER450kHz_ID_0207.log'};
    cfg.deployments(k).echosounderFiles = {};
    cfg.deployments(k).tz_offset_hours  = 7;

end
