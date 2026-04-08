% RUN_STORM_ANALYSIS  Storm event decomposition with cross-shore depth transect.
%
% Plotting conventions (apply to ALL pipeline figures):
%   - Use 'tex' interpreter (never 'latex') — renders math while
%     respecting FontName from startup.m
%   - Solid lines where data exists; faint shaded envelope across gaps
%   - dz/dt as 24-hr moving average in mm/day (not raw burst-to-burst)
%   - tau_b filtered to physical maximum (10 Pa)
%   - Consistent line weights: data=1.5, context=0.8, reference=0.5

clear; close all;

codeDir = fileparts(mfilename('fullpath'));
addpath(codeDir);
addpath(fullfile(codeDir, '..', 'config'));
addpath('/Users/holden/Documents/Scripps/Research/toolbox');
addpath('/Users/holden/Documents/Scripps/Research/Beach_Change_Observation/mop');

L4dir  = fullfile(codeDir, '..', 'outputs', 'L4');
L3root = fullfile(codeDir, '..', 'outputs', 'all');
pvuRoot = '/Users/holden/Documents/Scripps/Research/PUV_Pipeline/outputs';
figDir = fullfile(codeDir, '..', 'outputs', 'figures');

%% Build 7m L4 if needed
if ~isfile(fullfile(L4dir, 'L4_TP_7m.mat'))
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
tau_b_max = 10;  % Pa physical maximum

%% === DEC 28 2023 STORM FIGURE ===
t1 = datetime(2023,12,22); t2 = datetime(2024,1,15);
smoothWin = 18;   % ~6 hours for bed level smoothing
dayWin    = 72;   % ~24 hours for dz/dt

fig = figure('Color','w','Visible','off','Position',[50 50 1000 900]);
tl = tiledlayout(4, 1, 'TileSpacing','compact', 'Padding','compact');
title(tl, 'December 28, 2023 Storm — Torrey Pines MOP586', 'FontSize', 13);

% --- Panel 1: Hs ---
ax1 = nexttile;
for d = 1:4
    L4 = L4s{d};
    win = L4.time >= t1 & L4.time <= t2 & ~isnan(L4.Hs_combined);
    plot(L4.time(win), L4.Hs_combined(win), 'Color', [colors(d,:) 0.6], ...
        'LineWidth', 0.8, 'DisplayName', labels{d});
    hold on
end
ylabel('H_s (m)');
lg = legend('Location','northeast'); lg.FontSize = 8;
xlim([t1 t2]); grid on; box off
set(ax1, 'XTickLabel', []);

% --- Panel 2: Smoothed bed level with gap shading ---
ax2 = nexttile;
for d = 1:4
    L4 = L4s{d};
    win = find(L4.time >= t1 & L4.time <= t2);
    if isempty(win), continue; end
    bl = L4.bedlevel_mm(win);
    iqr_val = L4.bedlevel_iqr_mm(win);
    tt = L4.time(win);

    pre = tt < datetime(2023,12,26);
    if any(pre & ~isnan(bl))
        bl = bl - median(bl(pre), 'omitnan');
    end

    bl_sm = movmedian(bl, smoothWin, 'omitnan');
    iqr_sm = movmedian(iqr_val, smoothWin, 'omitnan');

    % IQR shading
    valid = find(~isnan(bl_sm));
    if numel(valid) > 2
        lo = bl_sm(valid) - iqr_sm(valid)/2;
        hi = bl_sm(valid) + iqr_sm(valid)/2;
        fill([tt(valid); flipud(tt(valid))], [lo; flipud(hi)], ...
            colors(d,:), 'FaceAlpha', 0.08, 'EdgeColor', 'none', 'HandleVisibility','off');
        hold on
    end

    % Segment the data at gaps > 3 hours
    dt_mins = minutes(diff(tt));
    gapThresh = 180;
    segStarts = [1; find(dt_mins > gapThresh) + 1];
    segEnds   = [find(dt_mins > gapThresh); numel(tt)];

    % Solid lines for data segments
    firstSeg = true;
    for seg = 1:numel(segStarts)
        sIdx = segStarts(seg):segEnds(seg);
        sValid = sIdx(~isnan(bl_sm(sIdx)));
        if numel(sValid) >= 2
            if firstSeg
                plot(tt(sValid), bl_sm(sValid), 'Color', colors(d,:), 'LineWidth', 1.5, ...
                    'DisplayName', labels{d});
                firstSeg = false;
            else
                plot(tt(sValid), bl_sm(sValid), 'Color', colors(d,:), 'LineWidth', 1.5, ...
                    'HandleVisibility','off');
            end
            hold on
        end
    end

    % Faint shading across gaps (expanding uncertainty envelope)
    for g = 1:numel(segStarts)-1
        gE = segEnds(g);     % last index of segment before gap
        gS = segStarts(g+1); % first index of segment after gap
        v1 = find(~isnan(bl_sm(1:gE)), 1, 'last');
        v2 = find(~isnan(bl_sm(gS:end)), 1, 'first') + gS - 1;
        if isempty(v1) || isempty(v2), continue; end

        tGap = [tt(v1), tt(v2)];
        blGap = [bl_sm(v1), bl_sm(v2)];
        gapDur_hr = hours(tGap(2) - tGap(1));
        nPts = max(20, round(gapDur_hr));
        tInterp = linspace(tGap(1), tGap(2), nPts);
        blInterp = interp1(datenum(tGap), blGap, datenum(tInterp));

        % Uncertainty grows with sqrt(time) from each endpoint
        tFrac = linspace(0, 1, nPts);
        uncert = gapDur_hr * 0.5 * sqrt(4 * tFrac .* (1 - tFrac));  % max at midpoint

        fill([tInterp, fliplr(tInterp)], ...
             [blInterp + uncert, fliplr(blInterp - uncert)], ...
             colors(d,:), 'FaceAlpha', 0.06, 'EdgeColor', 'none', 'HandleVisibility','off');
    end
end
ylabel('\Deltaz from pre-storm (mm)');
yline(0, 'k:', 'HandleVisibility','off', 'LineWidth', 0.5);
lg = legend('Location','northwest'); lg.FontSize = 8;
xlim([t1 t2]); grid on; box off
set(ax2, 'XTickLabel', []);

% --- Panel 3: dz/dt as 24-hr moving average (mm/day) ---
ax3 = nexttile;
for d = 1:4
    L4 = L4s{d};
    win = find(L4.time >= t1 & L4.time <= t2);
    if isempty(win), continue; end
    bl = L4.bedlevel_mm(win);
    tt = L4.time(win);
    pre = tt < datetime(2023,12,26);
    if any(pre & ~isnan(bl))
        bl = bl - median(bl(pre), 'omitnan');
    end

    % Smooth bed level first, then compute daily rate from 24-hr difference
    bl_sm2 = movmedian(bl, smoothWin, 'omitnan');
    % Use centered 24-hr difference (not derivative of movmean)
    halfDay = round(dayWin / 2);
    dzdt_day = nan(size(bl_sm2));
    for j = halfDay+1:numel(bl_sm2)-halfDay
        dt_hr_j = hours(tt(j+halfDay) - tt(j-halfDay));
        if dt_hr_j > 0 && dt_hr_j < 48 && ~isnan(bl_sm2(j+halfDay)) && ~isnan(bl_sm2(j-halfDay))
            dzdt_day(j) = (bl_sm2(j+halfDay) - bl_sm2(j-halfDay)) / dt_hr_j * 24;
        end
    end

    valid = ~isnan(dzdt_day);
    plot(tt(valid), dzdt_day(valid), 'Color', [colors(d,:) 0.8], ...
        'LineWidth', 1.0, 'DisplayName', labels{d});
    hold on
end
ylabel('d\Deltaz/dt (mm/day)');
yline(0, 'k:', 'HandleVisibility','off', 'LineWidth', 0.5);
lg = legend('Location','northeast'); lg.FontSize = 8;
xlim([t1 t2]); grid on; box off
set(ax3, 'XTickLabel', []);

% --- Panel 4: tau_b (QC filtered) ---
ax4 = nexttile;
for d = 1:4
    L4 = L4s{d};
    tau = L4.tau_b;
    tau(tau > tau_b_max) = NaN;
    win = L4.time >= t1 & L4.time <= t2 & L4.puv_valid & ~isnan(tau);
    if any(win)
        plot(L4.time(win), tau(win), 'Color', [colors(d,:) 0.6], ...
            'LineWidth', 0.8, 'DisplayName', labels{d});
        hold on
    end
end
ylabel('\tau_b (Pa)');
xlabel('Date');
lg = legend('Location','northeast'); lg.FontSize = 8;
xlim([t1 t2]); grid on; box off

linkaxes([ax1 ax2 ax3 ax4], 'x');

exportgraphics(fig, fullfile(figDir, 'storm_dec2023_TP_refined.png'), 'Resolution', 200);
close(fig);
fprintf('Saved storm_dec2023_TP_refined.png\n');

%% === QUANTIFY ===
fprintf('\n=== Dec 28 Storm Response ===\n');
preWindow  = [datetime(2023,12,22), datetime(2023,12,26)];
postWindow = [datetime(2024,1,5), datetime(2024,1,15)];

fprintf('%-6s %8s %8s %8s\n', 'Depth', 'Pre-BL', 'Post-BL', 'Net DZ');
for d = 1:4
    L4 = L4s{d};
    pre  = L4.time >= preWindow(1) & L4.time <= preWindow(2);
    post = L4.time >= postWindow(1) & L4.time <= postWindow(2);
    preBL  = median(L4.bedlevel_mm(pre), 'omitnan');
    postBL = median(L4.bedlevel_mm(post), 'omitnan');
    fprintf('%-6s %+7.0fmm %+7.0fmm %+7.0fmm\n', ...
        [num2str(depths(d)) 'm'], preBL, postBL, postBL-preBL);
end
