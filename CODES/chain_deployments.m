function C = chain_deployments(L3dir, siteName, opts)
%CHAIN_DEPLOYMENTS  Chain multi-deployment bed level into a continuous time series.
%
% Two anchoring methods:
%   "survey"  : Anchor each deployment to the nearest jetski GPS survey
%               elevation (NAVD88). Requires survey data on server.
%   "sequential" : Anchor deployment N+1 so its first value matches
%               deployment N's last value. Assumes same-day instrument
%               swaps with no significant bed change during the gap.
%
% Inputs:
%   L3dir    : directory containing site subdirectory with L3 .mat files
%   siteName : 'SouthSIOPier', 'TorreyPines', or 'SolanaBeach'
%
% Optional name-value:
%   method          : "survey" (default) or "sequential"
%   depths          : vector of depths to include (default: all)
%   instrumentLat   : latitude (required for survey method)
%   instrumentLon   : longitude (required for survey method)
%   smFilePath      : path to SM files (default: '/Volumes/group/MOPS/')
%   maxSurveyDelta_hr : max hours between survey and nearest burst (default: 48)
%
% Output struct C:
%   .time            (datetime)
%   .bedlevel_mm     (double) — relative to first deployment baseline
%   .elevation_m     (double) — absolute NAVD88 (survey method only; NaN for sequential)
%   .altitude_mm     (double) — burst-median altitude (unchanged)
%   .bedlevel_iqr_mm (double)
%   .dzdt_mm_hr      (double)
%   .pctValid        (double)
%   .deploymentID    (string) — which deployment each burst came from
%   .method          (string)
%   .nDeployments    (scalar)
%   .offsets_mm      (double) — offset applied to each deployment

arguments
    L3dir (1,1) string
    siteName (1,1) string
    opts.method (1,1) string = "survey"
    opts.depths (1,:) double = []
    opts.instrumentLat (1,1) double = NaN
    opts.instrumentLon (1,1) double = NaN
    opts.smFilePath (1,1) string = "/Volumes/group/MOPS/"
    opts.maxSurveyDelta_hr (1,1) double = 48
    opts.sensorElev_m (1,1) double = NaN  % known sensor elevation (NAVD88) for sequential+absolute
    opts.mopNumber (1,1) double = NaN     % override auto-detected MOP number
end

%% -- Load all L3 files for this site, organized by deployment time --------
siteDir = fullfile(L3dir, siteName);
L3files = dir(fullfile(siteDir, '*_L3.mat'));
if isempty(L3files)
    error('chain_deployments: no L3 files in %s', siteDir);
end

% Load each deployment's burst-averaged data
deps = struct();
nDep = 0;

for f = 1:numel(L3files)
    S = load(fullfile(L3files(f).folder, L3files(f).name));

    % Filter by depth
    if ~isempty(opts.depths) && ~any(S.dep.Depth_m == opts.depths)
        continue
    end

    % Get burst-averaged struct
    if ~isempty(S.BA_echo) && isstruct(S.BA_echo) && S.BA_echo.nBursts > 0
        BA = S.BA_echo;
    elseif ~isempty(S.BA_alt) && isstruct(S.BA_alt) && S.BA_alt.nBursts > 0
        BA = S.BA_alt;
    else
        continue
    end

    nDep = nDep + 1;
    deps(nDep).BA = BA;
    deps(nDep).depID = string(S.dep.DeploymentID);
    deps(nDep).startTime = min(BA.time);
end

if nDep == 0
    error('chain_deployments: no matching deployments found');
end

% Sort by start time
[~, order] = sort([deps.startTime]);
deps = deps(order);

fprintf('  Chaining %d deployments for %s\n', nDep, siteName);

%% -- Load survey data (for survey method) ---------------------------------
surveyDatenums = [];
surveyElevs = [];
xShore = NaN;

if opts.method == "survey" && ~isnan(opts.instrumentLat)
    [autoMop, xShore] = LatLon2MopxshoreX(opts.instrumentLat, opts.instrumentLon);
    if ~isnan(opts.mopNumber)
        mopNum = opts.mopNumber;
    else
        mopNum = round(autoMop);
    end
    smFile = fullfile(opts.smFilePath, sprintf('M%05dSM.mat', mopNum));

    if isfile(smFile)
        load(smFile, 'SM');
        for k = 1:numel(SM)
            X1D = SM(k).X1D; Z1D = SM(k).Z1Dmean;
            validX = ~isnan(Z1D);
            if sum(validX) < 3, continue; end
            elev = interp1(X1D(validX), Z1D(validX), xShore, 'linear', NaN);
            if isnan(elev) || elev > -3, continue; end
            surveyDatenums(end+1) = SM(k).Datenum; %#ok
            surveyElevs(end+1) = elev; %#ok
        end
        fprintf('  Loaded %d surveys at MOP %d, X_shore=%dm\n', ...
            numel(surveyDatenums), mopNum, round(xShore));
    else
        warning('chain_deployments: SM file not found, falling back to sequential: %s', smFile);
        opts.method = "sequential";
    end
end

%% -- Compute per-deployment offsets ---------------------------------------
offsets_mm = zeros(nDep, 1);  % offset to add to each deployment's bed level
hasAbsolute = false;

if opts.method == "survey" && ~isempty(surveyDatenums)
    % For each deployment, find the nearest survey and compute offset
    surveyDatetimes = datetime(surveyDatenums, 'ConvertFrom', 'datenum');

    for d = 1:nDep
        BA = deps(d).BA;
        validIdx = find(~isnan(BA.altitude_mm));
        if isempty(validIdx), continue; end

        % Find nearest survey to any burst in this deployment
        bestDt = inf;
        bestSurveyElev = NaN;
        bestBurstAlt = NaN;

        for sk = 1:numel(surveyDatetimes)
            [dt, bIdx] = min(abs(BA.time(validIdx) - surveyDatetimes(sk)));
            if hours(dt) < bestDt && hours(dt) < opts.maxSurveyDelta_hr
                bestDt = hours(dt);
                bestSurveyElev = surveyElevs(sk);
                bestBurstAlt = BA.altitude_mm(validIdx(bIdx));
            end
        end

        if ~isnan(bestSurveyElev)
            % offset converts altitude to NAVD88: elev = -(alt/1000) + offset_m
            % At survey time: bestSurveyElev = -(bestBurstAlt/1000) + offset_m
            offset_m = bestSurveyElev + bestBurstAlt / 1000;
            offsets_mm(d) = offset_m * 1000;
            fprintf('  [%d] %s: anchored to survey (dt=%.0fhr, offset=%+.0fmm)\n', ...
                d, deps(d).depID, bestDt, offsets_mm(d));
            hasAbsolute = true;
        else
            fprintf('  [%d] %s: no survey within %dhr\n', ...
                d, deps(d).depID, opts.maxSurveyDelta_hr);
        end
    end

    % For deployments without a direct survey match, interpolate offset
    % from neighboring deployments that do have matches
    matched = offsets_mm ~= 0 | (1:nDep)' == 1;
    if sum(matched) >= 2 && sum(~matched) > 0
        midTimes = arrayfun(@(d) mean(datenum([d.BA.time(1), d.BA.time(end)])), deps)';
        offsets_mm(~matched) = interp1(midTimes(matched), offsets_mm(matched), ...
            midTimes(~matched), 'linear', 'extrap');
        fprintf('  Interpolated offsets for %d unmatched deployments\n', sum(~matched));
    end

elseif opts.method == "sequential"
    % Chain sequentially: deployment N+1 starts where N ended
    for d = 2:nDep
        prevBA = deps(d-1).BA;
        currBA = deps(d).BA;

        % Last valid altitude of previous deployment
        prevValid = find(~isnan(prevBA.altitude_mm), 1, 'last');
        currValid = find(~isnan(currBA.altitude_mm), 1, 'first');

        if ~isempty(prevValid) && ~isempty(currValid)
            % Offset so that currBA starts at the same bed level where prevBA ended
            prevEndAlt = prevBA.altitude_mm(prevValid);
            currStartAlt = currBA.altitude_mm(currValid);
            % Accumulate offsets
            offsets_mm(d) = offsets_mm(d-1) + (currStartAlt - prevEndAlt);
        else
            offsets_mm(d) = offsets_mm(d-1);
        end
        fprintf('  [%d] %s: sequential offset %+.0f mm\n', d, deps(d).depID, offsets_mm(d));
    end
end

%% -- Build chained output -------------------------------------------------
allTime = datetime.empty(0,1);
allBL = [];
allElev = [];
allAlt = [];
allIQR = [];
allDzdt = [];
allPctVal = [];
allDepID = string.empty(0,1);

for d = 1:nDep
    BA = deps(d).BA;
    n = numel(BA.time);

    % Bed level with offset applied
    baseline = BA.altitude_mm - offsets_mm(d);
    fv = find(~isnan(baseline), 1);
    if d == 1 && ~isempty(fv)
        globalBaseline = baseline(fv);
    end

    bl = -(baseline - globalBaseline);

    % Absolute elevation
    if hasAbsolute
        % Survey-anchored: elev = -(alt/1000) + offset/1000
        elev = -(BA.altitude_mm / 1000) + offsets_mm(d) / 1000;
    elseif ~isnan(opts.sensorElev_m)
        % Known sensor elevation: bed_elev = sensor_elev - alt/1000
        elev = opts.sensorElev_m - BA.altitude_mm / 1000;
    else
        elev = nan(n, 1);
    end

    allTime = [allTime; BA.time]; %#ok
    allBL = [allBL; bl]; %#ok
    allElev = [allElev; elev]; %#ok
    allAlt = [allAlt; BA.altitude_mm]; %#ok
    allIQR = [allIQR; BA.bedlevel_iqr_mm]; %#ok
    allDzdt = [allDzdt; BA.dzdt_mm_hr]; %#ok
    allPctVal = [allPctVal; BA.pctValid]; %#ok
    allDepID = [allDepID; repmat(deps(d).depID, n, 1)]; %#ok
end

C.time = allTime;
C.bedlevel_mm = allBL;
C.elevation_m = allElev;
C.altitude_mm = allAlt;
C.bedlevel_iqr_mm = allIQR;
C.dzdt_mm_hr = allDzdt;
C.pctValid = allPctVal;
C.deploymentID = allDepID;
C.method = opts.method;
C.nDeployments = nDep;
C.offsets_mm = offsets_mm;

fprintf('  Chained: %d total bursts, method=%s\n', numel(allTime), opts.method);
end
