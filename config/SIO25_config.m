function cfg = SIO25_config()
    cfg.name        = 'SIO25';
    cfg.rawDataRoot = '/Volumes/group/Altimeter_data/SouthSIOPier';
    cfg.outputDir   = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.site        = 'SouthSIOPier';
    cfg.mop         = 'MOP511';

    k = 0;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP511_6m_20241220';
    cfg.deployments(k).depth_m          = 6;
    cfg.deployments(k).altimeterFiles   = {'data/AltimeterData/20241220_224029_RANGELOGGER450kHz_ID_0207.log'};
    cfg.deployments(k).echosounderFiles = {'data/EchologgerData/20241220-20250107MOP511_6m.log'};
    cfg.deployments(k).tz_offset_hours  = 8;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP511_6m_20250123';
    cfg.deployments(k).depth_m          = 6;
    cfg.deployments(k).altimeterFiles   = {'data/AltimeterData/20250123_130707_RANGELOGGER450kHz_ID_0130.log'};
    cfg.deployments(k).echosounderFiles = {'data/EchologgerData/20250107-20250123MOP511_6m.log', ...
                                           'data/EchologgerData/20250123-20250227MOP511_6m.log'};
    cfg.deployments(k).tz_offset_hours  = 8;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP511_6m_20250310';
    cfg.deployments(k).depth_m          = 6;
    cfg.deployments(k).altimeterFiles   = {'data/AltimeterData/20250310_114345_RANGELOGGER450kHz_ID_0060.log'};
    cfg.deployments(k).echosounderFiles = {'data/EchologgerData/20250227-20250310MOP511_6m.log', ...
                                           'data/EchologgerData/20250310-20250319MOP511_6m.log'};
    cfg.deployments(k).tz_offset_hours  = 7;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP511_6m_20250417';
    cfg.deployments(k).depth_m          = 6;
    cfg.deployments(k).altimeterFiles   = {'data/AltimeterData/20250417_160706_RANGELOGGER450kHz_ID_0130.log'};
    cfg.deployments(k).echosounderFiles = {'data/EchologgerData/20250319-20250328MOP511_6m.log', ...
                                           'data/EchologgerData/20250328-20250406MOP511_6m.log', ...
                                           'data/EchologgerData/20250406-20250415MOP511_6m.log', ...
                                           'data/EchologgerData/20250415-20250417MOP511_6m.log'};
    cfg.deployments(k).tz_offset_hours  = 7;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP511_6m_20250521';
    cfg.deployments(k).depth_m          = 6;
    cfg.deployments(k).altimeterFiles   = {'data/AltimeterData/20250521_101218_RANGELOGGER450kHz_ID_0127.log'};
    cfg.deployments(k).echosounderFiles = {};
    cfg.deployments(k).tz_offset_hours  = 7;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP511_6m_20250625';
    cfg.deployments(k).depth_m          = 6;
    cfg.deployments(k).altimeterFiles   = {'data/AltimeterData/20250625_141603_RANGELOGGER450kHz_ID_0130.log'};
    cfg.deployments(k).echosounderFiles = {};
    cfg.deployments(k).tz_offset_hours  = 7;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP511_6m_20250721';
    cfg.deployments(k).depth_m          = 6;
    cfg.deployments(k).altimeterFiles   = {'data/AltimeterData/20250721_121530_RANGELOGGER450kHz_ID_0207.log'};
    cfg.deployments(k).echosounderFiles = {};
    cfg.deployments(k).tz_offset_hours  = 7;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP511_6m_20250821';
    cfg.deployments(k).depth_m          = 6;
    cfg.deployments(k).altimeterFiles   = {'data/AltimeterData/20250821_112312_RANGELOGGER450kHz_ID_0130.log'};
    cfg.deployments(k).echosounderFiles = {};
    cfg.deployments(k).tz_offset_hours  = 7;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP511_6m_20250924';
    cfg.deployments(k).depth_m          = 6;
    cfg.deployments(k).altimeterFiles   = {'data/AltimeterData/20250924_201028_RANGELOGGER450kHz_ID_0207.log'};
    cfg.deployments(k).echosounderFiles = {};
    cfg.deployments(k).tz_offset_hours  = 7;

end
