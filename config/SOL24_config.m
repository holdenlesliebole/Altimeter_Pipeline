function cfg = SOL24_config()
    cfg.name        = 'SOL24';
    cfg.rawDataRoot = '/Volumes/group/Altimeter_data/SolanaBeach';
    cfg.outputDir   = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.site        = 'SolanaBeach';
    cfg.mop         = 'MOP654';
    cfg.latlon      = [32.99064, -117.27897];

    k = 0;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP654_7m_20240119';
    cfg.deployments(k).depth_m          = 7;
    cfg.deployments(k).altimeterFiles   = {'20240119_162029_RANGELOGGER450kHz_ID_0207.log'};
    cfg.deployments(k).echosounderFiles = {};
    cfg.deployments(k).tz_offset_hours  = 8;   % Nov-2023 local PST (+8) -> UTC; per ISSUE-001 verified map
    cfg.deployments(k).notes            = '7m at MOP654.5; co-located with SOL23 PUV (Nov 16 2023-Jan 18 2024); altimeter record spans Nov 14 2023-Jan 18 2024; depth confirmed 2026-05-20 from SOL23 PUV co-location (was logged as depth-unknown)';

    k = k + 1;
    cfg.deployments(k).label            = 'MOP654_7m_20241122';
    cfg.deployments(k).depth_m          = 7;
    cfg.deployments(k).altimeterFiles   = {};
    cfg.deployments(k).echosounderFiles = {'ECHO20241122_230730_194_7mSolana.BIN'};
    cfg.deployments(k).tz_offset_hours  = 0;   % .BIN posix timestamps are already UTC

    k = k + 1;
    cfg.deployments(k).label            = 'MOP654_7m_20250114';
    cfg.deployments(k).depth_m          = 7;
    cfg.deployments(k).altimeterFiles   = {};
    cfg.deployments(k).echosounderFiles = {'ECHO20250114_062730_119_7mSolana.BIN'};
    cfg.deployments(k).tz_offset_hours  = 0;   % .BIN posix timestamps are already UTC

end
