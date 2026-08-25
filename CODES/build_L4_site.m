function L4 = build_L4_site(L3root, pvuRoot, siteName, opts)
%BUILD_L4_SITE  Build full-site L4 merged product across all deployments.
%
% Chains all altimeter L3 files for a site, loads all matching PUV L2/L3
% files, and merges them into a single L4 struct spanning the full record.
%
% Inputs:
%   L3root   : directory containing altimeter L3 files (e.g. outputs/all)
%   pvuRoot  : PUV Pipeline outputs root (e.g. PUV_Pipeline/outputs)
%   siteName : 'SouthSIOPier', 'TorreyPines', or 'SolanaBeach'
%
% Optional name-value:
%   depths           : vector of depths to include (default: all)
%   pvuDeployments   : cell array of PUV deployment names to search
%   pvuLabel         : PUV instrument label (e.g. 'SIO_6m', 'MOP586_5m')
%   matchTolerance_min : max altimeter-burst-to-PUV time offset (default 15).
%                        PUV is hourly (burst center ~HH:29); altimeter burst
%                        centers are ~30-min and offset ~10 min from the PUV
%                        centers, so a 5-min tolerance matched ~nothing (0% at
%                        TP 5m). 15 min is below the 30-min PUV cadence and
%                        above the ~10-min center offset — matches the nearest
%                        altimeter burst to each PUV hour.
%   anchorMethod     : "survey" or "sequential" for chaining (default "sequential")
%   instrumentLat    : for survey anchoring
%   instrumentLon    : for survey anchoring
%   sensorElev_m     : known sensor elevation for sequential+absolute
%   savePath         : save L4 .mat to this path

arguments
    L3root (1,1) string
    pvuRoot (1,1) string
    siteName (1,1) string
    opts.depths (1,:) double = []
    opts.pvuDeployments cell = {}
    opts.pvuLabel (1,1) string = ""
    opts.matchTolerance_min (1,1) double = 15
    opts.anchorMethod (1,1) string = "sequential"
    opts.instrumentLat (1,1) double = NaN
    opts.instrumentLon (1,1) double = NaN
    opts.sensorElev_m (1,1) double = NaN
    opts.mopNumber (1,1) double = NaN    % override auto-detected MOP for surveys
    opts.mopStation (1,1) string = ""    % CDIP station code for MOP wave data (e.g. "D0511")
    opts.savePath (1,1) string = ""
    opts.grainSizeLabel (1,1) string = ""      % site_grain_size key; defaults to pvuLabel
    opts.requireGrainSize (1,1) logical = true   % error if site_grain_size has no entry
end

fprintf('\n=== Building L4 for %s ===\n', siteName);

%% -- Chain altimeter deployments ------------------------------------------
chainOpts = {'method', opts.anchorMethod};
if ~isempty(opts.depths)
    chainOpts = [chainOpts, 'depths', opts.depths];
end
if ~isnan(opts.instrumentLat)
    chainOpts = [chainOpts, 'instrumentLat', opts.instrumentLat, ...
                 'instrumentLon', opts.instrumentLon];
end
if ~isnan(opts.sensorElev_m)
    chainOpts = [chainOpts, 'sensorElev_m', opts.sensorElev_m];
end
if ~isnan(opts.mopNumber)
    chainOpts = [chainOpts, 'mopNumber', opts.mopNumber];
end

C = chain_deployments(L3root, siteName, chainOpts{:});
fprintf('  Altimeter: %d bursts, %s to %s\n', numel(C.time), ...
    string(C.time(1)), string(C.time(end)));

%% -- Load all PUV L2/L3 files --------------------------------------------
% Concatenate all PUV segments into one big time vector + field arrays
allPvuTime = datetime.empty(0,1);
allL2 = [];
allL3 = [];

if isempty(opts.pvuDeployments)
    % Auto-discover from pvuRoot/L2/
    d = dir(fullfile(pvuRoot, 'L2'));
    opts.pvuDeployments = {d([d.isdir] & ~startsWith({d.name}, '.')).name};
end

nPvuLoaded = 0;
for p = 1:numel(opts.pvuDeployments)
    depName = opts.pvuDeployments{p};

    % Find L2 file
    if opts.pvuLabel ~= ""
        l2File = fullfile(pvuRoot, 'L2', depName, opts.pvuLabel + "_L2.mat");
        l3File = fullfile(pvuRoot, 'L3', depName, opts.pvuLabel + "_L3.mat");
    else
        % Try to find any L2 file in this deployment
        l2Files = dir(fullfile(pvuRoot, 'L2', depName, '*_L2.mat'));
        if isempty(l2Files), continue; end
        l2File = fullfile(l2Files(1).folder, l2Files(1).name);
        l3Stem = strrep(l2Files(1).name, '_L2.mat', '_L3.mat');
        l3File = fullfile(pvuRoot, 'L3', depName, l3Stem);
    end

    if ~isfile(l2File), continue; end

    S2 = load(l2File); L2 = S2.L2;

    % PUV L2 times are tz-aware UTC; the chained altimeter times are tz-naive
    % but in UTC (the L1 readers convert raw->UTC). Strip the PUV zone so the
    % two are directly comparable (both naive-UTC). Both represent UTC, so
    % this is a label-only operation, not a value shift.
    if ~isempty(L2.time.TimeZone)
        L2.time.TimeZone = '';
    end

    if isfile(l3File)
        S3 = load(l3File); L3 = S3.L3;
    else
        L3 = [];
    end

    % Check temporal overlap with altimeter record
    pvuStart = L2.time(1); pvuEnd = L2.time(end);
    altStart = C.time(1); altEnd = C.time(end);

    if pvuEnd < altStart || pvuStart > altEnd
        continue  % no overlap
    end

    fprintf('  PUV %s: %d segments, %s to %s\n', depName, numel(L2.time), ...
        string(pvuStart), string(pvuEnd));

    % Store for matching
    nPvuLoaded = nPvuLoaded + 1;
    pvuData(nPvuLoaded).L2 = L2; %#ok
    pvuData(nPvuLoaded).L3 = L3; %#ok
    pvuData(nPvuLoaded).depName = depName; %#ok
end

if nPvuLoaded == 0
    warning('build_L4_site: no PUV data found with temporal overlap');
    L4 = [];
    return
end

%% -- Match each altimeter burst to nearest PUV segment --------------------
nBursts = numel(C.time);
tol = minutes(opts.matchTolerance_min);

matchPvuIdx  = nan(nBursts, 1);  % which PUV deployment
matchSegIdx  = nan(nBursts, 1);  % which segment within that deployment
matchDt      = nan(nBursts, 1);  % time offset in minutes

for k = 1:nBursts
    bestDt = inf;
    for p = 1:nPvuLoaded
        [dt, idx] = min(abs(pvuData(p).L2.time - C.time(k)));
        dtMin = minutes(dt);
        if dtMin < bestDt && dt <= tol
            bestDt = dtMin;
            matchPvuIdx(k) = p;
            matchSegIdx(k) = idx;
            matchDt(k) = dtMin;
        end
    end
end

% Per-burst PUV QC provenance (channel decoupling). A FAIL (qc_flag==4) segment must not
% contribute to any L4 field; a recovered/rescaled (qc_flag==3) segment may, but its flag
% travels so downstream can filter to clean-only (qc_flag==1). Backward-compatible with old
% L2 via l4_puv_qc: without these fields, everything reads as good and the historical L4 is
% reproduced exactly.
matchQC      = 2 * ones(nBursts, 1);   % default 2 = no match / not evaluated
matchSegVvel = false(nBursts, 1);
matchSegVp   = false(nBursts, 1);
matchUse     = false(nBursts, 1);      % may this match contribute to L4 fields?
for k = 1:nBursts
    if ~isnan(matchPvuIdx(k))
        q = l4_puv_qc(pvuData(matchPvuIdx(k)).L2, matchSegIdx(k));
        matchQC(k)      = q.qc_flag;
        matchSegVvel(k) = q.segValid_vel;
        matchSegVp(k)   = q.segValid_p;
        matchUse(k)     = q.use;
    end
end

nMatched = sum(~isnan(matchPvuIdx));
fprintf('  Matched: %d/%d bursts (%.0f%%), median dt=%.1f min\n', ...
    nMatched, nBursts, 100*nMatched/nBursts, median(matchDt(~isnan(matchDt))));

%% -- Build L4 struct ------------------------------------------------------
% Bed response (from chained altimeter)
L4.time            = C.time;
L4.bedlevel_mm     = C.bedlevel_mm;
L4.bedlevel_iqr_mm = C.bedlevel_iqr_mm;
L4.dzdt_mm_hr      = C.dzdt_mm_hr;
L4.altitude_mm     = C.altitude_mm;
L4.elevation_m     = C.elevation_m;
L4.pctValid        = C.pctValid;
L4.deploymentID    = C.deploymentID;

% Helper to extract a scalar field from the matched PUV L2
    function vals = getL2(fieldName)
        vals = nan(nBursts, 1);
        for i = 1:nBursts
            if matchUse(i)     % skip FAIL (qc_flag==4) segments; old L2 => always true
                vals(i) = pvuData(matchPvuIdx(i)).L2.(fieldName)(matchSegIdx(i));
            end
        end
    end

    function vals = getL2sub(structName, fieldName)
        vals = nan(nBursts, 1);
        for i = 1:nBursts
            if matchUse(i)
                vals(i) = pvuData(matchPvuIdx(i)).L2.(structName).(fieldName)(matchSegIdx(i));
            end
        end
    end

    function vals = getL3(fieldName)
        vals = nan(nBursts, 1);
        for i = 1:nBursts
            if matchUse(i) && ~isempty(pvuData(matchPvuIdx(i)).L3)
                vals(i) = pvuData(matchPvuIdx(i)).L3.(fieldName)(matchSegIdx(i));
            end
        end
    end

    function vals = getL3sub(structName, fieldName)
        vals = nan(nBursts, 1);
        for i = 1:nBursts
            if matchUse(i) && ~isempty(pvuData(matchPvuIdx(i)).L3)
                try
                    vals(i) = pvuData(matchPvuIdx(i)).L3.(structName).(fieldName)(matchSegIdx(i));
                catch
                end
            end
        end
    end

% Wave forcing — bulk
L4.Hs       = getL2('Hs');
L4.Hs_SS    = getL2('Hs_SS');
L4.Tp       = getL2('Tp');
L4.Ef       = getL2('Ef');
L4.depth    = getL2('depth');
L4.meanDir  = getL2('meanDir');

% Wave forcing — bed level
L4.Ub       = getL2('Ub');
L4.tau_b    = getL2('tau_b');
L4.Aw       = getL2('Aw');

% L3 derived
L4.Fb       = getL3('Fb');
L4.Fb_cum   = getL3('Fb_cum');
L4.shields  = getL3('shields');

L4.mobilized = false(nBursts, 1);
for i = 1:nBursts
    if matchUse(i) && ~isempty(pvuData(matchPvuIdx(i)).L3)
        try
            L4.mobilized(i) = pvuData(matchPvuIdx(i)).L3.mobilized(matchSegIdx(i));
        catch
        end
    end
end

% Velocity moments
L4.skewness  = getL2sub('vmom', 'skewness');
L4.asymmetry = getL2sub('vmom', 'asymmetry');
L4.u_abs3    = getL2sub('vmom', 'u_abs3');
L4.u_uabs2   = getL2sub('vmom', 'u_uabs2');

% Currents
L4.uMean = getL2('uMean');
L4.vMean = getL2('vMean');
L4.TKE   = getL2sub('reynolds', 'TKE');

% L3 subtidal + tidal
L4.subtidal_u  = getL3sub('subtidal', 'u');
L4.tidal_depth = getL3sub('tidal', 'depth_pred');

% Swell/sea fractions
L4.frac_swell = getL3('frac_swell');
L4.frac_sea   = getL3('frac_sea');
L4.Ef_swell   = L4.Ef .* L4.frac_swell;
L4.Ef_sea     = L4.Ef .* L4.frac_sea;

% Storm flag
L4.storm_flag = false(nBursts, 1);
for p = 1:nPvuLoaded
    if isempty(pvuData(p).L3), continue; end
    try
        if ~isempty(pvuData(p).L3.events.start)
            for e = 1:numel(pvuData(p).L3.events.start)
                inStorm = C.time >= pvuData(p).L3.events.start(e) & ...
                          C.time <= pvuData(p).L3.events.end_time(e);
                L4.storm_flag(inStorm) = true;
            end
        end
    catch
    end
end

% Quality
L4.puv_match_min = matchDt;
L4.puv_valid     = ~isnan(matchPvuIdx);   % a PUV segment matched in time (unchanged meaning)

% PUV QC provenance per burst (channel decoupling). On old L2 these are all "good" and
% reproduce the historical L4. On rerun L2:
%   puv_qc_flag = 1 clean, 3 recovered/rescaled (suspect -- e.g. velocity moments from a
%     segment whose pressure sensor had died), 4 fail (dropped from every L4 field above),
%     2 not evaluated / no match.
%   Consumers wanting CLEAN-ONLY forcing filter on puv_qc_flag == 1. Storm-peak velocity
%     moments recovered from sensor-block failures carry puv_qc_flag == 3 & puv_segValid_vel.
L4.puv_qc_flag      = matchQC;
L4.puv_segValid_vel = matchSegVvel;
L4.puv_segValid_p   = matchSegVp;
if any(matchQC == 4)
    fprintf('  PUV QC: %d matched bursts dropped as qc_flag=4 (implausible pressure)\n', sum(matchQC==4));
end
if any(matchQC == 3)
    fprintf('  PUV QC: %d matched bursts are qc_flag=3 (recovered/rescaled; filter to ==1 for clean-only)\n', sum(matchQC==3));
end

iqr99 = prctile(C.bedlevel_iqr_mm(~isnan(C.bedlevel_iqr_mm)), 99);
if iqr99 > 0
    L4.alt_quality = (C.pctValid / 100) .* max(0, 1 - C.bedlevel_iqr_mm / iqr99);
else
    L4.alt_quality = C.pctValid / 100;
end

% PUV deployment name per burst
L4.puv_deployment = strings(nBursts, 1);
for i = 1:nBursts
    if ~isnan(matchPvuIdx(i))
        L4.puv_deployment(i) = pvuData(matchPvuIdx(i)).depName;
    end
end

% Metadata
L4.site    = siteName;
L4.nBursts = nBursts;
L4.nMatched = nMatched;
L4.nPvuDeployments = nPvuLoaded;

%% -- MOP wave data (continuous, fills PUV gaps) ---------------------------
L4.mop_Hs = nan(nBursts, 1);
L4.mop_Tp = nan(nBursts, 1);

if opts.mopStation ~= "" && exist('read_MOPline2', 'file')
    try
        tStart = C.time(1) - days(1);
        tEnd   = C.time(end) + days(1);
        MOP = read_MOPline2(char(opts.mopStation), tStart, tEnd);
        if ~isempty(MOP) && isfield(MOP, 'time')
            if isdatetime(MOP.time)
                mopTime = MOP.time;
            else
                mopTime = datetime(MOP.time, 'ConvertFrom', 'datenum');
            end
            mopHs = double(MOP.Hs);
            if isfield(MOP, 'fp')
                mopTp = 1 ./ double(MOP.fp);
            elseif isfield(MOP, 'Tp')
                mopTp = double(MOP.Tp);
            else
                mopTp = nan(size(mopHs));
            end
            % Interpolate hourly MOP to burst timestamps
            L4.mop_Hs = interp1(mopTime, mopHs, C.time, 'linear', NaN);
            L4.mop_Tp = interp1(mopTime, mopTp, C.time, 'linear', NaN);
            nMop = sum(~isnan(L4.mop_Hs));
            fprintf('  MOP %s: %d hourly records, %d/%d bursts filled (%.0f%%)\n', ...
                opts.mopStation, numel(mopTime), nMop, nBursts, 100*nMop/nBursts);
        end
    catch ME
        fprintf('  MOP loading failed: %s\n', ME.message);
    end
end

% Use MOP Hs where PUV is missing (gap-fill)
L4.Hs_combined = L4.Hs;
L4.Hs_source   = strings(nBursts, 1);
L4.Hs_source(L4.puv_valid) = "PUV";
gapFilled = isnan(L4.Hs_combined) & ~isnan(L4.mop_Hs);
L4.Hs_combined(gapFilled) = L4.mop_Hs(gapFilled);
L4.Hs_source(gapFilled) = "MOP";
fprintf('  Hs coverage: %d PUV + %d MOP gap-fill = %d/%d (%.0f%%)\n', ...
    sum(L4.puv_valid), sum(gapFilled), sum(~isnan(L4.Hs_combined)), nBursts, ...
    100*sum(~isnan(L4.Hs_combined))/nBursts);

%% -- Continuous near-bed orbital velocity (Ub gap-fill) -------------------
% Where PUV exists, L4.Ub is the measured sea-swell-band (0.04-0.25 Hz) rms
% orbital velocity. In the gaps, reconstruct it from the MOP frequency
% spectrum via linear theory: shoal MOP spec1D from the MOP reference depth
% to the instrument nominal depth (energy-flux conservation), apply the
% near-bed velocity transfer (2*pi*f/sinh(kh))^2 per frequency, integrate the
% SS band. This spectral form matches the PUV's own-spectrum Ub at slope~1,
% R2~0.99 (validated 2026-05-22 across all deployments); the MOP-driven
% version validates at R2~0.7-0.9 (site-dependent; weakest at SIO/canyon),
% so a per-site calibration slope (measured = calib * model, fit on the PUV
% overlap) corrects the systematic bias before gap-filling.
L4.mop_Ub        = nan(nBursts, 1);
L4.Ub_calibration = NaN;
hNom = NaN;
if ~isempty(opts.depths) && isscalar(opts.depths), hNom = opts.depths; end
if exist('MOP','var') && isstruct(MOP) && isfield(MOP,'spec1D') && ...
        isfield(MOP,'frequency') && isfinite(hNom) && hNom > 0
    try
        if isdatetime(MOP.time), mt = MOP.time; else, mt = datetime(MOP.time,'ConvertFrom','datenum'); end
        fr = MOP.frequency(:); fbw = MOP.fbw(:); hm = MOP.depth;
        sp = MOP.spec1D; if size(sp,2) ~= numel(fr), sp = sp.'; end   % [nt_mop x nf]
        ss = fr >= 0.04 & fr <= 0.25; fb = fr(ss); wb = fbw(ss); om = 2*pi*fb;
        gg = 9.81;
        kP = om.^2/gg; for q = 1:120, kP = om.^2./(gg*tanh(kP*hNom)); end
        kM = om.^2/gg; for q = 1:120, kM = om.^2./(gg*tanh(kM*hm));   end
        cgP = 0.5*(1 + 2*kP*hNom./sinh(2*kP*hNom)).*(om./kP);
        cgM = 0.5*(1 + 2*kM*hm  ./sinh(2*kM*hm)  ).*(om./kM);
        Tf = (om./sinh(kP*hNom)).^2;     % near-bed velocity transfer at instrument depth
        shoal = cgM./cgP;                % S_inst(f) = S_mop(f) * Cg_mop/Cg_inst
        ubMop = nan(numel(mt),1);
        for it = 1:numel(mt)
            Spuv = sp(it,ss).' .* shoal;
            ubMop(it) = sqrt(sum(Tf .* Spuv .* wb, 'omitnan'));
        end
        L4.mop_Ub = interp1(mt, ubMop, C.time, 'linear', NaN);
    catch ME
        fprintf('  MOP Ub model failed: %s\n', ME.message);
    end
end

% Per-site calibration (measured = calib * model) over the PUV overlap, then blend
L4.Ub_combined = L4.Ub;
L4.Ub_source   = strings(nBursts, 1);
L4.Ub_source(L4.puv_valid & isfinite(L4.Ub)) = "PUV";
ovU = L4.puv_valid & isfinite(L4.Ub) & isfinite(L4.mop_Ub) & L4.mop_Ub > 0;
calib = 1;
if nnz(ovU) >= 30, calib = sum(L4.mop_Ub(ovU).*L4.Ub(ovU)) / sum(L4.mop_Ub(ovU).^2); end
L4.Ub_calibration = calib;
mopCal = calib * L4.mop_Ub;
gapU = isnan(L4.Ub_combined) & isfinite(mopCal);
L4.Ub_combined(gapU) = mopCal(gapU);
L4.Ub_source(gapU)   = "MOP";

% Continuous tau_b / shields from Ub_combined. Uses Swart (1974) piecewise
% f_w via PUV_Pipeline/shared/bed_stress_ks with the per-site Nikuradse
% roughness ks = 2.5*D84 (Wiberg & Smith 1991; from site_grain_size.m's
% measured PSD where available, log-linear depth extrapolation otherwise).
% D50 (also from site_grain_size) is used for Shields normalization. This is
% the data-anchored methodology adopted 2026-05-23 (Paper 2 audit). At PUV
% bursts, L4.tau_b (copied from L2) matches L4.tau_b_combined ONLY after the
% L2 spectral processing is recomputed with the same per-site ks (see
% /tmp/p2_recompute_L2_with_ks.m run 2026-05-23 + .bak_fw_d84 backups).
rho = 1025; rhos = 2650; gg = 9.81;
D50 = 0.00025; D84 = NaN; ks_m = NaN; gs_status = 'no_lookup';
% pvuLabel names the PUV L2/L3 FILE ("SIO_6m"); the grain-size table is keyed on
% SITE ("MOP511_6m"). They are different namespaces and coincide at Torrey only by
% accident. Overloading one parameter for both is what hid the SIO fallback.
gsLabel = opts.grainSizeLabel; if gsLabel == "", gsLabel = opts.pvuLabel; end
try
    gs = site_grain_size(char(gsLabel));
    D50 = gs.D50; D84 = gs.D84; ks_m = 2.5*D84; gs_status = char(gs.status);
catch ME
    % HARDENED 2026-08-24. This used to fall back to ks = 10*D50 with a default
    % D50, which is a DIFFERENT roughness formulation, not a degraded version of
    % the right one. It ran undetected at SIO for months because the pvuLabel
    % ("SIO_6m") did not match the table key ("MOP511_6m"). A build that cannot
    % resolve its grain size should stop, not guess.
    if opts.requireGrainSize
        error('build_L4_site:noGrainSize', ...
            ['No site_grain_size entry for "%s": %s\n' ...
             'Add the site to PUV_Pipeline/shared/site_grain_size.m, or pass ' ...
             'requireGrainSize=false to accept the ks=10*D50 fallback knowingly.'], ...
            char(gsLabel), ME.message);
    end
    warning('build_L4_site:noGrainSize', ...
        'No site_grain_size entry for "%s": %s. Falling back to ks=10*D50 with D50=%.0f um.', ...
        char(gsLabel), ME.message, D50*1e6);
    ks_m = 10*D50;
end
Trep = L4.Tp;                                   % measured peak period where PUV...
if isfield(L4,'mop_Tp'), Trep(~isfinite(Trep)) = L4.mop_Tp(~isfinite(Trep)); end  % ...MOP Tp in gaps
if exist('bed_stress_ks','file') ~= 2
    error('build_L4_site:noBedStress', ...
        'bed_stress_ks.m (PUV_Pipeline/shared) must be on the path for tau_b_combined.');
end
[L4.tau_b_combined, ~, L4.Aw_combined] = bed_stress_ks(L4.Ub_combined, Trep, ks_m, rho);
L4.shields_combined = L4.tau_b_combined / ((rhos - rho)*gg*D50);
L4.Ub_D50  = D50;
L4.Ub_D84  = D84;
L4.Ub_ks_m = ks_m;
L4.grain_size_status = string(gs_status);
fprintf('  Ub gap-fill: calib=%.3f, %d PUV + %d MOP = %d/%d (%.0f%%); tau_b_comb median %.2f Pa\n', ...
    calib, sum(L4.Ub_source=="PUV"), sum(L4.Ub_source=="MOP"), sum(L4.Ub_source~=""), nBursts, ...
    100*sum(L4.Ub_source~="")/nBursts, median(L4.tau_b_combined,'omitnan'));

% Summary
nStorm = sum(L4.storm_flag & L4.puv_valid);
fprintf('  L4 complete: %d bursts, %d with PUV (%.0f%%), %d during storms\n', ...
    nBursts, nMatched, 100*nMatched/nBursts, nStorm);

%% -- Save -----------------------------------------------------------------
if opts.savePath ~= ""
    save(opts.savePath, 'L4', '-v7.3');
    fprintf('  Saved: %s\n', opts.savePath);
end
end
