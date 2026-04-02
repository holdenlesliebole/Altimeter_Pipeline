function cfg = SOL26_config()
    cfg.name        = 'SOL26';
    cfg.rawDataRoot = '/Volumes/group/Altimeter_data/SolanaBeach';
    cfg.outputDir   = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.site        = 'SolanaBeach';
    cfg.mop         = 'MOP654';

    k = 0;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP654_7m_20251205';
    cfg.deployments(k).depth_m          = 7;
    cfg.deployments(k).altimeterFiles   = {};
    cfg.deployments(k).echosounderFiles = {'ECHO20251205_212000_155.BIN'};
    cfg.deployments(k).tz_offset_hours  = 8;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP654_7m_20260111';
    cfg.deployments(k).depth_m          = 7;
    cfg.deployments(k).altimeterFiles   = {};
    cfg.deployments(k).echosounderFiles = {'ECHO20260111_000000_169.BIN'};
    cfg.deployments(k).tz_offset_hours  = 8;

    k = k + 1;
    cfg.deployments(k).label            = 'MOP654_7m_20260216';
    cfg.deployments(k).depth_m          = 7;
    cfg.deployments(k).altimeterFiles   = {};
    cfg.deployments(k).echosounderFiles = {'ECHO20260216_024000_181.BIN'};
    cfg.deployments(k).tz_offset_hours  = 7;
    cfg.deployments(k).notes            = 'very short deployment (~2 days); pipe was tilted from Feb 7 storm';

end
