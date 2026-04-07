addpath('/Users/holden/Documents/Scripps/Research/Altimeter_Pipeline/CODES');

L4dir = '/Users/holden/Documents/Scripps/Research/Altimeter_Pipeline/outputs/L4';
figDir = '/Users/holden/Documents/Scripps/Research/Altimeter_Pipeline/outputs/figures';

% Load all L4 products
sites = {
    'L4_SIO_6m.mat', 'SIO 6m', 6;
    'L4_TP_5m.mat',  'TP 5m',  5;
    'L4_TP_10m.mat', 'TP 10m', 10;
    'L4_TP_15m.mat', 'TP 15m', 15;
};

%% === BINNED |dz/dt| vs tau_b — threshold identification ===
fig1 = figure('Color','w','Visible','off','Position',[50 50 1200 900]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
sgtitle('Bed Change Rate vs Bed Shear Stress — Threshold Analysis','FontSize',14);

colors = [0.18 0.45 0.75; 0.85 0.33 0.1; 0.47 0.67 0.19; 0.49 0.18 0.56];

thresholds = nan(4,1);

for s = 1:4
    S = load(fullfile(L4dir, sites{s,1}));
    L4 = S.L4;
    
    matched = L4.puv_valid & ~isnan(L4.dzdt_mm_hr) & ~isnan(L4.tau_b);
    tau = L4.tau_b(matched);
    dzdt = abs(L4.dzdt_mm_hr(matched));
    
    % Bin by tau_b
    nBins = 30;
    edges = linspace(0, prctile(tau, 99), nBins+1);
    binC = (edges(1:end-1)+edges(2:end))/2;
    binMean = nan(nBins,1);
    binStd = nan(nBins,1);
    binN = zeros(nBins,1);
    
    for b = 1:nBins
        inBin = tau >= edges(b) & tau < edges(b+1);
        binN(b) = sum(inBin);
        if binN(b) >= 10
            binMean(b) = mean(dzdt(inBin));
            binStd(b) = std(dzdt(inBin)) / sqrt(binN(b));
        end
    end
    
    % Estimate background noise level from lowest tau bins
    bgBins = binC < prctile(tau, 10);
    if sum(bgBins & ~isnan(binMean)) >= 2
        bgLevel = mean(binMean(bgBins & ~isnan(binMean)));
    else
        bgLevel = min(binMean(~isnan(binMean)));
    end
    
    % Threshold: first bin where mean |dz/dt| exceeds 1.5x background
    aboveThresh = binMean > 1.5 * bgLevel;
    threshIdx = find(aboveThresh & ~isnan(binMean), 1);
    if ~isempty(threshIdx)
        thresholds(s) = binC(threshIdx);
    end
    
    nexttile
    v = ~isnan(binMean);
    errorbar(binC(v), binMean(v), binStd(v), 'o-', ...
        'Color', colors(s,:), 'MarkerFaceColor', colors(s,:), 'LineWidth', 1.2);
    hold on
    yline(bgLevel, '--', 'Color', [0.5 0.5 0.5], 'HandleVisibility','off');
    yline(1.5*bgLevel, ':', 'Color', [0.5 0.5 0.5], 'Label', '1.5x background', ...
        'LabelHorizontalAlignment','left', 'HandleVisibility','off');
    if ~isnan(thresholds(s))
        xline(thresholds(s), '-', 'Color', 'r', 'LineWidth', 1.5, ...
            'Label', sprintf('\\tau_{cr} \\approx %.2f Pa', thresholds(s)), ...
            'LabelHorizontalAlignment','right');
    end
    xlabel('\tau_b (Pa)'); ylabel('Mean |dz/dt| (mm/hr)');
    title(sprintf('%s (%d matched)', sites{s,2}, sum(matched)));
    grid on
end

exportgraphics(fig1, fullfile(figDir, 'threshold_tau_b.png'), 'Resolution', 150);
close(fig1);
fprintf('Saved threshold_tau_b.png\n');

%% === BINNED |dz/dt| vs Ub — all depths overlaid ===
fig2 = figure('Color','w','Visible','off','Position',[50 50 800 500]);

for s = 1:4
    S = load(fullfile(L4dir, sites{s,1}));
    L4 = S.L4;
    
    matched = L4.puv_valid & ~isnan(L4.dzdt_mm_hr) & ~isnan(L4.Ub);
    Ub = L4.Ub(matched);
    dzdt = abs(L4.dzdt_mm_hr(matched));
    
    nBins = 15;
    edges = linspace(prctile(Ub,1), prctile(Ub,99), nBins+1);
    binC = (edges(1:end-1)+edges(2:end))/2;
    binMean = nan(nBins,1);
    binStd = nan(nBins,1);
    
    for b = 1:nBins
        inBin = Ub >= edges(b) & Ub < edges(b+1);
        if sum(inBin) >= 10
            binMean(b) = mean(dzdt(inBin));
            binStd(b) = std(dzdt(inBin)) / sqrt(sum(inBin));
        end
    end
    
    v = ~isnan(binMean);
    errorbar(binC(v), binMean(v), binStd(v), 'o-', ...
        'Color', colors(s,:), 'MarkerFaceColor', colors(s,:), ...
        'LineWidth', 1.2, 'DisplayName', sites{s,2});
    hold on
end

xlabel('U_b (m/s)'); ylabel('Mean |dz/dt| (mm/hr)');
title('Bed Change Rate vs Orbital Velocity — All Depths');
legend('Location','northwest');
grid on; box off

exportgraphics(fig2, fullfile(figDir, 'threshold_Ub_all_depths.png'), 'Resolution', 150);
close(fig2);
fprintf('Saved threshold_Ub_all_depths.png\n');

%% === SHIELDS PARAMETER ANALYSIS ===
fig3 = figure('Color','w','Visible','off','Position',[50 50 1200 450]);
tiledlayout(1,3,'TileSpacing','compact','Padding','compact');
sgtitle('Shields Parameter Analysis','FontSize',14);

% Panel 1: |dz/dt| vs Shields
nexttile
for s = 1:4
    S = load(fullfile(L4dir, sites{s,1}));
    L4 = S.L4;
    matched = L4.puv_valid & ~isnan(L4.dzdt_mm_hr) & ~isnan(L4.shields);
    shields = L4.shields(matched);
    dzdt = abs(L4.dzdt_mm_hr(matched));
    
    nBins = 15;
    edges = linspace(0, prctile(shields,99), nBins+1);
    binC = (edges(1:end-1)+edges(2:end))/2;
    binMean = nan(nBins,1); binStd = nan(nBins,1);
    for b = 1:nBins
        inBin = shields >= edges(b) & shields < edges(b+1);
        if sum(inBin) >= 10
            binMean(b) = mean(dzdt(inBin));
            binStd(b) = std(dzdt(inBin)) / sqrt(sum(inBin));
        end
    end
    v = ~isnan(binMean);
    errorbar(binC(v), binMean(v), binStd(v), 'o-', 'Color', colors(s,:), ...
        'MarkerFaceColor', colors(s,:), 'LineWidth', 1.2, 'DisplayName', sites{s,2});
    hold on
end
xlabel('Shields parameter \theta'); ylabel('Mean |dz/dt| (mm/hr)');
legend('Location','northwest'); grid on

% Panel 2: Fraction mobilized vs depth
nexttile
depthVals = [6, 5, 10, 15];
fracMob = nan(4,1);
medShields = nan(4,1);
for s = 1:4
    S = load(fullfile(L4dir, sites{s,1}));
    L4 = S.L4;
    matched = L4.puv_valid;
    fracMob(s) = 100*mean(L4.mobilized(matched));
    medShields(s) = median(L4.shields(matched), 'omitnan');
end
bar(categorical({'SIO 6m','TP 5m','TP 10m','TP 15m'}), fracMob);
ylabel('Bursts mobilized (%)');
title('Mobilization by depth');
grid on

% Panel 3: Summary table as text
nexttile
axis off
txt = sprintf('%-8s %6s %8s %8s %8s\n', 'Site', 'Depth', 'tau_cr', 'theta_med', 'Mobil%');
txt = [txt sprintf('%-8s %6s %8s %8s %8s\n', '', '(m)', '(Pa)', '', '')];
for s = 1:4
    txt = [txt sprintf('%-8s %5dm %8.2f %8.3f %7.0f%%\n', ...
        sites{s,2}, sites{s,3}, thresholds(s), medShields(s), fracMob(s))];
end
text(0.1, 0.7, txt, 'FontName', 'FixedWidth', 'FontSize', 10, ...
    'VerticalAlignment', 'top');
title('Summary');

exportgraphics(fig3, fullfile(figDir, 'shields_analysis.png'), 'Resolution', 150);
close(fig3);
fprintf('Saved shields_analysis.png\n');

%% Print summary
fprintf('\n=== THRESHOLD ANALYSIS SUMMARY ===\n');
fprintf('%-8s %6s %8s %8s %8s\n', 'Site', 'Depth', 'tau_cr', 'theta_med', 'Mobil%');
for s = 1:4
    fprintf('%-8s %5dm %8.2f %8.3f %7.0f%%\n', ...
        sites{s,2}, sites{s,3}, thresholds(s), medShields(s), fracMob(s));
end

exit;
