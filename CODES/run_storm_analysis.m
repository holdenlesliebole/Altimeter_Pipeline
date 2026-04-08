addpath('/Users/holden/Documents/Scripps/Research/Altimeter_Pipeline/CODES');
addpath('/Users/holden/Documents/Scripps/Research/Altimeter_Pipeline/config');
addpath('/Users/holden/Documents/Scripps/Research/toolbox');
addpath('/Users/holden/Documents/Scripps/Research/Beach_Change_Observation/mop');

L4dir = '/Users/holden/Documents/Scripps/Research/Altimeter_Pipeline/outputs/L4';
L3root = '/Users/holden/Documents/Scripps/Research/Altimeter_Pipeline/outputs/all';
pvuRoot = '/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs';
figDir = '/Users/holden/Documents/Scripps/Research/Altimeter_Pipeline/outputs/figures';

%% Build 7m L4 if it doesn't exist
if ~isfile(fullfile(L4dir, 'L4_TP_7m.mat'))
    fprintf('Building TP 7m L4...\n');
    build_L4_site(L3root, pvuRoot, 'TorreyPines', ...
        'depths', 7, 'pvuLabel', "MOP586_7m", ...
        'anchorMethod', 'survey', ...
        'instrumentLat', 32.93048, 'instrumentLon', -117.26420, ...
        'mopStation', "D0586", ...
        'savePath', fullfile(L4dir, 'L4_TP_7m.mat'));
end

%% Load all depths
S5 = load(fullfile(L4dir, 'L4_TP_5m.mat')); L4_5 = S5.L4;
S7 = load(fullfile(L4dir, 'L4_TP_7m.mat')); L4_7 = S7.L4;
S10 = load(fullfile(L4dir, 'L4_TP_10m.mat')); L4_10 = S10.L4;
S15 = load(fullfile(L4dir, 'L4_TP_15m.mat')); L4_15 = S15.L4;

L4s = {L4_5, L4_7, L4_10, L4_15};
labels = {'5 m', '7 m', '10 m', '15 m'};
depths = [5, 7, 10, 15];
colors = [0.85 0.33 0.1; 0.93 0.69 0.13; 0.47 0.67 0.19; 0.49 0.18 0.56];

%% === DEC 28 2023 STORM — REFINED FIGURE ===
t1 = datetime(2023,12,22); t2 = datetime(2024,1,15);

fig = figure('Color','w','Visible','off','Position',[50 50 1000 900]);
tl = tiledlayout(4, 1, 'TileSpacing','compact', 'Padding','compact');
title(tl, '\textbf{December 28, 2023 Storm --- Torrey Pines MOP586 Cross-Shore Response}', ...
    'Interpreter','latex', 'FontSize', 13);

% Panel 1: Hs
ax1 = nexttile;
for d = 1:4
    L4 = L4s{d};
    win = L4.time >= t1 & L4.time <= t2 & ~isnan(L4.Hs_combined);
    plot(L4.time(win), L4.Hs_combined(win), 'Color', [colors(d,:) 0.6], ...
        'LineWidth', 0.8, 'DisplayName', labels{d});
    hold on
end
ylabel('$H_s$ (m)', 'Interpreter','latex', 'FontSize', 11);
legend('Location','northeast', 'FontSize', 8);
xlim([t1 t2]); grid on; box off
set(ax1, 'XTickLabel', []);

% Panel 2: Smoothed bed level (6-hr running median) with IQR uncertainty
ax2 = nexttile;
smoothWin = 18;  % ~6 hours at 20-min burst cadence
for d = 1:4
    L4 = L4s{d};
    win = L4.time >= t1 & L4.time <= t2;
    bl = L4.bedlevel_mm(win);
    iqr_val = L4.bedlevel_iqr_mm(win);
    tt = L4.time(win);
    
    % Re-baseline to pre-storm
    pre = tt < datetime(2023,12,26);
    if any(pre & ~isnan(bl))
        bl = bl - median(bl(pre), 'omitnan');
    end
    
    % Smooth
    bl_sm = movmedian(bl, smoothWin, 'omitnan');
    iqr_sm = movmedian(iqr_val, smoothWin, 'omitnan');
    
    valid = ~isnan(bl_sm);
    
    % Find gaps > 3 hours for faint interpolation
    dt_burst = minutes(diff(tt));
    gapIdx = find(dt_burst > 180);  % 3-hour gaps
    
    % Plot solid where data exists, faint dashed across gaps
    % First plot the IQR band
    if any(valid)
        lo = bl_sm - iqr_sm/2;
        hi = bl_sm + iqr_sm/2;
        vIdx = find(valid);
        fill([tt(vIdx); flipud(tt(vIdx))], [lo(vIdx); flipud(hi(vIdx))], ...
            colors(d,:), 'FaceAlpha', 0.08, 'EdgeColor', 'none', 'HandleVisibility','off');
        hold on
    end
    
    % Plot the bed level line
    plot(tt(valid), bl_sm(valid), 'Color', colors(d,:), 'LineWidth', 1.5, ...
        'DisplayName', labels{d});
    hold on
end
ylabel('$\Delta z$ from pre-storm (mm)', 'Interpreter','latex', 'FontSize', 11);
yline(0, 'k:', 'HandleVisibility','off', 'LineWidth', 0.5);
legend('Location','northwest', 'FontSize', 8);
xlim([t1 t2]); grid on; box off
set(ax2, 'XTickLabel', []);

% Panel 3: Smoothed dz/dt (hourly average, not raw burst-to-burst)
ax3 = nexttile;
for d = 1:4
    L4 = L4s{d};
    win = L4.time >= t1 & L4.time <= t2;
    bl = L4.bedlevel_mm(win);
    tt = L4.time(win);
    pre = tt < datetime(2023,12,26);
    if any(pre & ~isnan(bl))
        bl = bl - median(bl(pre), 'omitnan');
    end
    
    % Compute dz/dt from smoothed bed level (much cleaner than raw)
    bl_sm = movmedian(bl, smoothWin, 'omitnan');
    dt_hr = hours(diff(tt));
    dzdt_sm = diff(bl_sm) ./ dt_hr;
    % Remove values across large gaps
    dzdt_sm(dt_hr > 3) = NaN;
    t_mid = tt(1:end-1) + diff(tt)/2;
    
    valid = ~isnan(dzdt_sm);
    plot(t_mid(valid), dzdt_sm(valid), 'Color', [colors(d,:) 0.7], ...
        'LineWidth', 1.0, 'DisplayName', labels{d});
    hold on
end
ylabel('$d\Delta z/dt$ (mm/hr)', 'Interpreter','latex', 'FontSize', 11);
yline(0, 'k:', 'HandleVisibility','off', 'LineWidth', 0.5);
legend('Location','northeast', 'FontSize', 8);
xlim([t1 t2]); grid on; box off
set(ax3, 'XTickLabel', []);

% Panel 4: tau_b from PUV
ax4 = nexttile;
for d = 1:4
    L4 = L4s{d};
    win = L4.time >= t1 & L4.time <= t2 & L4.puv_valid & ~isnan(L4.tau_b);
    if any(win)
        plot(L4.time(win), L4.tau_b(win), 'Color', [colors(d,:) 0.6], ...
            'LineWidth', 0.8, 'DisplayName', labels{d});
        hold on
    end
end
ylabel('$\tau_b$ (Pa)', 'Interpreter','latex', 'FontSize', 11);
xlabel('Date', 'FontSize', 11);
legend('Location','northeast', 'FontSize', 8);
xlim([t1 t2]); grid on; box off

linkaxes([ax1 ax2 ax3 ax4], 'x');

exportgraphics(fig, fullfile(figDir, 'storm_dec2023_TP_refined.png'), 'Resolution', 200);
close(fig);
fprintf('Saved storm_dec2023_TP_refined.png\n');

%% Quantify 7m response
fprintf('\n=== Dec 28 Storm Response (with 7m) ===\n');
stormStart = datetime(2023,12,26);
postWindow = [datetime(2024,1,5), datetime(2024,1,15)];
preWindow = [datetime(2023,12,22), stormStart];

fprintf('%-6s %8s %8s %8s\n', 'Depth', 'Pre-BL', 'Post-BL', 'Net DZ');
for d = 1:4
    L4 = L4s{d};
    pre = L4.time >= preWindow(1) & L4.time <= preWindow(2);
    post = L4.time >= postWindow(1) & L4.time <= postWindow(2);
    preBL = median(L4.bedlevel_mm(pre), 'omitnan');
    postBL = median(L4.bedlevel_mm(post), 'omitnan');
    fprintf('%-6s %+7.0fmm %+7.0fmm %+7.0fmm\n', ...
        [num2str(depths(d)) 'm'], preBL, postBL, postBL-preBL);
end

exit;
