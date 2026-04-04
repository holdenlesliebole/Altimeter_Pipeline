function cfg = SOL25_config()
    cfg.name        = 'SOL25';
    cfg.rawDataRoot = '/Volumes/group/Altimeter_data/SolanaBeach';
    cfg.outputDir   = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.site        = 'SolanaBeach';
    cfg.mop         = 'MOP654';
    cfg.latlon      = [32.99064, -117.27897];  % MOP654 7m instrument position

    k = 0;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP654_7m_20250304';
    cfg.deployments(k).depth_m          = 7;
    cfg.deployments(k).altimeterFiles   = {};
    cfg.deployments(k).echosounderFiles = {'ECHO20250304_192040_193.BIN'};
    cfg.deployments(k).tz_offset_hours  = 7;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP654_7m_20250409';
    cfg.deployments(k).depth_m          = 7;
    cfg.deployments(k).altimeterFiles   = {};
    cfg.deployments(k).echosounderFiles = {'ECHO20250409_220040_206.BIN'};
    cfg.deployments(k).tz_offset_hours  = 7;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP654_7m_20250516';
    cfg.deployments(k).depth_m          = 7;
    cfg.deployments(k).altimeterFiles   = {};
    cfg.deployments(k).echosounderFiles = {'ECHO20250516_004040_218.BIN'};
    cfg.deployments(k).tz_offset_hours  = 7;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP654_7m_20250621';
    cfg.deployments(k).depth_m          = 7;
    cfg.deployments(k).altimeterFiles   = {};
    cfg.deployments(k).echosounderFiles = {'ECHO20250621_032040_107.BIN'};
    cfg.deployments(k).tz_offset_hours  = 7;
    cfg.deployments(k).notes            = 'very short deployment (~3 days)';

end
