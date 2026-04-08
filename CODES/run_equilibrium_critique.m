% RUN_EQUILIBRIUM_CRITIQUE  Test Dean/Yates/Ludka equilibrium beach models
% against depth-resolved altimeter observations.
%
% The equilibrium concept: dz/dt = C * (E_eq - E) where E is a wave
% energy metric and E_eq is its equilibrium value for the current beach
% state. In practice:
%   - Dean (1991): Omega = Hs / (ws * T), erosive if Omega > Omega_eq
%   - Yates et al. (2009): dS/dt = C+ * (E_eq+ - E) for accretion,
%     C- * (E_eq- - E) for erosion, where S = shoreline position
%   - Ludka et al. (2015): same framework applied to Torrey Pines
%
% We test: does dz/dt correlate with disequilibrium at depth?

clear; close all;

codeDir = fileparts(mfilename('fullpath'));
addpath(codeDir);

L4dir = fullfile(codeDir, '..', 'outputs', 'L4');
figDir = fullfile(codeDir, '..', 'outputs', 'figures');

%% Load L4 products
sites = {
    'L4_SIO_6m.mat', 'SIO 6m', 6;
    'L4_TP_5m.mat',  'TP 5m',  5;
    'L4_TP_10m.mat', 'TP 10m', 10;
    'L4_TP_15m.mat', 'TP 15m', 15;
};
colors = [0.18 0.45 0.75; 0.85 0.33 0.1; 0.47 0.67 0.19; 0.49 0.18 0.56];

% Sediment fall velocity for D50 = 0.25mm (Soulsby 1997)
D50 = 0.25e-3;  % m
rho_s = 2650; rho_w = 1025; g = 9.81; nu = 1.05e-6;
Dstar = D50 * ((rho_s/rho_w - 1) * g / nu^2)^(1/3);
ws = nu/D50 * (sqrt(10.36^2 + 1.049*Dstar^3) - 10.36);  % Soulsby
fprintf('D50 = %.2f mm, ws = %.4f m/s\n', D50*1000, ws);

%% === 1. COMPUTE DEAN OMEGA AND TEST DISEQUILIBRIUM ===
fig1 = figure('Color','w','Visible','off','Position',[50 50 1200 900]);
tiledlayout(2, 2, 'TileSpacing','compact', 'Padding','compact');
sgtitle('Equilibrium Model Test: dz/dt vs Dean \Omega Disequilibrium', 'FontSize', 13);

for s = 1:4
    S = load(fullfile(L4dir, sites{s,1}));
    L4 = S.L4;

    % Use combined Hs (PUV + MOP) and Tp
    Hs = L4.Hs_combined;
    Tp = nan(size(Hs));
    % PUV Tp where available
    matched = L4.puv_valid;
    Tp(matched) = L4.Tp(matched);
    % MOP Tp for gap-fill
    if isfield(L4, 'mop_Tp')
        gapFill = isnan(Tp) & ~isnan(L4.mop_Tp);
        Tp(gapFill) = L4.mop_Tp(gapFill);
    end

    % Dean number
    Omega = Hs ./ (ws .* Tp);

    % Equilibrium Omega: use the long-term median as the "equilibrium"
    % This is the simplest test — Yates uses a more complex state-dependent eq.
    Omega_eq = median(Omega, 'omitnan');

    % Disequilibrium
    diseq = Omega - Omega_eq;

    % Smoothed dz/dt (24-hr centered difference in mm/day)
    bl = L4.bedlevel_mm;
    tt = L4.time;
    bl_sm = movmedian(bl, 18, 'omitnan');  % 6-hr smooth
    halfDay = 36;  % ~12 hrs each side = 24hr centered
    dzdt_day = nan(size(bl));
    for j = halfDay+1:numel(bl)-halfDay
        dt_hr = hours(tt(j+halfDay) - tt(j-halfDay));
        if dt_hr > 0 && dt_hr < 48 && ~isnan(bl_sm(j+halfDay)) && ~isnan(bl_sm(j-halfDay))
            dzdt_day(j) = (bl_sm(j+halfDay) - bl_sm(j-halfDay)) / dt_hr * 24;
        end
    end

    % Valid points: have both Omega and dz/dt
    valid = ~isnan(diseq) & ~isnan(dzdt_day);

    % Bin by disequilibrium
    nBins = 20;
    edges = linspace(prctile(diseq(valid), 2), prctile(diseq(valid), 98), nBins+1);
    binC = (edges(1:end-1) + edges(2:end)) / 2;
    binMean = nan(nBins, 1);
    binStd = nan(nBins, 1);
    for b = 1:nBins
        inBin = valid & diseq >= edges(b) & diseq < edges(b+1);
        if sum(inBin) >= 10
            binMean(b) = mean(dzdt_day(inBin));
            binStd(b) = std(dzdt_day(inBin)) / sqrt(sum(inBin));
        end
    end

    % Correlation
    cc = corrcoef(diseq(valid), dzdt_day(valid));
    R2 = cc(1,2)^2;

    % Linear fit
    p = polyfit(diseq(valid), dzdt_day(valid), 1);

    nexttile
    errorbar(binC(~isnan(binMean)), binMean(~isnan(binMean)), binStd(~isnan(binMean)), ...
        'o', 'Color', colors(s,:), 'MarkerFaceColor', colors(s,:), 'LineWidth', 1.2);
    hold on
    % Best-fit line
    xfit = linspace(min(binC), max(binC), 100);
    plot(xfit, polyval(p, xfit), '--', 'Color', [colors(s,:) 0.5], 'LineWidth', 1.0);
    yline(0, 'k:', 'LineWidth', 0.5);
    xline(0, 'k:', 'LineWidth', 0.5);
    xlabel('\Omega - \Omega_{eq}');
    ylabel('d\Deltaz/dt (mm/day)');
    title(sprintf('%s: R^2 = %.3f, slope = %.1f', sites{s,2}, R2, p(1)));
    grid on

    fprintf('%s: Omega_eq=%.2f, R2=%.4f, slope=%.2f mm/day per unit disequilibrium\n', ...
        sites{s,2}, Omega_eq, R2, p(1));
end

exportgraphics(fig1, fullfile(figDir, 'equilibrium_omega_test.png'), 'Resolution', 200);
close(fig1);
fprintf('\nSaved equilibrium_omega_test.png\n');

%% === 2. YATES-STYLE: dz/dt vs Hs^2 (energy proxy) ===
fig2 = figure('Color','w','Visible','off','Position',[50 50 1200 500]);
tiledlayout(1, 2, 'TileSpacing','compact', 'Padding','compact');

% Panel 1: dz/dt vs Hs^2
nexttile
for s = 1:4
    S = load(fullfile(L4dir, sites{s,1}));
    L4 = S.L4;

    Hs2 = L4.Hs_combined.^2;
    bl = L4.bedlevel_mm;
    tt = L4.time;
    bl_sm = movmedian(bl, 18, 'omitnan');
    halfDay = 36;
    dzdt_day = nan(size(bl));
    for j = halfDay+1:numel(bl)-halfDay
        dt_hr = hours(tt(j+halfDay) - tt(j-halfDay));
        if dt_hr > 0 && dt_hr < 48 && ~isnan(bl_sm(j+halfDay)) && ~isnan(bl_sm(j-halfDay))
            dzdt_day(j) = (bl_sm(j+halfDay) - bl_sm(j-halfDay)) / dt_hr * 24;
        end
    end

    valid = ~isnan(Hs2) & ~isnan(dzdt_day);
    nBins = 15;
    edges = linspace(prctile(Hs2(valid), 1), prctile(Hs2(valid), 99), nBins+1);
    binC = (edges(1:end-1)+edges(2:end))/2;
    binMean = nan(nBins,1);
    for b = 1:nBins
        inBin = valid & Hs2 >= edges(b) & Hs2 < edges(b+1);
        if sum(inBin) >= 10, binMean(b) = mean(dzdt_day(inBin)); end
    end

    v = ~isnan(binMean);
    plot(binC(v), binMean(v), 'o-', 'Color', colors(s,:), ...
        'MarkerFaceColor', colors(s,:), 'LineWidth', 1.2, 'DisplayName', sites{s,2});
    hold on
end
xlabel('H_s^2 (m^2)');
ylabel('Mean d\Deltaz/dt (mm/day)');
title('Bed change rate vs wave energy proxy');
yline(0, 'k:', 'HandleVisibility','off');
legend('Location','best', 'FontSize', 9);
grid on

% Panel 2: The key critique — dz/dt vs bed level (state dependence)
% Yates predicts: dz/dt should depend on BOTH forcing AND current state
% If the bed is above equilibrium, the same Hs should produce erosion
% If below equilibrium, same Hs should produce accretion
nexttile
for s = 1:4
    S = load(fullfile(L4dir, sites{s,1}));
    L4 = S.L4;

    bl = L4.bedlevel_mm;
    tt = L4.time;
    bl_sm = movmedian(bl, 18, 'omitnan');
    halfDay = 36;
    dzdt_day = nan(size(bl));
    for j = halfDay+1:numel(bl)-halfDay
        dt_hr = hours(tt(j+halfDay) - tt(j-halfDay));
        if dt_hr > 0 && dt_hr < 48 && ~isnan(bl_sm(j+halfDay)) && ~isnan(bl_sm(j-halfDay))
            dzdt_day(j) = (bl_sm(j+halfDay) - bl_sm(j-halfDay)) / dt_hr * 24;
        end
    end

    valid = ~isnan(bl_sm) & ~isnan(dzdt_day);
    nBins = 15;
    edges = linspace(prctile(bl_sm(valid), 2), prctile(bl_sm(valid), 98), nBins+1);
    binC = (edges(1:end-1)+edges(2:end))/2;
    binMean = nan(nBins,1);
    for b = 1:nBins
        inBin = valid & bl_sm >= edges(b) & bl_sm < edges(b+1);
        if sum(inBin) >= 10, binMean(b) = mean(dzdt_day(inBin)); end
    end

    v = ~isnan(binMean);
    plot(binC(v), binMean(v), 'o-', 'Color', colors(s,:), ...
        'MarkerFaceColor', colors(s,:), 'LineWidth', 1.2, 'DisplayName', sites{s,2});
    hold on

    % Equilibrium model prediction: negative slope (above eq → erosion, below → accretion)
    cc = corrcoef(bl_sm(valid), dzdt_day(valid));
    fprintf('%s: dz/dt vs z: R2=%.4f (equilibrium expects negative slope)\n', ...
        sites{s,2}, cc(1,2)^2);
end
xlabel('Bed level \Deltaz (mm)');
ylabel('Mean d\Deltaz/dt (mm/day)');
title('State dependence: dz/dt vs current bed level');
yline(0, 'k:', 'HandleVisibility','off');
legend('Location','best', 'FontSize', 9);
grid on

exportgraphics(fig2, fullfile(figDir, 'equilibrium_energy_state.png'), 'Resolution', 200);
close(fig2);
fprintf('\nSaved equilibrium_energy_state.png\n');

%% === 3. SUMMARY: Model comparison ===
fprintf('\n=== EQUILIBRIUM MODEL SUMMARY ===\n');
fprintf('%-8s %8s %8s %8s %8s\n', 'Site', 'Omega_R2', 'Hs2_corr', 'State_R2', 'Verdict');
for s = 1:4
    S = load(fullfile(L4dir, sites{s,1}));
    L4 = S.L4;

    Hs = L4.Hs_combined;
    Tp = nan(size(Hs));
    matched = L4.puv_valid;
    Tp(matched) = L4.Tp(matched);
    if isfield(L4, 'mop_Tp')
        gf = isnan(Tp) & ~isnan(L4.mop_Tp);
        Tp(gf) = L4.mop_Tp(gf);
    end
    Omega = Hs ./ (ws .* Tp);
    diseq = Omega - median(Omega, 'omitnan');

    bl = L4.bedlevel_mm;
    tt = L4.time;
    bl_sm = movmedian(bl, 18, 'omitnan');
    halfDay = 36;
    dzdt_day = nan(size(bl));
    for j = halfDay+1:numel(bl)-halfDay
        dt_hr = hours(tt(j+halfDay) - tt(j-halfDay));
        if dt_hr > 0 && dt_hr < 48 && ~isnan(bl_sm(j+halfDay)) && ~isnan(bl_sm(j-halfDay))
            dzdt_day(j) = (bl_sm(j+halfDay) - bl_sm(j-halfDay)) / dt_hr * 24;
        end
    end

    v1 = ~isnan(diseq) & ~isnan(dzdt_day);
    v2 = ~isnan(Hs.^2) & ~isnan(dzdt_day);
    v3 = ~isnan(bl_sm) & ~isnan(dzdt_day);

    r2_omega = 0; r2_hs2 = 0; r2_state = 0;
    if sum(v1) > 10, cc = corrcoef(diseq(v1), dzdt_day(v1)); r2_omega = cc(1,2)^2; end
    if sum(v2) > 10, cc = corrcoef(Hs(v2).^2, dzdt_day(v2)); r2_hs2 = cc(1,2)^2; end
    if sum(v3) > 10, cc = corrcoef(bl_sm(v3), dzdt_day(v3)); r2_state = cc(1,2)^2; end

    verdict = 'FAIL';
    if r2_omega > 0.1 || r2_state > 0.1, verdict = 'WEAK'; end
    if r2_omega > 0.3 && r2_state > 0.3, verdict = 'PASS'; end

    fprintf('%-8s %8.4f %8.4f %8.4f %8s\n', sites{s,2}, r2_omega, r2_hs2, r2_state, verdict);
end

exit;
