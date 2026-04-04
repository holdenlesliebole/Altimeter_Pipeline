% RUN_SURVEY_VALIDATION  Validate altimeter/echosounder bed level against beach surveys.
%
% Loads L3 burst-averaged data from processed deployments and compares
% bed level changes against CPG beach survey (SM) profile data at the
% instrument location.
%
% Requires:
%   - Processed L3 .mat files (run ALT_L1_driver first)
%   - CPG toolbox on path (for LatLon2MopxshoreX)
%   - SM files on server (/Volumes/group/MOPS/)

clear; close all;

%% ======================== SETUP ========================
codeDir   = fileparts(mfilename('fullpath'));
configDir = fullfile(codeDir, '..', 'config');
outDir    = fullfile(codeDir, '..', 'outputs', 'validation');

addpath(codeDir);
addpath(configDir);
addpath('/Users/holden/Documents/Scripps/Research/toolbox');
addpath('/Users/holden/Documents/Scripps/Research/Beach_Change_Observation/mop');

%% ======================== DEFINE VALIDATION TARGETS ========================
% Each entry: L3 file path, instrument lat/lon, label
targets = struct();

% SOL25 echosounder (best coverage: ~19 surveys)
targets(1).name     = 'SOL25 MOP654 7m echo';
targets(1).L3file   = fullfile(outDir, 'SolanaBeach', 'MOP654_7m_20250304_L3.mat');
targets(1).lat      = 32.99064;
targets(1).lon      = -117.27897;
targets(1).baField  = 'BA_echo';

% TP25 5m echosounder (already processed)
targets(2).name     = 'TP25 MOP586 5m echo';
targets(2).L3file   = fullfile(codeDir, '..', 'outputs', 'TP25', 'TorreyPines', ...
                       'MOP586_5m_20250325_L3.mat');
targets(2).lat      = 32.93056;
targets(2).lon      = -117.26319;
targets(2).baField  = 'BA_echo';

% TP25 10m altimeter
targets(3).name     = 'TP25 MOP586 10m alt';
targets(3).L3file   = fullfile(outDir, 'TorreyPines', 'MOP586_10m_20250305_L3.mat');
targets(3).lat      = 32.93035;
targets(3).lon      = -117.26572;
targets(3).baField  = 'BA_alt';

%% ======================== RUN VALIDATION ========================
results = struct();

for t = 1:numel(targets)
    fprintf('\n======== %s ========\n', targets(t).name);

    if ~isfile(targets(t).L3file)
        fprintf('  L3 file not found: %s\n', targets(t).L3file);
        fprintf('  Run ALT_L1_driver for this deployment first.\n');
        continue
    end

    S = load(targets(t).L3file);

    % Get the burst-averaged struct
    BA = S.(targets(t).baField);
    if isempty(BA) || BA.nBursts == 0
        fprintf('  No burst data in L3 file.\n');
        continue
    end

    V = validate_against_surveys(BA, ...
        'instrumentLat', targets(t).lat, ...
        'instrumentLon', targets(t).lon);

    results(t).name = targets(t).name;
    results(t).V    = V;

    if V.nPairs < 1
        fprintf('  Insufficient survey overlap for validation.\n');
        continue
    end

    %% -- Plot 1: Time series with survey checkpoints --
    fig = figure('Color','w','Visible','off','Position',[100 100 1000 500]);
    tiledlayout(2,1,'TileSpacing','compact','Padding','compact');

    nexttile
    plot(BA.time, BA.bedlevel_mm, 'Color',[0.18 0.45 0.75], 'LineWidth',0.8); hold on
    % Overlay survey elevations (convert to relative bed level for comparison)
    if V.nSurveys > 0
        survBL = -(V.surveyElev_m - V.surveyElev_m(1)) * 1000;  % relative, mm
        altBLAtSurvey = V.altBedLevel_mm - V.altBedLevel_mm(1);  % re-baseline to first survey
        % Shift altimeter to match first survey point
        offset = survBL(1) - altBLAtSurvey(1);
        plot(BA.time, BA.bedlevel_mm + offset, 'Color',[0.18 0.45 0.75 0.3], ...
            'LineWidth',0.5, 'HandleVisibility','off');
        plot(V.surveyDates, survBL, 'ro', 'MarkerSize',8, 'MarkerFaceColor','r', ...
            'DisplayName','Survey');
    end
    ylabel('Bed level change (mm)');
    legend('Altimeter/Echo','Survey','Location','best');
    title(targets(t).name, 'Interpreter','none');
    grid on; box off

    nexttile
    validPairs = ~isnan(V.deltaZ_survey_mm) & ~isnan(V.deltaZ_alt_mm);
    if any(validPairs)
        scatter(V.deltaZ_survey_mm(validPairs), V.deltaZ_alt_mm(validPairs), ...
            50, [0.18 0.45 0.75], 'filled'); hold on
        lims = [min([V.deltaZ_survey_mm(validPairs); V.deltaZ_alt_mm(validPairs)]) - 10, ...
                max([V.deltaZ_survey_mm(validPairs); V.deltaZ_alt_mm(validPairs)]) + 10];
        plot(lims, lims, 'k--', 'HandleVisibility','off');
        xlim(lims); ylim(lims);
        xlabel('\Deltaz survey (mm)');
        ylabel('\Deltaz altimeter (mm)');
        title(sprintf('R^2=%.3f, RMSE=%.1f mm, bias=%.1f mm, N=%d', ...
            V.r2, V.rmse_mm, V.bias_mm, V.nPairs));
        axis square; grid on; box off
    else
        text(0.5, 0.5, 'Insufficient paired data', 'Units','normalized', ...
            'HorizontalAlignment','center');
    end

    pngFile = fullfile(outDir, sprintf('survey_validation_%s.png', ...
        regexprep(targets(t).name, '[^a-zA-Z0-9]', '_')));
    exportgraphics(fig, pngFile, 'Resolution', 150);
    close(fig);
    fprintf('  Saved: %s\n', pngFile);
end

%% ======================== SUMMARY TABLE ========================
fprintf('\n======== SURVEY VALIDATION SUMMARY ========\n');
fprintf('%-30s %6s %6s %8s %8s %8s\n', 'Deployment', 'N_surv', 'N_pair', ...
    'RMSE_mm', 'bias_mm', 'R2');
for t = 1:numel(results)
    if ~isfield(results(t), 'V') || isempty(results(t).V), continue; end
    V = results(t).V;
    fprintf('%-30s %6d %6d %8.1f %8.1f %8.3f\n', ...
        results(t).name, V.nSurveys, V.nPairs, V.rmse_mm, V.bias_mm, V.r2);
end
