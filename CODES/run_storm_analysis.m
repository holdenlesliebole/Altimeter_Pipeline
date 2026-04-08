addpath('/Users/holden/Documents/Scripps/Research/Altimeter_Pipeline/CODES');

L4dir = '/Users/holden/Documents/Scripps/Research/Altimeter_Pipeline/outputs/L4';
figDir = '/Users/holden/Documents/Scripps/Research/Altimeter_Pipeline/outputs/figures';

% Load all TP L4 products
S5 = load(fullfile(L4dir, 'L4_TP_5m.mat')); L4_5 = S5.L4;
S10 = load(fullfile(L4dir, 'L4_TP_10m.mat')); L4_10 = S10.L4;
S15 = load(fullfile(L4dir, 'L4_TP_15m.mat')); L4_15 = S15.L4;
S_SIO = load(fullfile(L4dir, 'L4_SIO_6m.mat')); L4_SIO = S_SIO.L4;

%% === IDENTIFY STORM EVENTS from Hs ===
% Use TP 10m MOP Hs as reference (best coverage)
Hs = L4_10.Hs_combined;
t = L4_10.time;
valid = ~isnan(Hs);

% Storm threshold: Hs > 2m for > 6 hours
Hs_thresh = 2.0;
min_dur_hr = 6;

above = Hs > Hs_thresh;
above(~valid) = false;

% Find storm start/end
d = diff([false; above; false]);
starts = find(d == 1);
ends = find(d == -1) - 1;

% Filter by duration
events = struct();
nEvents = 0;
for e = 1:numel(starts)
    dur_hr = hours(t(ends(e)) - t(starts(e)));
    if dur_hr >= min_dur_hr
        nEvents = nEvents + 1;
        events(nEvents).start = t(starts(e));
        events(nEvents).end_time = t(ends(e));
        events(nEvents).dur_hr = dur_hr;
        [events(nEvents).peak_Hs, pidx] = max(Hs(starts(e):ends(e)));
        events(nEvents).peak_time = t(starts(e) + pidx - 1);
    end
end

fprintf('=== Storm Events (Hs > %.1fm, > %dhr) ===\n', Hs_thresh, min_dur_hr);
for e = 1:nEvents
    fprintf('  %d. %s to %s (%.0fhr), peak Hs=%.2fm at %s\n', ...
        e, string(events(e).start), string(events(e).end_time), ...
        events(e).dur_hr, events(e).peak_Hs, string(events(e).peak_time));
end

%% === DEC 28 2023 STORM — DETAILED CASE STUDY ===
% Window: Dec 25 2023 - Jan 10 2024 (pre-storm to post-storm)
t1 = datetime(2023,12,22); t2 = datetime(2024,1,15);

fig1 = figure('Color','w','Visible','off','Position',[50 50 1200 1000]);
tiledlayout(5, 1, 'TileSpacing','compact', 'Padding','compact');
sgtitle('December 28, 2023 Storm — Torrey Pines Cross-Shore Response', 'FontSize', 14);

colors = {[0.85 0.33 0.1], [0.47 0.67 0.19], [0.49 0.18 0.56]};
L4s = {L4_5, L4_10, L4_15};
labels = {'5m', '10m', '15m'};
depths = [5, 10, 15];

% Panel 1: Hs (combined MOP+PUV)
nexttile
for d = 1:3
    L4 = L4s{d};
    win = L4.time >= t1 & L4.time <= t2;
    hasHs = win & ~isnan(L4.Hs_combined);
    plot(L4.time(hasHs), L4.Hs_combined(hasHs), 'Color', [colors{d} 0.7], ...
        'LineWidth', 1.0, 'DisplayName', [labels{d} ' H_s']);
    hold on
end
ylabel('H_s (m)');
legend('Location','northeast');
xlim([t1 t2]);
grid on; box off
title('Wave Height');

% Panel 2: Bed level at each depth
nexttile
for d = 1:3
    L4 = L4s{d};
    win = L4.time >= t1 & L4.time <= t2;
    bl = L4.bedlevel_mm(win);
    tt = L4.time(win);
    % Re-baseline to pre-storm value
    preStorm = tt < datetime(2023,12,26);
    if any(preStorm & ~isnan(bl))
        bl = bl - median(bl(preStorm), 'omitnan');
    end
    plot(tt, bl, 'Color', colors{d}, 'LineWidth', 1.2, 'DisplayName', [labels{d} ' bed level']);
    hold on
end
ylabel('\Delta z from pre-storm (mm)');
legend('Location','best');
xlim([t1 t2]);
grid on; box off
title('Bed Level Change (relative to pre-storm)');

% Panel 3: dz/dt at each depth
nexttile
for d = 1:3
    L4 = L4s{d};
    win = L4.time >= t1 & L4.time <= t2 & ~isnan(L4.dzdt_mm_hr);
    plot(L4.time(win), L4.dzdt_mm_hr(win), 'Color', [colors{d} 0.5], ...
        'LineWidth', 0.6, 'DisplayName', labels{d});
    hold on
end
ylabel('dz/dt (mm/hr)');
yline(0, 'k-', 'HandleVisibility','off');
legend('Location','best');
xlim([t1 t2]);
grid on; box off
title('Bed Level Change Rate');

% Panel 4: tau_b (PUV only)
nexttile
for d = 1:3
    L4 = L4s{d};
    win = L4.time >= t1 & L4.time <= t2 & L4.puv_valid;
    if any(win)
        plot(L4.time(win), L4.tau_b(win), 'Color', [colors{d} 0.5], ...
            'LineWidth', 0.6, 'DisplayName', labels{d});
        hold on
    end
end
ylabel('\tau_b (Pa)');
legend('Location','best');
xlim([t1 t2]);
grid on; box off
title('Bed Shear Stress (PUV)');

% Panel 5: Cumulative bed level change
nexttile
for d = 1:3
    L4 = L4s{d};
    win = L4.time >= t1 & L4.time <= t2;
    bl = L4.bedlevel_mm(win);
    tt = L4.time(win);
    preStorm = tt < datetime(2023,12,26);
    if any(preStorm & ~isnan(bl))
        bl = bl - median(bl(preStorm), 'omitnan');
    end
    % Smooth with 6-hour running median for clarity
    if sum(~isnan(bl)) > 20
        bl_smooth = movmedian(bl, 20, 'omitnan');
        plot(tt, bl_smooth, 'Color', colors{d}, 'LineWidth', 2.0, 'DisplayName', labels{d});
        hold on
    end
end
ylabel('\Delta z smoothed (mm)');
yline(0, 'k--', 'HandleVisibility','off');
legend('Location','best');
xlim([t1 t2]);
grid on; box off
title('Smoothed Bed Level (6-hr running median)');

exportgraphics(fig1, fullfile(figDir, 'storm_dec2023_TP.png'), 'Resolution', 150);
close(fig1);
fprintf('\nSaved storm_dec2023_TP.png\n');

%% === QUANTIFY STORM RESPONSE PER DEPTH ===
fprintf('\n=== Dec 28 Storm Response by Depth ===\n');
stormStart = datetime(2023,12,26);
stormEnd = datetime(2023,12,31);
preWindow = [datetime(2023,12,22), stormStart];
postWindow = [datetime(2024,1,5), datetime(2024,1,15)];

fprintf('%-6s %8s %8s %8s %8s %8s\n', 'Depth', 'Pre-BL', 'Storm-BL', 'Post-BL', 'DeltaZ', 'Peak|dz|');
for d = 1:3
    L4 = L4s{d};
    
    pre = L4.time >= preWindow(1) & L4.time <= preWindow(2);
    storm = L4.time >= stormStart & L4.time <= stormEnd;
    post = L4.time >= postWindow(1) & L4.time <= postWindow(2);
    
    preBL = median(L4.bedlevel_mm(pre), 'omitnan');
    stormBL = median(L4.bedlevel_mm(storm), 'omitnan');
    postBL = median(L4.bedlevel_mm(post), 'omitnan');
    deltaZ = postBL - preBL;
    peakDzdt = max(abs(L4.dzdt_mm_hr(storm)), [], 'omitnan');
    
    fprintf('%-6s %+7.0fmm %+7.0fmm %+7.0fmm %+7.0fmm %7.0fmm/hr\n', ...
        [num2str(depths(d)) 'm'], preBL, stormBL, postBL, deltaZ, peakDzdt);
end

%% === DEC 22 2024 STORM — SIO + TP ===
t3 = datetime(2024,12,18); t4 = datetime(2025,1,10);

fig2 = figure('Color','w','Visible','off','Position',[50 50 1200 700]);
tiledlayout(3, 1, 'TileSpacing','compact', 'Padding','compact');
sgtitle('December 22, 2024 Storm — Multi-Site Response', 'FontSize', 14);

% Panel 1: Hs at SIO and TP
nexttile
win_sio = L4_SIO.time >= t3 & L4_SIO.time <= t4 & ~isnan(L4_SIO.Hs_combined);
plot(L4_SIO.time(win_sio), L4_SIO.Hs_combined(win_sio), 'Color', [0.18 0.45 0.75 0.7], ...
    'LineWidth', 1.0, 'DisplayName', 'SIO 6m');
hold on
win_tp = L4_10.time >= t3 & L4_10.time <= t4 & ~isnan(L4_10.Hs_combined);
plot(L4_10.time(win_tp), L4_10.Hs_combined(win_tp), 'Color', [0.47 0.67 0.19 0.7], ...
    'LineWidth', 1.0, 'DisplayName', 'TP 10m');
ylabel('H_s (m)'); legend('Location','best');
xlim([t3 t4]); grid on; box off
title('Wave Height');

% Panel 2: Bed level — SIO
nexttile
win = L4_SIO.time >= t3 & L4_SIO.time <= t4;
bl = L4_SIO.bedlevel_mm(win);
tt = L4_SIO.time(win);
pre = tt < datetime(2024,12,20);
if any(pre & ~isnan(bl)), bl = bl - median(bl(pre),'omitnan'); end
plot(tt, bl, 'Color', [0.18 0.45 0.75], 'LineWidth', 1.0);
ylabel('\Delta z from pre-storm (mm)');
xlim([t3 t4]); grid on; box off
title('SIO Pier 6m — Bed Level Change');

% Panel 3: Bed level — TP multi-depth
nexttile
for d = 1:3
    L4 = L4s{d};
    win = L4.time >= t3 & L4.time <= t4;
    bl = L4.bedlevel_mm(win);
    tt = L4.time(win);
    pre = tt < datetime(2024,12,20);
    if any(pre & ~isnan(bl)), bl = bl - median(bl(pre),'omitnan'); end
    plot(tt, bl, 'Color', colors{d}, 'LineWidth', 1.0, 'DisplayName', labels{d});
    hold on
end
ylabel('\Delta z from pre-storm (mm)');
yline(0, 'k--', 'HandleVisibility','off');
legend('Location','best');
xlim([t3 t4]); grid on; box off
title('Torrey Pines — Bed Level Change');

exportgraphics(fig2, fullfile(figDir, 'storm_dec2024_multi.png'), 'Resolution', 150);
close(fig2);
fprintf('Saved storm_dec2024_multi.png\n');

exit;
