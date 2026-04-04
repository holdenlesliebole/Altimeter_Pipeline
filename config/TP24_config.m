function cfg = TP24_config()
    cfg.name        = 'TP24';
    cfg.rawDataRoot = '/Volumes/group/Altimeter_data/TorreyPines';
    cfg.outputDir   = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.site        = 'TorreyPines';
    cfg.mop         = 'MOP586';
    % Instrument positions vary by depth — stored per deployment below

    k = 0;

    %% Phase 1: Altimeters only (Feb - Aug 2024)
    %  Sensor IDs: 0127=5m, 0128=7m, 0130=10m, 0131=15m
    %  Firmware bug: altimeters overwritten with Error-3, data missing before ~Apr 24

    k = k + 1;
    cfg.deployments(k).label            = 'MOP586_5m_20240214';
    cfg.deployments(k).depth_m          = 5;
    cfg.deployments(k).altimeterFiles   = {'20240214_162515_RANGELOGGER450kHz_ID_0127.log', ...
                                           '20240513_171949_RANGELOGGER450kHz_ID_0127.log'};
    cfg.deployments(k).echosounderFiles = {};
    cfg.deployments(k).tz_offset_hours  = 7;
    cfg.deployments(k).notes            = 'firmware bug lost data before ~Apr 24; 5m recovered May 13 (pipe exposed)';

    k = k + 1;
    cfg.deployments(k).label            = 'MOP586_7m_20240213';
    cfg.deployments(k).depth_m          = 7;
    cfg.deployments(k).altimeterFiles   = {'20240119_151750_RANGELOGGER450kHz_ID_0128.log', ...
                                           '20240814_111056_RANGELOGGER450kHz_ID_0128.log'};
    cfg.deployments(k).echosounderFiles = {};
    cfg.deployments(k).tz_offset_hours  = 7;
    cfg.deployments(k).notes            = 'firmware bug lost data before ~Apr 24; recovered Aug 14 2024';

    k = k + 1;
    cfg.deployments(k).label            = 'MOP586_10m_20240213';
    cfg.deployments(k).depth_m          = 10;
    cfg.deployments(k).altimeterFiles   = {'20240213_150935_RANGELOGGER450kHz_ID_0130.log', ...
                                           '20240814_100146_RANGELOGGER450kHz_ID_0130.log'};
    cfg.deployments(k).echosounderFiles = {};
    cfg.deployments(k).tz_offset_hours  = 7;
    cfg.deployments(k).notes            = 'firmware bug lost data before ~Apr 24; recovered Aug 14 2024';

    k = k + 1;
    cfg.deployments(k).label            = 'MOP586_15m_20240213';
    cfg.deployments(k).depth_m          = 15;
    cfg.deployments(k).altimeterFiles   = {'20240213_164124_RANGELOGGER450kHz_ID_0131.log', ...
                                           '20240813_112413_RANGELOGGER450kHz_ID_0131.log'};
    cfg.deployments(k).echosounderFiles = {};
    cfg.deployments(k).tz_offset_hours  = 7;
    cfg.deployments(k).notes            = 'firmware bug lost data before ~Apr 24; recovered Aug 13; 15m pulled after this';

    %% Phase 2: Echosounders (Jul 26 - Nov 2024)
    %  3 EA400 echosounders replaced altimeters at 5m, 7m, 10m

    k = k + 1;
    cfg.deployments(k).label            = 'MOP586_5m_20240725';
    cfg.deployments(k).depth_m          = 5;
    cfg.deployments(k).altimeterFiles   = {};
    cfg.deployments(k).echosounderFiles = {'ECHO20240725_212809_169_5m.BIN'};
    cfg.deployments(k).tz_offset_hours  = 7;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP586_7m_20240725';
    cfg.deployments(k).depth_m          = 7;
    cfg.deployments(k).altimeterFiles   = {};
    cfg.deployments(k).echosounderFiles = {'ECHO20241107_115635_215_7m_1.BIN', ...
                                           'ECHO20241107_115635_215_7m_2.BIN'};
    cfg.deployments(k).tz_offset_hours  = 7;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP586_10m_20240725';
    cfg.deployments(k).depth_m          = 10;
    cfg.deployments(k).altimeterFiles   = {};
    cfg.deployments(k).echosounderFiles = {'ECHO20240725_210006_180_10m.BIN'};
    cfg.deployments(k).tz_offset_hours  = 7;
    cfg.deployments(k).notes            = '10m echosounder stopped after ~1 month';

    k = k + 1;
    cfg.deployments(k).label            = 'MOP586_15m_20241122';
    cfg.deployments(k).depth_m          = 15;
    cfg.deployments(k).altimeterFiles   = {'20241202_160207_RANGELOGGER450kHz_ID_0208.log'};
    cfg.deployments(k).echosounderFiles = {};
    cfg.deployments(k).tz_offset_hours  = 8;
    cfg.deployments(k).notes            = 'altimeter only; deployed Nov, recovered Dec 2024';

end
