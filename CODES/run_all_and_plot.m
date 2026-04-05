% RUN_ALL_AND_PLOT  Batch-process all deployments and generate site time series plots.
%
% Processes all config groups, saves L1/L2/L3 to a unified outputs directory,
% then generates one multi-panel time series figure per site with survey overlay.

clear; close all;

%% ======================== SETUP ========================
codeDir   = fileparts(mfilename('fullpath'));
configDir = fullfile(codeDir, '..', 'config');
outRoot   = fullfile(codeDir, '..', 'outputs', 'all');
figDir    = fullfile(codeDir, '..', 'outputs', 'figures');

addpath(codeDir);
addpath(configDir);
addpath('/Users/holden/Documents/Scripps/Research/toolbox');
addpath('/Users/holden/Documents/Scripps/Research/Beach_Change_Observation/mop');

if ~exist(outRoot, 'dir'), mkdir(outRoot); end
if ~exist(figDir, 'dir'), mkdir(figDir); end

%% ======================== QC + PROCESSING CONFIG ========================
cfg.qcParams   = struct();  % phase-space default
cfg.savePlots  = false;     % skip per-deployment quicklooks (generating site plots instead)
cfg.overwrite  = false;     % skip already-processed deployments
cfg.outputRoot = outRoot;

%% ======================== PROCESS ALL CONFIGS ============================
registry = deployment_registry();
configNames = keys(registry);

fprintf('\n=== Processing %d deployment groups ===\n', numel(configNames));
totalDone = 0; totalSkip = 0; totalFail = 0;

for c = 1:numel(configNames)
    cName = configNames{c};
    fprintf('\n======== %s ========\n', cName);

    configFn = registry(cName);
    depCfg = configFn();

    % Check for local cache
    localCache = fullfile(codeDir, '..', 'raw_cache', depCfg.name);
    if isfolder(localCache)
        dataRoot = localCache;
        fprintf('  Using local cache\n');
    else
        dataRoot = depCfg.rawDataRoot;
    end

    for k = 1:numel(depCfg.deployments)
        dep = depCfg.deployments(k);

        depStruct.DeploymentID    = string(dep.label);
        depStruct.Site            = string(depCfg.site);
        depStruct.MOP             = string(depCfg.mop);
        depStruct.Depth_m         = dep.depth_m;
        depStruct.TZ_offset_hours = dep.tz_offset_hours;
        depStruct.AltimeterFiles  = strjoin(string(dep.altimeterFiles), '|');
        depStruct.EchosounderFiles = strjoin(string(dep.echosounderFiles), '|');

        cfgRun = cfg;
        cfgRun.serverRoot = dataRoot;

        try
            result = process_deployment(depStruct, cfgRun);
            if result == "skip"
                totalSkip = totalSkip + 1;
            else
                totalDone = totalDone + 1;
            end
        catch ME
            fprintf('  FAIL: %s — %s\n', dep.label, ME.message);
            totalFail = totalFail + 1;
        end
    end
end

fprintf('\n=== Processing complete: %d done, %d skipped, %d failed ===\n', ...
    totalDone, totalSkip, totalFail);

%% ======================== SITE TIME SERIES PLOTS =========================
fprintf('\n=== Generating site time series plots ===\n');

% --- SIO Pier (MOP511, 6m) --- no surveys available
try
    fig = plot_site_timeseries('SouthSIOPier', outRoot, ...
        'savePath', fullfile(figDir, 'timeseries_SouthSIOPier.png'));
    close(fig);
catch ME
    fprintf('SIO plot failed: %s\n', ME.message);
end

% --- Torrey Pines (MOP586, multi-depth) --- use 5m position for surveys
try
    fig = plot_site_timeseries('TorreyPines', outRoot, ...
        'instrumentLat', 32.93056, 'instrumentLon', -117.26319, ...
        'savePath', fullfile(figDir, 'timeseries_TorreyPines.png'));
    close(fig);
catch ME
    fprintf('TP plot failed: %s\n', ME.message);
end

% --- Solana Beach (MOP654, 7m) ---
try
    fig = plot_site_timeseries('SolanaBeach', outRoot, ...
        'instrumentLat', 32.99064, 'instrumentLon', -117.27897, ...
        'savePath', fullfile(figDir, 'timeseries_SolanaBeach.png'));
    close(fig);
catch ME
    fprintf('SOL plot failed: %s\n', ME.message);
end

fprintf('\n=== Done. Figures saved to %s ===\n', figDir);
