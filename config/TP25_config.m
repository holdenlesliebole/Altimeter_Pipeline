function cfg = TP25_config()
    cfg.name        = 'TP25';
    cfg.rawDataRoot = '/Volumes/group/Altimeter_data/TorreyPines';
    cfg.outputDir   = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.site        = 'TorreyPines';
    cfg.mop         = 'MOP586';

    k = 0;

    %% Period 1: Nov 2024 - Feb 2025

    k = k + 1;
    cfg.deployments(k).label            = 'MOP586_5m_20241122';
    cfg.deployments(k).depth_m          = 5;
    cfg.deployments(k).altimeterFiles   = {};
    cfg.deployments(k).echosounderFiles = {'ECHO20241122_223110_255_5m.BIN'};
    cfg.deployments(k).tz_offset_hours  = 8;
    cfg.deployments(k).notes            = 'pipe bent during 12/22/2024 storm; ghosting in data after that';

    k = k + 1;
    cfg.deployments(k).label            = 'MOP586_7m_20241122';
    cfg.deployments(k).depth_m          = 7;
    cfg.deployments(k).altimeterFiles   = {};
    cfg.deployments(k).echosounderFiles = {'ECHO20241122_224817_562_7m.BIN'};
    cfg.deployments(k).tz_offset_hours  = 8;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP586_5m_20250114';
    cfg.deployments(k).depth_m          = 5;
    cfg.deployments(k).altimeterFiles   = {};
    cfg.deployments(k).echosounderFiles = {'ECHO20250114_055110_246_5m.BIN'};
    cfg.deployments(k).tz_offset_hours  = 8;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP586_7m_20250114';
    cfg.deployments(k).depth_m          = 7;
    cfg.deployments(k).altimeterFiles   = {};
    cfg.deployments(k).echosounderFiles = {'ECHO20250114_060817_156_7m.BIN'};
    cfg.deployments(k).tz_offset_hours  = 8;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP586_10m_20241122';
    cfg.deployments(k).depth_m          = 10;
    cfg.deployments(k).altimeterFiles   = {'20250221_090158_RANGELOGGER450kHz_ID_0127.log'};
    cfg.deployments(k).echosounderFiles = {};
    cfg.deployments(k).tz_offset_hours  = 8;
    cfg.deployments(k).notes            = 'sensor ID 0127 reassigned from 5m to 10m for this period';

    k = k + 1;
    cfg.deployments(k).label            = 'MOP586_15m_20241122';
    cfg.deployments(k).depth_m          = 15;
    cfg.deployments(k).altimeterFiles   = {'20250221_133214_RANGELOGGER450kHz_ID_0128.log'};
    cfg.deployments(k).echosounderFiles = {};
    cfg.deployments(k).tz_offset_hours  = 8;
    cfg.deployments(k).notes            = 'sensor ID 0128 reassigned from 7m to 15m for this period';

    %% Period 2: Mar - Jun 2025

    k = k + 1;
    cfg.deployments(k).label            = 'MOP586_5m_20250325';
    cfg.deployments(k).depth_m          = 5;
    cfg.deployments(k).altimeterFiles   = {};
    cfg.deployments(k).echosounderFiles = {'ECHO20250325_175753_150.BIN', ...
                                           'ECHO20250420_213753_176.BIN', ...
                                           'ECHO20250517_011753_200.BIN', ...
                                           'ECHO20250612_045753_224.BIN'};
    cfg.deployments(k).tz_offset_hours  = 7;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP586_10m_20250305';
    cfg.deployments(k).depth_m          = 10;
    cfg.deployments(k).altimeterFiles   = {'20250609_230627_RANGELOGGER450kHz_ID_0207.log'};
    cfg.deployments(k).echosounderFiles = {};
    cfg.deployments(k).tz_offset_hours  = 7;
    cfg.deployments(k).notes            = 'sensor ID 0207; recovered Jun 9 2025';

    k = k + 1;
    cfg.deployments(k).label            = 'MOP586_15m_20250305';
    cfg.deployments(k).depth_m          = 15;
    cfg.deployments(k).altimeterFiles   = {'20250610_160636_RANGELOGGER450kHz_ID_0208.log'};
    cfg.deployments(k).echosounderFiles = {};
    cfg.deployments(k).tz_offset_hours  = 7;
    cfg.deployments(k).notes            = 'sensor ID 0208; recovered Jun 10 2025';

end
