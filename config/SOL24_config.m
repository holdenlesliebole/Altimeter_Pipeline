function cfg = SOL24_config()
    cfg.name        = 'SOL24';
    cfg.rawDataRoot = '/Volumes/group/Altimeter_data/SolanaBeach';
    cfg.outputDir   = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.site        = 'SolanaBeach';
    cfg.mop         = 'MOP654';
    cfg.latlon      = [32.99064, -117.27897];

    k = 0;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP654_0m_20240119';
    cfg.deployments(k).depth_m          = 0;
    cfg.deployments(k).altimeterFiles   = {'20240119_162029_RANGELOGGER450kHz_ID_0207.log'};
    cfg.deployments(k).echosounderFiles = {};
    cfg.deployments(k).tz_offset_hours  = 8;
    cfg.deployments(k).notes            = 'early test deployment; depth unknown';

    k = k + 1;
    cfg.deployments(k).label            = 'MOP654_7m_20241122';
    cfg.deployments(k).depth_m          = 7;
    cfg.deployments(k).altimeterFiles   = {};
    cfg.deployments(k).echosounderFiles = {'ECHO20241122_230730_194_7mSolana.BIN'};
    cfg.deployments(k).tz_offset_hours  = 8;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP654_7m_20250114';
    cfg.deployments(k).depth_m          = 7;
    cfg.deployments(k).altimeterFiles   = {};
    cfg.deployments(k).echosounderFiles = {'ECHO20250114_062730_119_7mSolana.BIN'};
    cfg.deployments(k).tz_offset_hours  = 8;

end
