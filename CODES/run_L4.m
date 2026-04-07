% RUN_L4  Build L4 merged products for all sites and generate diagnostic plots.
%
% Requires:
%   - Altimeter L3 files in outputs/all/ (from run_all_and_plot.m)
%   - PUV L2/L3 files in PUV_Pipeline/outputs/
%   - CPG toolbox on path (for survey-anchored sites)

clear; close all;

%% ======================== SETUP ========================
codeDir = fileparts(mfilename('fullpath'));
addpath(codeDir);
addpath(fullfile(codeDir, '..', 'config'));
addpath('/Users/holden/Documents/Scripps/Research/toolbox');
addpath('/Users/holden/Documents/Scripps/Research/Beach_Change_Observation/mop');

L3root = fullfile(codeDir, '..', 'outputs', 'all');
pvuRoot = '/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs';
outDir = fullfile(codeDir, '..', 'outputs', 'L4');
figDir = fullfile(codeDir, '..', 'outputs', 'figures');

if ~exist(outDir, 'dir'), mkdir(outDir); end
if ~exist(figDir, 'dir'), mkdir(figDir); end

%% ======================== SIO PIER (6m) ========================
fprintf('\n========================================\n');
fprintf('SIO Pier MOP511 6m\n');
fprintf('========================================\n');

L4_SIO = build_L4_site(L3root, pvuRoot, 'SouthSIOPier', ...
    'depths', 6, ...
    'pvuLabel', "SIO_6m", ...
    'anchorMethod', 'survey', ...
    'instrumentLat', 32.8665, 'instrumentLon', -117.2570, ...
    'mopNumber', 511, ...
    'sensorElev_m', -4.96, ...
    'mopStation', "D0511", ...
    'savePath', fullfile(outDir, 'L4_SIO_6m.mat'));

%% ======================== TORREY PINES (multi-depth) ========================
tp_depths = struct();
tp_depths(1).depth = 5;  tp_depths(1).label = "MOP586_5m";
tp_depths(1).lat = 32.93056; tp_depths(1).lon = -117.26319;
tp_depths(2).depth = 10; tp_depths(2).label = "MOP586_10m";
tp_depths(2).lat = 32.93035; tp_depths(2).lon = -117.26572;
tp_depths(3).depth = 15; tp_depths(3).label = "MOP586_15m";
tp_depths(3).lat = 32.93005; tp_depths(3).lon = -117.26950;

for d = 1:numel(tp_depths)
    fprintf('\n========================================\n');
    fprintf('Torrey Pines MOP586 %dm\n', tp_depths(d).depth);
    fprintf('========================================\n');

    try
        L4 = build_L4_site(L3root, pvuRoot, 'TorreyPines', ...
            'depths', tp_depths(d).depth, ...
            'pvuLabel', tp_depths(d).label, ...
            'anchorMethod', 'survey', ...
            'instrumentLat', tp_depths(d).lat, ...
            'instrumentLon', tp_depths(d).lon, ...
            'mopStation', "D0586", ...
            'savePath', fullfile(outDir, sprintf('L4_TP_%dm.mat', tp_depths(d).depth)));

        % Store for plotting
        eval(sprintf('L4_TP%d = L4;', tp_depths(d).depth));
    catch ME
        fprintf('  FAILED: %s\n', ME.message);
    end
end

%% ======================== DIAGNOSTIC PLOTS ========================
fprintf('\n=== Generating L4 diagnostic plots ===\n');

% Helper: plot dz/dt vs tau_b with density coloring
plotL4 = @(L4, titleStr, fname) local_plot_L4(L4, titleStr, fname, figDir);

if exist('L4_SIO', 'var') && L4_SIO.nMatched > 0
    plotL4(L4_SIO, 'SIO Pier 6m', 'L4_SIO_6m');
end
if exist('L4_TP5', 'var') && L4_TP5.nMatched > 0
    plotL4(L4_TP5, 'Torrey Pines 5m', 'L4_TP_5m');
end
if exist('L4_TP10', 'var') && L4_TP10.nMatched > 0
    plotL4(L4_TP10, 'Torrey Pines 10m', 'L4_TP_10m');
end
if exist('L4_TP15', 'var') && L4_TP15.nMatched > 0
    plotL4(L4_TP15, 'Torrey Pines 15m', 'L4_TP_15m');
end

fprintf('\n=== L4 complete ===\n');

%% ======================== LOCAL FUNCTIONS ========================

function local_plot_L4(L4, titleStr, fname, figDir)
    matched = L4.puv_valid & ~isnan(L4.dzdt_mm_hr);
    if sum(matched) < 10
        fprintf('  %s: too few matched points for plots\n', titleStr);
        return
    end

    fig = figure('Color','w','Visible','off','Position',[100 100 1200 800]);
    tiledlayout(2, 2, 'TileSpacing','compact', 'Padding','compact');
    sgtitle(sprintf('%s — L4 Diagnostics (%d matched bursts)', titleStr, sum(matched)), ...
        'FontSize', 14);

    % Panel 1: Time series — bed level + Hs (combined PUV + MOP)
    nexttile([1 2])
    yyaxis left
    plot(L4.time, L4.bedlevel_mm, 'Color',[0.18 0.45 0.75], 'LineWidth',0.6);
    ylabel('Bed level (mm)');
    yyaxis right
    if isfield(L4, 'Hs_combined')
        hasHs = ~isnan(L4.Hs_combined);
        plot(L4.time(hasHs), L4.Hs_combined(hasHs), 'Color',[0.85 0.33 0.1 0.3], 'LineWidth',0.4);
        nPuv = sum(L4.Hs_source == "PUV");
        nMop = sum(L4.Hs_source == "MOP");
        legend('Bed level', sprintf('H_s (%d PUV + %d MOP)', nPuv, nMop), 'Location','best');
    else
        plot(L4.time(matched), L4.Hs(matched), 'Color',[0.85 0.33 0.1 0.3], 'LineWidth',0.4);
        legend('Bed level', 'H_s (PUV)', 'Location','best');
    end
    ylabel('H_s (m)');
    grid on; box off

    % Panel 2: dz/dt vs tau_b
    nexttile
    scatter(L4.tau_b(matched), L4.dzdt_mm_hr(matched), 8, L4.Hs(matched), ...
        'filled', 'MarkerFaceAlpha', 0.3);
    xlabel('\tau_b (Pa)'); ylabel('dz/dt (mm/hr)');
    cb = colorbar; cb.Label.String = 'H_s (m)';
    title('Bed change rate vs shear stress');
    grid on

    % Panel 3: |dz/dt| vs Ub (binned)
    nexttile
    Ub = L4.Ub(matched);
    dzdt_abs = abs(L4.dzdt_mm_hr(matched));
    nBins = 20;
    edges = linspace(min(Ub), max(Ub), nBins+1);
    binCenters = (edges(1:end-1) + edges(2:end)) / 2;
    binMean = nan(nBins, 1);
    binStd = nan(nBins, 1);
    for b = 1:nBins
        inBin = Ub >= edges(b) & Ub < edges(b+1);
        if sum(inBin) >= 5
            binMean(b) = mean(dzdt_abs(inBin));
            binStd(b) = std(dzdt_abs(inBin)) / sqrt(sum(inBin));
        end
    end
    valid = ~isnan(binMean);
    errorbar(binCenters(valid), binMean(valid), binStd(valid), 'o-', ...
        'Color',[0.18 0.45 0.75], 'MarkerFaceColor',[0.18 0.45 0.75], 'LineWidth',1.2);
    xlabel('U_b (m/s)'); ylabel('Mean |dz/dt| (mm/hr)');
    title('Binned |bed change rate| vs orbital velocity');
    grid on

    exportgraphics(fig, fullfile(figDir, [fname '_diagnostics.png']), 'Resolution', 150);
    close(fig);
    fprintf('  Saved: %s_diagnostics.png\n', fname);
end
