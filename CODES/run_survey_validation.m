% RUN_SURVEY_VALIDATION  Validate altimeter/echosounder bed level against beach surveys.
%
% Chains ALL processed L3 files for each site/depth into a continuous
% burst-averaged time series, then validates against jetski GPS surveys.
%
% Requires:
%   - Processed L3 .mat files in outputs/all/ (run run_all_and_plot.m first)
%   - CPG toolbox on path (for LatLon2MopxshoreX)
%   - SM files on server (/Volumes/group/MOPS/)

clear; close all;

%% ======================== SETUP ========================
codeDir   = fileparts(mfilename('fullpath'));
configDir = fullfile(codeDir, '..', 'config');
L3root    = fullfile(codeDir, '..', 'outputs', 'all');
figDir    = fullfile(codeDir, '..', 'outputs', 'figures');

addpath(codeDir);
addpath(configDir);
addpath('/Users/holden/Documents/Scripps/Research/toolbox');
addpath('/Users/holden/Documents/Scripps/Research/Beach_Change_Observation/mop');

if ~exist(figDir, 'dir'), mkdir(figDir); end

%% ======================== DEFINE VALIDATION SITES ========================
% Each site: name, L3 subdirectory, lat/lon, which depths to chain, which BA field
sites = struct();

sites(1).name     = 'SolanaBeach MOP654 7m';
sites(1).siteDir  = 'SolanaBeach';
sites(1).lat      = 32.99064;
sites(1).lon      = -117.27897;
sites(1).depths   = [0, 7];  % include unknown-depth early deployment

sites(2).name     = 'TorreyPines MOP586 5m';
sites(2).siteDir  = 'TorreyPines';
sites(2).lat      = 32.93056;
sites(2).lon      = -117.26319;
sites(2).depths   = 5;

sites(3).name     = 'TorreyPines MOP586 10m';
sites(3).siteDir  = 'TorreyPines';
sites(3).lat      = 32.93035;
sites(3).lon      = -117.26572;
sites(3).depths   = 10;

%% ======================== CHAIN AND VALIDATE =============================
results = struct();

for s = 1:numel(sites)
    si = sites(s);
    fprintf('\n======== %s ========\n', si.name);

    % Find all L3 files for this site
    siteL3dir = fullfile(L3root, si.siteDir);
    if ~isfolder(siteL3dir)
        fprintf('  No L3 directory: %s\n', siteL3dir);
        continue
    end
    L3files = dir(fullfile(siteL3dir, '*_L3.mat'));

    % Chain burst-averaged data from matching deployments
    allBA = struct('time', datetime.empty(0,1), 'altitude_mm', [], ...
        'bedlevel_iqr_mm', [], 'pctValid', [], 'dzdt_mm_hr', []);

    for f = 1:numel(L3files)
        S = load(fullfile(L3files(f).folder, L3files(f).name));

        % Check depth matches
        if ~any(S.dep.Depth_m == si.depths), continue; end

        % Get burst-averaged struct
        if ~isempty(S.BA_echo) && isstruct(S.BA_echo) && S.BA_echo.nBursts > 0
            BA = S.BA_echo;
        elseif ~isempty(S.BA_alt) && isstruct(S.BA_alt) && S.BA_alt.nBursts > 0
            BA = S.BA_alt;
        else
            continue
        end

        allBA.time = [allBA.time; BA.time];
        allBA.altitude_mm = [allBA.altitude_mm; BA.altitude_mm];
        allBA.bedlevel_iqr_mm = [allBA.bedlevel_iqr_mm; BA.bedlevel_iqr_mm];
        allBA.pctValid = [allBA.pctValid; BA.pctValid];
        allBA.dzdt_mm_hr = [allBA.dzdt_mm_hr; BA.dzdt_mm_hr];
    end

    if isempty(allBA.time)
        fprintf('  No matching L3 data found.\n');
        continue
    end

    % Sort and re-baseline
    [allBA.time, order] = sort(allBA.time);
    allBA.altitude_mm = allBA.altitude_mm(order);
    allBA.bedlevel_iqr_mm = allBA.bedlevel_iqr_mm(order);
    allBA.pctValid = allBA.pctValid(order);
    allBA.dzdt_mm_hr = allBA.dzdt_mm_hr(order);
    allBA.nBursts = numel(allBA.time);

    fv = find(~isnan(allBA.altitude_mm), 1);
    if ~isempty(fv)
        allBA.bedlevel_mm = -(allBA.altitude_mm - allBA.altitude_mm(fv));
    else
        allBA.bedlevel_mm = nan(size(allBA.altitude_mm));
    end

    fprintf('  Chained: %d bursts, %s to %s\n', allBA.nBursts, ...
        string(allBA.time(1)), string(allBA.time(end)));

    % Validate
    V = validate_against_surveys(allBA, ...
        'instrumentLat', si.lat, 'instrumentLon', si.lon, ...
        'maxTimeDelta_hr', 24);

    results(s).name = si.name;
    results(s).V = V;

    if V.nPairs < 1
        fprintf('  Insufficient survey pairs for validation.\n');
        continue
    end

    % Plot
    fig = figure('Color','w','Visible','off','Position',[100 100 1100 550]);
    tiledlayout(2,1,'TileSpacing','compact','Padding','compact');

    nexttile
    plot(allBA.time, allBA.bedlevel_mm, 'Color',[0.18 0.45 0.75], 'LineWidth',0.8); hold on
    if V.nSurveys > 0
        survBL = -(V.surveyElev_m - V.surveyElev_m(1)) * 1000;
        [~, mIdx] = min(abs(allBA.time - V.surveyDates(1)));
        if ~isnan(allBA.bedlevel_mm(mIdx))
            offset = allBA.bedlevel_mm(mIdx) - survBL(1);
            plot(V.surveyDates, survBL + offset, 'rs', 'MarkerSize',10, 'MarkerFaceColor','r');
        end
    end
    ylabel('Bed level change (mm)');
    legend('Instrument','Survey','Location','best');
    title(sprintf('%s — Survey Validation', si.name), 'Interpreter','none');
    grid on; box off

    nexttile
    vp = ~isnan(V.deltaZ_survey_mm) & ~isnan(V.deltaZ_alt_mm);
    if any(vp)
        scatter(V.deltaZ_survey_mm(vp), V.deltaZ_alt_mm(vp), 60, [0.18 0.45 0.75], 'filled'); hold on
        lims = [min([V.deltaZ_survey_mm(vp);V.deltaZ_alt_mm(vp)])-20, ...
                max([V.deltaZ_survey_mm(vp);V.deltaZ_alt_mm(vp)])+20];
        plot(lims, lims, 'k--');
        xlim(lims); ylim(lims);
    end
    xlabel('\Deltaz survey (mm)'); ylabel('\Deltaz instrument (mm)');
    title(sprintf('R^2=%.3f, RMSE=%.1f mm, bias=%.1f mm, N=%d', V.r2, V.rmse_mm, V.bias_mm, V.nPairs));
    axis square; grid on

    fname = sprintf('survey_validation_%s.png', regexprep(si.name, '[^a-zA-Z0-9]', '_'));
    exportgraphics(fig, fullfile(figDir, fname), 'Resolution', 150);
    close(fig);
    fprintf('  Saved: %s\n', fname);
end

%% ======================== SUMMARY =============================
fprintf('\n======== SURVEY VALIDATION SUMMARY ========\n');
fprintf('%-30s %6s %6s %8s %8s %8s\n', 'Site', 'N_surv', 'N_pair', 'RMSE_mm', 'bias_mm', 'R2');
for s = 1:numel(results)
    if ~isfield(results(s), 'V') || isempty(results(s).V), continue; end
    V = results(s).V;
    fprintf('%-30s %6d %6d %8.1f %8.1f %8.3f\n', ...
        results(s).name, V.nSurveys, V.nPairs, V.rmse_mm, V.bias_mm, V.r2);
end
