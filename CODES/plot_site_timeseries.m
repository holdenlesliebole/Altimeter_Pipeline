function fig = plot_site_timeseries(siteName, L3dir, opts)
%PLOT_SITE_TIMESERIES  Multi-deployment bed level time series with survey overlay.
%
% Finds all L3 files for a site, chains burst-averaged bed levels across
% deployments (separated by depth), and overlays jetski survey elevations.
%
% Inputs:
%   siteName : 'SouthSIOPier', 'TorreyPines', or 'SolanaBeach'
%   L3dir    : directory containing site subdirectory with L3 .mat files
%
% Optional name-value:
%   instrumentLat   : latitude for survey lookup (required for survey overlay)
%   instrumentLon   : longitude for survey lookup
%   smFilePath      : path to SM files (default: '/Volumes/group/MOPS/')
%   mopNumber       : MOP number (auto-detected from lat/lon if not given)
%   savePath        : if provided, saves PNG to this path
%
% Output:
%   fig : figure handle

arguments
    siteName (1,1) string
    L3dir (1,1) string
    opts.instrumentLat (1,1) double = NaN
    opts.instrumentLon (1,1) double = NaN
    opts.smFilePath (1,1) string = "/Volumes/group/MOPS/"
    opts.mopNumber (1,1) double = NaN
    opts.savePath (1,1) string = ""
end

%% -- Find and load all L3 files for this site ----------------------------
siteDir = fullfile(L3dir, siteName);
if ~isfolder(siteDir)
    error('plot_site_timeseries: directory not found: %s', siteDir);
end

L3files = dir(fullfile(siteDir, '*_L3.mat'));
if isempty(L3files)
    error('plot_site_timeseries: no L3 files found in %s', siteDir);
end

fprintf('Found %d L3 files for %s\n', numel(L3files), siteName);

% Load all deployments, organize by depth
depData = struct();
for f = 1:numel(L3files)
    S = load(fullfile(L3files(f).folder, L3files(f).name));

    % Determine depth from deployment metadata
    depth_m = S.dep.Depth_m;
    depthKey = sprintf('d%dm', depth_m);

    % Get burst-averaged data (prefer echosounder, fall back to altimeter)
    if ~isempty(S.BA_echo) && isstruct(S.BA_echo) && S.BA_echo.nBursts > 0
        BA = S.BA_echo;
        src = 'echo';
    elseif ~isempty(S.BA_alt) && isstruct(S.BA_alt) && S.BA_alt.nBursts > 0
        BA = S.BA_alt;
        src = 'alt';
    else
        continue
    end

    if ~isfield(depData, depthKey)
        depData.(depthKey).depth_m = depth_m;
        depData.(depthKey).time = datetime.empty(0,1);
        depData.(depthKey).altitude_mm = [];
        depData.(depthKey).bedlevel_iqr_mm = [];
        depData.(depthKey).sources = {};
    end

    depData.(depthKey).time = [depData.(depthKey).time; BA.time];
    depData.(depthKey).altitude_mm = [depData.(depthKey).altitude_mm; BA.altitude_mm];
    depData.(depthKey).bedlevel_iqr_mm = [depData.(depthKey).bedlevel_iqr_mm; BA.bedlevel_iqr_mm];
    depData.(depthKey).sources{end+1} = src;
end

% Sort each depth by time and recompute bed level relative to first valid
depthKeys = fieldnames(depData);
for d = 1:numel(depthKeys)
    dd = depData.(depthKeys{d});
    [dd.time, order] = sort(dd.time);
    dd.altitude_mm = dd.altitude_mm(order);
    dd.bedlevel_iqr_mm = dd.bedlevel_iqr_mm(order);

    firstValid = find(~isnan(dd.altitude_mm), 1);
    if ~isempty(firstValid)
        dd.bedlevel_mm = -(dd.altitude_mm - dd.altitude_mm(firstValid));
    else
        dd.bedlevel_mm = nan(size(dd.altitude_mm));
    end
    depData.(depthKeys{d}) = dd;
end

%% -- Load survey data (if lat/lon provided) ------------------------------
hasSurvey = false;
surveyDates = [];
surveyElevs = [];

if ~isnan(opts.instrumentLat) && ~isnan(opts.instrumentLon)
    if isnan(opts.mopNumber)
        [mopNum, xShore] = LatLon2MopxshoreX(opts.instrumentLat, opts.instrumentLon);
        mopNum = round(mopNum);
    else
        mopNum = opts.mopNumber;
        [~, xShore] = LatLon2MopxshoreX(opts.instrumentLat, opts.instrumentLon);
    end

    smFile = fullfile(opts.smFilePath, sprintf('M%05dSM.mat', mopNum));
    if isfile(smFile)
        load(smFile, 'SM');
        % Find all surveys during the data period
        allTimes = [];
        for d = 1:numel(depthKeys)
            allTimes = [allTimes; depData.(depthKeys{d}).time]; %#ok
        end
        tStart = min(allTimes) - days(30);
        tEnd   = max(allTimes) + days(30);

        smDates = [SM.Datenum];
        for k = 1:numel(SM)
            if smDates(k) < datenum(tStart) || smDates(k) > datenum(tEnd)
                continue
            end
            X1D = SM(k).X1D; Z1D = SM(k).Z1Dmean;
            validX = ~isnan(Z1D);
            if sum(validX) < 3, continue; end
            elev = interp1(X1D(validX), Z1D(validX), xShore, 'linear', NaN);
            if isnan(elev) || elev > -3, continue; end
            surveyDates(end+1) = smDates(k); %#ok
            surveyElevs(end+1) = elev; %#ok
        end
        hasSurvey = numel(surveyDates) > 0;
        if hasSurvey
            fprintf('Found %d surveys at MOP %d, X_shore=%dm\n', ...
                numel(surveyDates), mopNum, round(xShore));
        end
    end
end

%% -- Plot ----------------------------------------------------------------
nDepths = numel(depthKeys);
colors = lines(max(nDepths, 3));

fig = figure('Color','w','Visible','off','Position',[50 50 1200 250+200*nDepths]);
tl = tiledlayout(nDepths, 1, 'TileSpacing','compact', 'Padding','compact');

mopStr = '';
if ~isnan(opts.instrumentLat) && hasSurvey
    mopStr = sprintf('  (MOP %d)', mopNum);
end
title(tl, sprintf('%s%s — Bed Level Time Series', siteName, mopStr), ...
    'Interpreter','none', 'FontSize', 14);

for d = 1:nDepths
    dd = depData.(depthKeys{d});
    nexttile

    % IQR shading
    valid = ~isnan(dd.bedlevel_mm);
    if any(valid) && any(~isnan(dd.bedlevel_iqr_mm(valid)))
        lo = dd.bedlevel_mm - dd.bedlevel_iqr_mm/2;
        hi = dd.bedlevel_mm + dd.bedlevel_iqr_mm/2;
        vIdx = find(valid);
        fill([dd.time(vIdx); flipud(dd.time(vIdx))], ...
             [lo(vIdx); flipud(hi(vIdx))], ...
             colors(d,:), 'FaceAlpha', 0.15, 'EdgeColor', 'none'); hold on
    end

    % Bed level line
    plot(dd.time, dd.bedlevel_mm, 'Color', colors(d,:), 'LineWidth', 1.0); hold on

    % Survey overlay (convert to relative bed level anchored to nearest burst)
    if hasSurvey
        survDT = datetime(surveyDates, 'ConvertFrom', 'datenum');
        % Align survey elevations to echosounder at first overlapping survey
        survBL = -(surveyElevs - surveyElevs(1)) * 1000;

        % Find nearest burst to first survey for alignment
        [~, matchIdx] = min(abs(dd.time - survDT(1)));
        if ~isnan(dd.bedlevel_mm(matchIdx))
            offset = dd.bedlevel_mm(matchIdx) - survBL(1);
            plot(survDT, survBL + offset, 'rs', 'MarkerSize', 7, ...
                'MarkerFaceColor', 'r', 'DisplayName', 'Survey');
        end
    end

    ylabel('Bed level (mm)');
    depthLabel = sprintf('%dm', dd.depth_m);
    if dd.depth_m == 0, depthLabel = 'unknown depth'; end
    text(0.02, 0.92, depthLabel, 'Units','normalized', ...
        'FontSize', 12, 'FontWeight', 'bold', ...
        'BackgroundColor', 'w', 'EdgeColor', colors(d,:));
    grid on; box off
end

xlabel(tl, 'Date');

%% -- Save ----------------------------------------------------------------
if opts.savePath ~= ""
    exportgraphics(fig, opts.savePath, 'Resolution', 200);
    fprintf('Saved: %s\n', opts.savePath);
end
end
