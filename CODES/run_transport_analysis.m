addpath('/Users/holden/Documents/Scripps/Research/Altimeter_Pipeline/CODES');

L4dir = '/Users/holden/Documents/Scripps/Research/Altimeter_Pipeline/outputs/L4';
figDir = '/Users/holden/Documents/Scripps/Research/Altimeter_Pipeline/outputs/figures';

sites = {
    'L4_SIO_6m.mat', 'SIO 6m', 6;
    'L4_TP_5m.mat',  'TP 5m',  5;
    'L4_TP_10m.mat', 'TP 10m', 10;
    'L4_TP_15m.mat', 'TP 15m', 15;
};
colors = [0.18 0.45 0.75; 0.85 0.33 0.1; 0.47 0.67 0.19; 0.49 0.18 0.56];

%% === 1. CHECK GRAIN SIZE AND SOULSBY THRESHOLD ===
fprintf('=== Grain Size and Theoretical Thresholds ===\n');
rho_s = 2650; rho_w = 1025; g = 9.81; nu = 1.05e-6;

for s = 1:4
    S = load(fullfile(L4dir, sites{s,1}));
    L4 = S.L4;
    
    D50 = 0.25e-3;
    if isnan(D50), D50 = 0.25e-3; end  % default placeholder
    
    % Soulsby (1997) critical Shields: theta_cr = 0.30/(1+1.2*Dstar) + 0.055*(1-exp(-0.020*Dstar))
    Dstar = D50 * ((rho_s/rho_w - 1) * g / nu^2)^(1/3);
    theta_cr_soulsby = 0.30 / (1 + 1.2*Dstar) + 0.055 * (1 - exp(-0.020*Dstar));
    tau_cr_soulsby = theta_cr_soulsby * (rho_s - rho_w) * g * D50;
    
    % Observed threshold from our data
    matched = L4.puv_valid & ~isnan(L4.shields);
    theta_med = median(L4.shields(matched), 'omitnan');
    
    fprintf('  %s: D50=%.2fmm, Dstar=%.1f, theta_cr_Soulsby=%.4f (tau=%.3f Pa)\n', ...
        sites{s,2}, D50*1000, Dstar, theta_cr_soulsby, tau_cr_soulsby);
    fprintf('         theta_median_observed=%.4f, mobilized=%.0f%%\n', ...
        theta_med, 100*mean(L4.mobilized(matched)));
end

%% === 2. TRANSPORT RATE: dz/dt vs EXCESS SHIELDS ===
fprintf('\n=== Transport Rate Fitting: |dz/dt| = a * (theta - theta_cr)^n ===\n');

fig1 = figure('Color','w','Visible','off','Position',[50 50 1200 500]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

% Panel 1: |dz/dt| vs excess Shields (all depths)
nexttile
for s = 1:4
    S = load(fullfile(L4dir, sites{s,1}));
    L4 = S.L4;
    
    matched = L4.puv_valid & ~isnan(L4.dzdt_mm_hr) & ~isnan(L4.shields);
    theta = L4.shields(matched);
    dzdt = abs(L4.dzdt_mm_hr(matched));
    
    % Use Soulsby theta_cr for this grain size
    D50 = 0.25e-3; if isnan(D50), D50 = 0.25e-3; end
    Dstar = D50 * ((rho_s/rho_w - 1) * g / nu^2)^(1/3);
    theta_cr = 0.30 / (1 + 1.2*Dstar) + 0.055 * (1 - exp(-0.020*Dstar));
    
    excess = max(0, theta - theta_cr);
    
    % Bin by excess Shields
    nBins = 15;
    edges = linspace(0, prctile(excess(excess>0), 95), nBins+1);
    binC = (edges(1:end-1)+edges(2:end))/2;
    binMean = nan(nBins,1);
    for b = 1:nBins
        inBin = excess >= edges(b) & excess < edges(b+1);
        if sum(inBin) >= 10, binMean(b) = mean(dzdt(inBin)); end
    end
    
    v = find(~isnan(binMean) & binC(:) > 0);
    plot(binC(v), binMean(v), 'o-', 'Color', colors(s,:), ...
        'MarkerFaceColor', colors(s,:), 'LineWidth', 1.2, 'DisplayName', sites{s,2});
    hold on
    
    % Power law fit on binned data
    if sum(v) >= 3
        xfit = log(binC(v));
        yfit = log(binMean(v));
        p = polyfit(xfit, yfit, 1);
        n_exp = p(1);
        a_coeff = exp(p(2));
        fprintf('  %s: |dz/dt| = %.1f * (theta-theta_cr)^%.2f\n', sites{s,2}, a_coeff, n_exp);
    end
end
xlabel('Excess Shields (\theta - \theta_{cr})');
ylabel('Mean |dz/dt| (mm/hr)');
title('Transport rate vs excess Shields parameter');
legend('Location','northwest');
set(gca, 'XScale', 'log', 'YScale', 'log');
grid on

% Panel 2: dz/dt SIGNED — accretion vs erosion
nexttile
for s = 1:4
    S = load(fullfile(L4dir, sites{s,1}));
    L4 = S.L4;
    
    matched = L4.puv_valid & ~isnan(L4.dzdt_mm_hr) & ~isnan(L4.tau_b);
    tau = L4.tau_b(matched);
    dzdt = L4.dzdt_mm_hr(matched);  % signed
    
    nBins = 20;
    edges = linspace(0, prctile(tau, 99), nBins+1);
    binC = (edges(1:end-1)+edges(2:end))/2;
    binMeanPos = nan(nBins,1);  % mean accretion rate
    binMeanNeg = nan(nBins,1);  % mean erosion rate
    
    for b = 1:nBins
        inBin = tau >= edges(b) & tau < edges(b+1);
        pos = dzdt(inBin) > 0;
        neg = dzdt(inBin) < 0;
        if sum(inBin) >= 10, dz_bin = dzdt(inBin); binMeanPos(b) = mean(dz_bin(dz_bin>0)); end
        dz_bin = dzdt(inBin); if any(dz_bin<0), binMeanNeg(b) = mean(dz_bin(dz_bin<0)); end
    end
    
    v = ~isnan(binMeanPos);
    plot(binC(v), binMeanPos(v), 'o-', 'Color', colors(s,:), ...
        'MarkerFaceColor', colors(s,:), 'LineWidth', 1.0, ...
        'DisplayName', [sites{s,2} ' accretion']);
    hold on
    v = ~isnan(binMeanNeg);
    plot(binC(v), binMeanNeg(v), 's--', 'Color', colors(s,:), ...
        'MarkerFaceColor', 'none', 'LineWidth', 1.0, ...
        'DisplayName', [sites{s,2} ' erosion']);
end
xlabel('\tau_b (Pa)'); ylabel('Mean dz/dt (mm/hr)');
title('Accretion vs erosion rate by shear stress');
yline(0, 'k-', 'HandleVisibility','off');
legend('Location','southwest','FontSize',7);
grid on

exportgraphics(fig1, fullfile(figDir, 'transport_rate_fitting.png'), 'Resolution', 150);
close(fig1);
fprintf('Saved transport_rate_fitting.png\n');

%% === 3. VELOCITY MOMENTS — does skewness drive net transport? ===
fprintf('\n=== Velocity Moment Analysis ===\n');

fig2 = figure('Color','w','Visible','off','Position',[50 50 1200 500]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

% Panel 1: dz/dt vs skewness
nexttile
for s = 1:4
    S = load(fullfile(L4dir, sites{s,1}));
    L4 = S.L4;
    matched = L4.puv_valid & ~isnan(L4.dzdt_mm_hr) & ~isnan(L4.skewness);
    sk = L4.skewness(matched);
    dzdt = L4.dzdt_mm_hr(matched);
    
    nBins = 15;
    edges = linspace(prctile(sk,2), prctile(sk,98), nBins+1);
    binC = (edges(1:end-1)+edges(2:end))/2;
    binMean = nan(nBins,1);
    for b = 1:nBins
        inBin = sk >= edges(b) & sk < edges(b+1);
        if sum(inBin) >= 10, binMean(b) = mean(dzdt(inBin)); end
    end
    v = ~isnan(binMean);
    plot(binC(v), binMean(v), 'o-', 'Color', colors(s,:), ...
        'MarkerFaceColor', colors(s,:), 'LineWidth', 1.2, 'DisplayName', sites{s,2});
    hold on
end
xlabel('Velocity skewness'); ylabel('Mean dz/dt (mm/hr)');
title('Bed change rate vs velocity skewness');
yline(0, 'k-', 'HandleVisibility','off');
legend('Location','best');
grid on

% Panel 2: dz/dt vs u|u|^2 moment
nexttile
for s = 1:4
    S = load(fullfile(L4dir, sites{s,1}));
    L4 = S.L4;
    matched = L4.puv_valid & ~isnan(L4.dzdt_mm_hr) & ~isnan(L4.u_uabs2);
    uuabs2 = L4.u_uabs2(matched);
    dzdt = L4.dzdt_mm_hr(matched);
    
    nBins = 15;
    edges = linspace(prctile(uuabs2,2), prctile(uuabs2,98), nBins+1);
    binC = (edges(1:end-1)+edges(2:end))/2;
    binMean = nan(nBins,1);
    for b = 1:nBins
        inBin = uuabs2 >= edges(b) & uuabs2 < edges(b+1);
        if sum(inBin) >= 10, binMean(b) = mean(dzdt(inBin)); end
    end
    v = ~isnan(binMean);
    plot(binC(v), binMean(v), 'o-', 'Color', colors(s,:), ...
        'MarkerFaceColor', colors(s,:), 'LineWidth', 1.2, 'DisplayName', sites{s,2});
    hold on
end
xlabel('<u|u|^2> (m^3/s^3)'); ylabel('Mean dz/dt (mm/hr)');
title('Bed change rate vs velocity moment u|u|^2');
yline(0, 'k-', 'HandleVisibility','off');
legend('Location','best');
grid on

exportgraphics(fig2, fullfile(figDir, 'velocity_moments.png'), 'Resolution', 150);
close(fig2);
fprintf('Saved velocity_moments.png\n');

%% === 4. DEPTH-DEPENDENT TRANSPORT EFFICIENCY ===
fprintf('\n=== Transport Efficiency by Depth ===\n');
fig3 = figure('Color','w','Visible','off','Position',[50 50 600 450]);

depthVals = [6, 5, 10, 15];
meanDzdt = nan(4,1);
meanTaub = nan(4,1);
meanUb = nan(4,1);

for s = 1:4
    S = load(fullfile(L4dir, sites{s,1}));
    L4 = S.L4;
    matched = L4.puv_valid & ~isnan(L4.dzdt_mm_hr);
    meanDzdt(s) = mean(abs(L4.dzdt_mm_hr(matched)), 'omitnan');
    meanTaub(s) = mean(L4.tau_b(matched), 'omitnan');
    meanUb(s) = mean(L4.Ub(matched), 'omitnan');
    fprintf('  %s: mean |dz/dt|=%.1f mm/hr, mean tau_b=%.2f Pa, mean Ub=%.3f m/s\n', ...
        sites{s,2}, meanDzdt(s), meanTaub(s), meanUb(s));
end

% Transport efficiency = mean|dz/dt| / mean tau_b
efficiency = meanDzdt ./ meanTaub;
bar(categorical({'SIO 6m','TP 5m','TP 10m','TP 15m'}), efficiency);
ylabel('Transport efficiency (mm/hr per Pa)');
title('Depth-dependent transport efficiency');
grid on

for k = 1:4
    text(k, efficiency(k)+0.2, sprintf('%.1f', efficiency(k)), ...
        'HorizontalAlignment','center', 'FontSize',11);
end

exportgraphics(fig3, fullfile(figDir, 'transport_efficiency.png'), 'Resolution', 150);
close(fig3);
fprintf('Saved transport_efficiency.png\n');

exit;
