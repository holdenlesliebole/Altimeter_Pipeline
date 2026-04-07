function L4 = merge_puv_altimeter(BA, L2, L3, opts)
%MERGE_PUV_ALTIMETER  Merge altimeter burst-averaged bed level with PUV wave products.
%
% Creates an L4 struct with altimeter timestamps as backbone and PUV
% wave forcing matched by nearest-neighbor within a tolerance window.
%
% Inputs:
%   BA  : burst-averaged struct from altimeter L3 (burst_average_altitude output)
%   L2  : PUV L2 struct (from PUV_L2_spectral)
%   L3  : PUV L3 struct (from PUV_L3, contains shields, Fb, subtidal, etc.)
%
% Optional name-value:
%   matchTolerance_min : max time offset for nearest-neighbor match (default 5)
%   site               : site name string (default "")
%   mop                : MOP string (default "")
%   depth_m            : nominal depth (default NaN)
%   altDeployment      : altimeter deployment ID (default "")
%   pvuDeployment      : PUV deployment name (default "")
%
% Output struct L4: see puv_correlation_reconciled.md for full field list

arguments
    BA (1,1) struct
    L2 (1,1) struct
    L3 (1,1) struct
    opts.matchTolerance_min (1,1) double = 5
    opts.site (1,1) string = ""
    opts.mop (1,1) string = ""
    opts.depth_m (1,1) double = NaN
    opts.altDeployment (1,1) string = ""
    opts.pvuDeployment (1,1) string = ""
end

nBursts = numel(BA.time);
tol = minutes(opts.matchTolerance_min);

%% -- Nearest-neighbor matching --------------------------------------------
% For each altimeter burst, find the nearest PUV L2/L3 segment
pvuTime = L2.time;
if isempty(pvuTime) || isempty(BA.time)
    error('merge_puv_altimeter: empty time vectors');
end

matchIdx   = nan(nBursts, 1);
matchDt    = nan(nBursts, 1);  % minutes

for k = 1:nBursts
    [dt, idx] = min(abs(pvuTime - BA.time(k)));
    matchDt(k) = minutes(dt);
    if dt <= tol
        matchIdx(k) = idx;
    end
end

nMatched = sum(~isnan(matchIdx));
fprintf('  merge_puv_altimeter: %d/%d bursts matched (%.0f%%), median dt=%.1f min\n', ...
    nMatched, nBursts, 100*nMatched/nBursts, median(matchDt(~isnan(matchIdx))));

%% -- Build L4 struct ------------------------------------------------------

% Bed response (from altimeter)
L4.time            = BA.time;
L4.bedlevel_mm     = BA.bedlevel_mm;
L4.bedlevel_iqr_mm = BA.bedlevel_iqr_mm;
L4.dzdt_mm_hr      = BA.dzdt_mm_hr;
L4.altitude_mm     = BA.altitude_mm;
L4.pctValid        = BA.pctValid;

% Helper: extract field from L2 or L3 at matched indices
    function vals = match_field(src, fieldName)
        vals = nan(nBursts, 1);
        for i = 1:nBursts
            if ~isnan(matchIdx(i))
                vals(i) = src.(fieldName)(matchIdx(i));
            end
        end
    end

    function vals = match_substruct(src, structName, fieldName)
        vals = nan(nBursts, 1);
        for i = 1:nBursts
            if ~isnan(matchIdx(i))
                vals(i) = src.(structName).(fieldName)(matchIdx(i));
            end
        end
    end

% Wave forcing — bulk (L2)
L4.Hs       = match_field(L2, 'Hs');
L4.Hs_SS    = match_field(L2, 'Hs_SS');
L4.Tp       = match_field(L2, 'Tp');
L4.Ef       = match_field(L2, 'Ef');
L4.depth    = match_field(L2, 'depth');
L4.meanDir  = match_field(L2, 'meanDir');

% Wave forcing — bed level (L2 + L3)
L4.Ub       = match_field(L2, 'Ub');
L4.tau_b    = match_field(L2, 'tau_b');
L4.Aw       = match_field(L2, 'Aw');

% L3 derived products
L4.Fb       = match_field(L3, 'Fb');
L4.Fb_cum   = match_field(L3, 'Fb_cum');
L4.shields  = match_field(L3, 'shields');

% Mobilization flag
L4.mobilized = false(nBursts, 1);
for i = 1:nBursts
    if ~isnan(matchIdx(i))
        L4.mobilized(i) = L3.mobilized(matchIdx(i));
    end
end

% Velocity moments (L2)
L4.skewness  = match_substruct(L2, 'vmom', 'skewness');
L4.asymmetry = match_substruct(L2, 'vmom', 'asymmetry');
L4.u_abs3    = match_substruct(L2, 'vmom', 'u_abs3');
L4.u_uabs2   = match_substruct(L2, 'vmom', 'u_uabs2');

% Currents (L2 + L3)
L4.uMean = match_field(L2, 'uMean');
L4.vMean = match_field(L2, 'vMean');
L4.TKE   = match_substruct(L2, 'reynolds', 'TKE');

% Subtidal currents (L3)
if isfield(L3, 'subtidal') && isfield(L3.subtidal, 'u')
    L4.subtidal_u = match_substruct(L3, 'subtidal', 'u');
else
    L4.subtidal_u = nan(nBursts, 1);
end

% Tidal depth (L3)
if isfield(L3, 'tidal') && isfield(L3.tidal, 'depth_pred')
    L4.tidal_depth = match_substruct(L3, 'tidal', 'depth_pred');
else
    L4.tidal_depth = nan(nBursts, 1);
end

% Swell vs sea energy fraction (L3)
% L3.bands contains frequency limits [fLo fHi], not time series.
% L3.frac_swell/frac_sea are the fractional contributions per segment.
% Compute band Ef as fraction × total Ef.
if isfield(L3, 'frac_swell')
    L4.frac_swell = match_field(L3, 'frac_swell');
    L4.frac_sea   = match_field(L3, 'frac_sea');
    L4.Ef_swell   = L4.Ef .* L4.frac_swell;
    L4.Ef_sea     = L4.Ef .* L4.frac_sea;
else
    L4.frac_swell = nan(nBursts, 1);
    L4.frac_sea   = nan(nBursts, 1);
    L4.Ef_swell   = nan(nBursts, 1);
    L4.Ef_sea     = nan(nBursts, 1);
end

% Storm flag (L3 events)
L4.storm_flag = false(nBursts, 1);
try
    if isfield(L3, 'events') && ~isempty(L3.events.start)
        for e = 1:numel(L3.events.start)
            inStorm = BA.time >= L3.events.start(e) & BA.time <= L3.events.end_time(e);
            L4.storm_flag(inStorm) = true;
        end
    end
catch
    % events struct empty or incompatible — no storm flags
end

% Quality
L4.puv_match_min = matchDt;
L4.puv_valid     = ~isnan(matchIdx);

% Composite altimeter quality (0-1, higher = better)
iqr99 = prctile(BA.bedlevel_iqr_mm(~isnan(BA.bedlevel_iqr_mm)), 99);
if iqr99 > 0
    L4.alt_quality = (BA.pctValid / 100) .* max(0, 1 - BA.bedlevel_iqr_mm / iqr99);
else
    L4.alt_quality = BA.pctValid / 100;
end

% Metadata
L4.site           = opts.site;
L4.mop            = opts.mop;
L4.depth_m        = opts.depth_m;
L4.alt_deployment = opts.altDeployment;
L4.puv_deployment = opts.pvuDeployment;
L4.doffp          = L2.doffp;
if isfield(L3, 'transport_params')
    L4.D50 = L3.transport_params.D50;
else
    L4.D50 = NaN;
end

% Summary
nStorm = sum(L4.storm_flag & L4.puv_valid);
fprintf('  L4: %d bursts, %d with PUV, %d during storms, doffp=%.2fm\n', ...
    nBursts, nMatched, nStorm, L4.doffp);
end
