% ALT_L1_DRIVER  Level-1 through Level-3 processing for all deployments in a config.
%
%   Loads raw altimeter/echosounder data, applies QC (despike, tilt mask),
%   derives bed level change, and saves one set of L1/L2/L3 .mat files per
%   deployment plus quicklook PNGs.
%
%   To process a different deployment group, change deployment_name below.

%% ======================== USER SETTINGS ========================
deployment_name = 'TP25';  % change to process a different deployment group

%% ======================== SETUP ========================
codeDir   = fileparts(mfilename('fullpath'));
configDir = fullfile(codeDir, '..', 'config');

addpath(codeDir);
addpath(configDir);

% Load the deployment configuration from the registry
registry = deployment_registry();
if ~isKey(registry, deployment_name)
    error('ALT_L1_driver:unknownDeployment', ...
        'Deployment "%s" not found in registry. Available: %s', ...
        deployment_name, strjoin(keys(registry), ', '));
end
configFn = registry(deployment_name);
cfg = configFn();

% Use local cache if available
localCache = fullfile(codeDir, '..', 'raw_cache', cfg.name);
if isfolder(localCache)
    cfg.localDataRoot = localCache;
    fprintf('Using local cache: %s\n', localCache);
end

% QC parameters
cfg.qcParams.winMovMean = minutes(15);
cfg.qcParams.thr1_mm    = 200;
cfg.qcParams.thr2_mm    = 100;
cfg.qcParams.jump_mm    = 10;
cfg.qcParams.useHampel  = false;

cfg.savePlots = true;
cfg.overwrite = false;

% Output directory
outRoot = fullfile(cfg.outputDir, cfg.name);
if ~exist(outRoot, 'dir'), mkdir(outRoot); end
cfg.outputRoot = outRoot;

%% ======================== PROCESS EACH DEPLOYMENT ========================
nDep = numel(cfg.deployments);
fprintf('\n=== Processing: %s (%d deployments) ===\n', deployment_name, nDep);

nDone = 0; nSkip = 0; nFail = 0;

for k = 1:nDep
    dep = cfg.deployments(k);
    fprintf('\n[%d/%d] %s — %s\n', k, nDep, cfg.name, dep.label);

    % Build the struct expected by process_deployment
    depStruct.DeploymentID    = string(dep.label);
    depStruct.Site            = string(cfg.site);
    depStruct.MOP             = string(cfg.mop);
    depStruct.Depth_m         = dep.depth_m;
    depStruct.TZ_offset_hours = dep.tz_offset_hours;

    % Join file lists with pipe separator (process_deployment splits on |)
    depStruct.AltimeterFiles  = strjoin(string(dep.altimeterFiles), '|');
    depStruct.EchosounderFiles = strjoin(string(dep.echosounderFiles), '|');

    % Determine data root: local cache > server
    if isfield(cfg, 'localDataRoot') && ~isempty(cfg.localDataRoot)
        cfgRun.serverRoot = cfg.localDataRoot;
    else
        cfgRun.serverRoot = cfg.rawDataRoot;
    end
    cfgRun.outputRoot  = cfg.outputRoot;
    cfgRun.qcParams    = cfg.qcParams;
    cfgRun.savePlots   = cfg.savePlots;
    cfgRun.overwrite   = cfg.overwrite;

    try
        result = process_deployment(depStruct, cfgRun);
        if result == "skip"
            nSkip = nSkip + 1;
        else
            nDone = nDone + 1;
        end
    catch ME
        warning('ALT_L1_driver:deploymentFailed', ...
            'FAILED: %s\nReason: %s', dep.label, ME.message);
        nFail = nFail + 1;
    end
end

fprintf('\nDone: %d processed, %d skipped (cached), %d errors.\n', ...
    nDone, nSkip, nFail);
