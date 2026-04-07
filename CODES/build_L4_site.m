function L4 = build_L4_site(L3root, pvuRoot, siteName, opts)
%BUILD_L4_SITE  Build full-site L4 merged product across all deployments.
%
% Chains all altimeter L3 files for a site, loads all matching PUV L2/L3
% files, and merges them into a single L4 struct spanning the full record.
%
% Inputs:
%   L3root   : directory containing altimeter L3 files (e.g. outputs/all)
%   pvuRoot  : PUV Pipeline outputs root (e.g. PUV_Pipeline/outputs)
%   siteName : 'SouthSIOPier', 'TorreyPines', or 'SolanaBeach'
%
% Optional name-value:
%   depths           : vector of depths to include (default: all)
%   pvuDeployments   : cell array of PUV deployment names to search
%   pvuLabel         : PUV instrument label (e.g. 'SIO_6m', 'MOP586_5m')
%   matchTolerance_min : max time offset (default 5)
%   anchorMethod     : "survey" or "sequential" for chaining (default "sequential")
%   instrumentLat    : for survey anchoring
%   instrumentLon    : for survey anchoring
%   sensorElev_m     : known sensor elevation for sequential+absolute
%   savePath         : save L4 .mat to this path

arguments
    L3root (1,1) string
    pvuRoot (1,1) string
    siteName (1,1) string
    opts.depths (1,:) double = []
    opts.pvuDeployments cell = {}
    opts.pvuLabel (1,1) string = ""
    opts.matchTolerance_min (1,1) double = 5
    opts.anchorMethod (1,1) string = "sequential"
    opts.instrumentLat (1,1) double = NaN
    opts.instrumentLon (1,1) double = NaN
    opts.sensorElev_m (1,1) double = NaN
    opts.mopNumber (1,1) double = NaN    % override auto-detected MOP for surveys
    opts.mopStation (1,1) string = ""    % CDIP station code for MOP wave data (e.g. "D0511")
    opts.savePath (1,1) string = ""
end

fprintf('\n=== Building L4 for %s ===\n', siteName);

%% -- Chain altimeter deployments ------------------------------------------
chainOpts = {'method', opts.anchorMethod};
if ~isempty(opts.depths)
    chainOpts = [chainOpts, 'depths', opts.depths];
end
if ~isnan(opts.instrumentLat)
    chainOpts = [chainOpts, 'instrumentLat', opts.instrumentLat, ...
                 'instrumentLon', opts.instrumentLon];
end
if ~isnan(opts.sensorElev_m)
    chainOpts = [chainOpts, 'sensorElev_m', opts.sensorElev_m];
end
if ~isnan(opts.mopNumber)
    chainOpts = [chainOpts, 'mopNumber', opts.mopNumber];
end

C = chain_deployments(L3root, siteName, chainOpts{:});
fprintf('  Altimeter: %d bursts, %s to %s\n', numel(C.time), ...
    string(C.time(1)), string(C.time(end)));

%% -- Load all PUV L2/L3 files --------------------------------------------
% Concatenate all PUV segments into one big time vector + field arrays
allPvuTime = datetime.empty(0,1);
allL2 = [];
allL3 = [];

if isempty(opts.pvuDeployments)
    % Auto-discover from pvuRoot/L2/
    d = dir(fullfile(pvuRoot, 'L2'));
    opts.pvuDeployments = {d([d.isdir] & ~startsWith({d.name}, '.')).name};
end

nPvuLoaded = 0;
for p = 1:numel(opts.pvuDeployments)
    depName = opts.pvuDeployments{p};

    % Find L2 file
    if opts.pvuLabel ~= ""
        l2File = fullfile(pvuRoot, 'L2', depName, opts.pvuLabel + "_L2.mat");
        l3File = fullfile(pvuRoot, 'L3', depName, opts.pvuLabel + "_L3.mat");
    else
        % Try to find any L2 file in this deployment
        l2Files = dir(fullfile(pvuRoot, 'L2', depName, '*_L2.mat'));
        if isempty(l2Files), continue; end
        l2File = fullfile(l2Files(1).folder, l2Files(1).name);
        l3Stem = strrep(l2Files(1).name, '_L2.mat', '_L3.mat');
        l3File = fullfile(pvuRoot, 'L3', depName, l3Stem);
    end

    if ~isfile(l2File), continue; end

    S2 = load(l2File); L2 = S2.L2;

    if isfile(l3File)
        S3 = load(l3File); L3 = S3.L3;
    else
        L3 = [];
    end

    % Check temporal overlap with altimeter record
    pvuStart = L2.time(1); pvuEnd = L2.time(end);
    altStart = C.time(1); altEnd = C.time(end);

    if pvuEnd < altStart || pvuStart > altEnd
        continue  % no overlap
    end

    fprintf('  PUV %s: %d segments, %s to %s\n', depName, numel(L2.time), ...
        string(pvuStart), string(pvuEnd));

    % Store for matching
    nPvuLoaded = nPvuLoaded + 1;
    pvuData(nPvuLoaded).L2 = L2; %#ok
    pvuData(nPvuLoaded).L3 = L3; %#ok
    pvuData(nPvuLoaded).depName = depName; %#ok
end

if nPvuLoaded == 0
    warning('build_L4_site: no PUV data found with temporal overlap');
    L4 = [];
    return
end

%% -- Match each altimeter burst to nearest PUV segment --------------------
nBursts = numel(C.time);
tol = minutes(opts.matchTolerance_min);

matchPvuIdx  = nan(nBursts, 1);  % which PUV deployment
matchSegIdx  = nan(nBursts, 1);  % which segment within that deployment
matchDt      = nan(nBursts, 1);  % time offset in minutes

for k = 1:nBursts
    bestDt = inf;
    for p = 1:nPvuLoaded
        [dt, idx] = min(abs(pvuData(p).L2.time - C.time(k)));
        dtMin = minutes(dt);
        if dtMin < bestDt && dt <= tol
            bestDt = dtMin;
            matchPvuIdx(k) = p;
            matchSegIdx(k) = idx;
            matchDt(k) = dtMin;
        end
    end
end

nMatched = sum(~isnan(matchPvuIdx));
fprintf('  Matched: %d/%d bursts (%.0f%%), median dt=%.1f min\n', ...
    nMatched, nBursts, 100*nMatched/nBursts, median(matchDt(~isnan(matchDt))));

%% -- Build L4 struct ------------------------------------------------------
% Bed response (from chained altimeter)
L4.time            = C.time;
L4.bedlevel_mm     = C.bedlevel_mm;
L4.bedlevel_iqr_mm = C.bedlevel_iqr_mm;
L4.dzdt_mm_hr      = C.dzdt_mm_hr;
L4.altitude_mm     = C.altitude_mm;
L4.elevation_m     = C.elevation_m;
L4.pctValid        = C.pctValid;
L4.deploymentID    = C.deploymentID;

% Helper to extract a scalar field from the matched PUV L2
    function vals = getL2(fieldName)
        vals = nan(nBursts, 1);
        for i = 1:nBursts
            if ~isnan(matchPvuIdx(i))
                vals(i) = pvuData(matchPvuIdx(i)).L2.(fieldName)(matchSegIdx(i));
            end
        end
    end

    function vals = getL2sub(structName, fieldName)
        vals = nan(nBursts, 1);
        for i = 1:nBursts
            if ~isnan(matchPvuIdx(i))
                vals(i) = pvuData(matchPvuIdx(i)).L2.(structName).(fieldName)(matchSegIdx(i));
            end
        end
    end

    function vals = getL3(fieldName)
        vals = nan(nBursts, 1);
        for i = 1:nBursts
            if ~isnan(matchPvuIdx(i)) && ~isempty(pvuData(matchPvuIdx(i)).L3)
                vals(i) = pvuData(matchPvuIdx(i)).L3.(fieldName)(matchSegIdx(i));
            end
        end
    end

    function vals = getL3sub(structName, fieldName)
        vals = nan(nBursts, 1);
        for i = 1:nBursts
            if ~isnan(matchPvuIdx(i)) && ~isempty(pvuData(matchPvuIdx(i)).L3)
                try
                    vals(i) = pvuData(matchPvuIdx(i)).L3.(structName).(fieldName)(matchSegIdx(i));
                catch
                end
            end
        end
    end

% Wave forcing — bulk
L4.Hs       = getL2('Hs');
L4.Hs_SS    = getL2('Hs_SS');
L4.Tp       = getL2('Tp');
L4.Ef       = getL2('Ef');
L4.depth    = getL2('depth');
L4.meanDir  = getL2('meanDir');

% Wave forcing — bed level
L4.Ub       = getL2('Ub');
L4.tau_b    = getL2('tau_b');
L4.Aw       = getL2('Aw');

% L3 derived
L4.Fb       = getL3('Fb');
L4.Fb_cum   = getL3('Fb_cum');
L4.shields  = getL3('shields');

L4.mobilized = false(nBursts, 1);
for i = 1:nBursts
    if ~isnan(matchPvuIdx(i)) && ~isempty(pvuData(matchPvuIdx(i)).L3)
        try
            L4.mobilized(i) = pvuData(matchPvuIdx(i)).L3.mobilized(matchSegIdx(i));
        catch
        end
    end
end

% Velocity moments
L4.skewness  = getL2sub('vmom', 'skewness');
L4.asymmetry = getL2sub('vmom', 'asymmetry');
L4.u_abs3    = getL2sub('vmom', 'u_abs3');
L4.u_uabs2   = getL2sub('vmom', 'u_uabs2');

% Currents
L4.uMean = getL2('uMean');
L4.vMean = getL2('vMean');
L4.TKE   = getL2sub('reynolds', 'TKE');

% L3 subtidal + tidal
L4.subtidal_u  = getL3sub('subtidal', 'u');
L4.tidal_depth = getL3sub('tidal', 'depth_pred');

% Swell/sea fractions
L4.frac_swell = getL3('frac_swell');
L4.frac_sea   = getL3('frac_sea');
L4.Ef_swell   = L4.Ef .* L4.frac_swell;
L4.Ef_sea     = L4.Ef .* L4.frac_sea;

% Storm flag
L4.storm_flag = false(nBursts, 1);
for p = 1:nPvuLoaded
    if isempty(pvuData(p).L3), continue; end
    try
        if ~isempty(pvuData(p).L3.events.start)
            for e = 1:numel(pvuData(p).L3.events.start)
                inStorm = C.time >= pvuData(p).L3.events.start(e) & ...
                          C.time <= pvuData(p).L3.events.end_time(e);
                L4.storm_flag(inStorm) = true;
            end
        end
    catch
    end
end

% Quality
L4.puv_match_min = matchDt;
L4.puv_valid     = ~isnan(matchPvuIdx);

iqr99 = prctile(C.bedlevel_iqr_mm(~isnan(C.bedlevel_iqr_mm)), 99);
if iqr99 > 0
    L4.alt_quality = (C.pctValid / 100) .* max(0, 1 - C.bedlevel_iqr_mm / iqr99);
else
    L4.alt_quality = C.pctValid / 100;
end

% PUV deployment name per burst
L4.puv_deployment = strings(nBursts, 1);
for i = 1:nBursts
    if ~isnan(matchPvuIdx(i))
        L4.puv_deployment(i) = pvuData(matchPvuIdx(i)).depName;
    end
end

% Metadata
L4.site    = siteName;
L4.nBursts = nBursts;
L4.nMatched = nMatched;
L4.nPvuDeployments = nPvuLoaded;

%% -- MOP wave data (continuous, fills PUV gaps) ---------------------------
L4.mop_Hs = nan(nBursts, 1);
L4.mop_Tp = nan(nBursts, 1);

if opts.mopStation ~= "" && exist('read_MOPline2', 'file')
    try
        tStart = C.time(1) - days(1);
        tEnd   = C.time(end) + days(1);
        MOP = read_MOPline2(char(opts.mopStation), datenum(tStart), datenum(tEnd));
        if ~isempty(MOP) && isfield(MOP, 'time')
            mopTime = datetime(MOP.time, 'ConvertFrom', 'datenum');
            mopHs = double(MOP.Hs);
            mopTp = 1 ./ double(MOP.fp);
            % Interpolate hourly MOP to burst timestamps
            L4.mop_Hs = interp1(mopTime, mopHs, C.time, 'linear', NaN);
            L4.mop_Tp = interp1(mopTime, mopTp, C.time, 'linear', NaN);
            nMop = sum(~isnan(L4.mop_Hs));
            fprintf('  MOP %s: %d hourly records, %d/%d bursts filled (%.0f%%)\n', ...
                opts.mopStation, numel(mopTime), nMop, nBursts, 100*nMop/nBursts);
        end
    catch ME
        fprintf('  MOP loading failed: %s\n', ME.message);
    end
end

% Use MOP Hs where PUV is missing (gap-fill)
L4.Hs_combined = L4.Hs;
L4.Hs_source   = strings(nBursts, 1);
L4.Hs_source(L4.puv_valid) = "PUV";
gapFilled = isnan(L4.Hs_combined) & ~isnan(L4.mop_Hs);
L4.Hs_combined(gapFilled) = L4.mop_Hs(gapFilled);
L4.Hs_source(gapFilled) = "MOP";
fprintf('  Hs coverage: %d PUV + %d MOP gap-fill = %d/%d (%.0f%%)\n', ...
    sum(L4.puv_valid), sum(gapFilled), sum(~isnan(L4.Hs_combined)), nBursts, ...
    100*sum(~isnan(L4.Hs_combined))/nBursts);

% Summary
nStorm = sum(L4.storm_flag & L4.puv_valid);
fprintf('  L4 complete: %d bursts, %d with PUV (%.0f%%), %d during storms\n', ...
    nBursts, nMatched, 100*nMatched/nBursts, nStorm);

%% -- Save -----------------------------------------------------------------
if opts.savePath ~= ""
    save(opts.savePath, 'L4', '-v7.3');
    fprintf('  Saved: %s\n', opts.savePath);
end
end
