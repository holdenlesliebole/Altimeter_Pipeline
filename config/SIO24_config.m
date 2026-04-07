function cfg = SIO24_config()
    cfg.name        = 'SIO24';
    cfg.rawDataRoot = '/Volumes/group/Altimeter_data/SouthSIOPier';
    cfg.outputDir   = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.site        = 'SouthSIOPier';
    cfg.mop         = 'MOP511';
    cfg.latlon      = [32.8665, -117.2570];  % MOP511 6m instrument position
    cfg.mopNumber   = 511;  % override auto-detection (LatLon2MopxshoreX maps to MOP513)

    k = 0;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP511_6m_20240402';
    cfg.deployments(k).depth_m          = 6;
    cfg.deployments(k).altimeterFiles   = {'data/AltimeterData/20240402_121226_RANGELOGGER450kHz_ID_0208.log'};
    cfg.deployments(k).echosounderFiles = {'data/EchologgerData/20240401-20240402MOP511_6m.log', ...
                                           'data/EchologgerData/20240402-20240419MOP511_6m.log'};
    cfg.deployments(k).tz_offset_hours  = 7;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP511_6m_20240423';
    cfg.deployments(k).depth_m          = 6;
    cfg.deployments(k).altimeterFiles   = {'data/AltimeterData/20240423_124416_RANGELOGGER450kHz_ID_0208.log'};
    cfg.deployments(k).echosounderFiles = {'data/EchologgerData/20240424-20240531MOP511_6m.log'};
    cfg.deployments(k).tz_offset_hours  = 7;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP511_6m_20240531';
    cfg.deployments(k).depth_m          = 6;
    cfg.deployments(k).altimeterFiles   = {'data/AltimeterData/20240531_144756_RANGELOGGER450kHz_ID_0208.log'};
    cfg.deployments(k).echosounderFiles = {'data/EchologgerData/20240611-20240711MOP511_6m.log'};
    cfg.deployments(k).tz_offset_hours  = 7;
    cfg.deployments(k).notes            = 'echosounder gap May 31 - Jun 11';

    k = k + 1;
    cfg.deployments(k).label            = 'MOP511_6m_20240711';
    cfg.deployments(k).depth_m          = 6;
    cfg.deployments(k).altimeterFiles   = {'data/AltimeterData/20240711_154044_RANGELOGGER450kHz_ID_0208.log'};
    cfg.deployments(k).echosounderFiles = {'data/EchologgerData/20240711-20240810MOP511_6m.log'};
    cfg.deployments(k).tz_offset_hours  = 7;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP511_6m_20240813';
    cfg.deployments(k).depth_m          = 6;
    cfg.deployments(k).altimeterFiles   = {'data/AltimeterData/20240813_142324_RANGELOGGER450kHz_ID_0207.log'};
    cfg.deployments(k).echosounderFiles = {'data/EchologgerData/20240813-20240918MOP511_6m.log'};
    cfg.deployments(k).tz_offset_hours  = 7;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP511_6m_20240919';
    cfg.deployments(k).depth_m          = 6;
    cfg.deployments(k).altimeterFiles   = {'data/AltimeterData/20240919_100642_RANGELOGGER450kHz_ID_0127.log'};
    cfg.deployments(k).echosounderFiles = {'data/EchologgerData/20240917-20241023MOP511_6m.log'};
    cfg.deployments(k).tz_offset_hours  = 7;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP511_6m_20241028';
    cfg.deployments(k).depth_m          = 6;
    cfg.deployments(k).altimeterFiles   = {'data/AltimeterData/20241028_140002_RANGELOGGER450kHz_ID_0207.log'};
    cfg.deployments(k).echosounderFiles = {'data/EchologgerData/20241024-20241119MOP511_6m.log'};
    cfg.deployments(k).tz_offset_hours  = 7;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP511_6m_20241119';
    cfg.deployments(k).depth_m          = 6;
    cfg.deployments(k).altimeterFiles   = {'data/AltimeterData/20241119_151117_RANGELOGGER450kHz_ID_0127.log'};
    cfg.deployments(k).echosounderFiles = {'data/EchologgerData/20241119-20241207MOP511_6m.log'};
    cfg.deployments(k).tz_offset_hours  = 8;

end
