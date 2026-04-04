function BA = burst_average_altitude(alt_mm, t, opts)
%BURST_AVERAGE_ALTITUDE  Compute burst-median bed level and statistics.
%
% Handles two sampling modes automatically:
%   - Continuous (e.g., SIO altimeter at 2 Hz): divides into fixed-size
%     non-overlapping windows matched to PUV L2 segments (2048 samples).
%   - Burst mode (e.g., TP altimeter, 60 samples every 20 min): detects
%     gaps > gapThreshold_s and treats each physical burst as one window.
%
% Inputs:
%   alt_mm : altitude in mm (QC'd, with NaN at bad samples)
%   t      : datetime vector (same length as alt_mm)
%
% Optional name-value:
%   burstSamples   : 2048 (for continuous mode; ignored in burst mode)
%   minPctValid    : 50   (reject bursts with < 50% valid data)
%   gapThreshold_s : 10   (gaps longer than this → burst mode)
%
% Output struct BA:
%   .time            (datetime, Mx1) — burst midpoint times
%   .bedlevel_mm     (double, Mx1)   — median bed level per burst
%   .bedlevel_iqr_mm (double, Mx1)   — IQR within burst (noise/wave estimate)
%   .altitude_mm     (double, Mx1)   — median altitude per burst (raw distance)
%   .pctValid        (double, Mx1)   — fraction of non-NaN samples per burst
%   .dzdt_mm_hr      (double, Mx1)   — bed level change rate (mm/hr)
%   .nBursts         (scalar)
%   .burstSamples    (scalar)        — samples per burst (fixed or median)
%   .mode            (string)        — "continuous" or "burst"

arguments
    alt_mm (:,1) double
    t (:,1) datetime
    opts.burstSamples (1,1) double = 2048
    opts.minPctValid (1,1) double = 50
    opts.gapThreshold_s (1,1) double = 10
end

N = numel(alt_mm);
if N == 0
    BA = local_empty_struct(opts.burstSamples);
    return
end

%% -- Detect sampling mode -------------------------------------------------
dt = seconds(diff(t));
gapIdx = find(dt > opts.gapThreshold_s);

if numel(gapIdx) > 5  % more than 5 gaps → burst mode
    mode = "burst";
    % Each burst is the data between consecutive gaps
    burstStarts = [1; gapIdx + 1];
    burstEnds   = [gapIdx; N];
    nBursts = numel(burstStarts);
    medianBurstLen = median(burstEnds - burstStarts + 1);
    fprintf('  Burst averaging (burst mode): %d physical bursts, ~%d samples each\n', ...
        nBursts, round(medianBurstLen));
else
    mode = "continuous";
    nBursts = floor(N / opts.burstSamples);
    medianBurstLen = opts.burstSamples;
    % Build burst start/end indices for uniform windows
    burstStarts = (0:nBursts-1)' * opts.burstSamples + 1;
    burstEnds   = (1:nBursts)' * opts.burstSamples;
    fprintf('  Burst averaging (continuous): %d bursts of %d samples (%.0f min)\n', ...
        nBursts, opts.burstSamples, opts.burstSamples / 2 / 60);
end

if nBursts == 0
    BA = local_empty_struct(opts.burstSamples);
    return
end

%% -- Compute burst statistics ---------------------------------------------
burstTime   = NaT(nBursts, 1);
burstAlt    = nan(nBursts, 1);
burstIQR    = nan(nBursts, 1);
burstPctVal = nan(nBursts, 1);

for k = 1:nBursts
    idx = burstStarts(k) : burstEnds(k);
    seg = alt_mm(idx);
    tSeg = t(idx);

    burstTime(k) = tSeg(round(numel(idx) / 2));

    nValid = sum(~isnan(seg));
    burstPctVal(k) = 100 * nValid / numel(idx);

    if nValid == 0, continue; end

    burstAlt(k) = median(seg, "omitnan");
    burstIQR(k) = iqr(seg);
end

% Reject low-validity bursts
lowValid = burstPctVal < opts.minPctValid;
burstAlt(lowValid) = NaN;
burstIQR(lowValid) = NaN;

%% -- Bed level relative to first valid burst ------------------------------
firstValid = find(~isnan(burstAlt), 1, 'first');
if ~isempty(firstValid)
    baseline = burstAlt(firstValid);
    bedlevel = -(burstAlt - baseline);
else
    bedlevel = nan(size(burstAlt));
end

%% -- Bed level change rate (mm/hr) ----------------------------------------
dzdt = nan(nBursts, 1);
dt_hr = hours(diff(burstTime));
dz = diff(bedlevel);
dzdt(2:end) = dz ./ dt_hr;
% NaN out rates across large gaps (> 3x median burst interval)
if nBursts > 1
    medianInterval_hr = median(dt_hr, "omitnan");
    dzdt(dt_hr > 3 * medianInterval_hr) = NaN;
end

nRejected = sum(lowValid);
fprintf('  %d rejected (<%d%% valid), %d with valid bed level\n', ...
    nRejected, opts.minPctValid, sum(~isnan(bedlevel)));

%% -- Build output ---------------------------------------------------------
BA.time            = burstTime;
BA.bedlevel_mm     = bedlevel;
BA.bedlevel_iqr_mm = burstIQR;
BA.altitude_mm     = burstAlt;
BA.pctValid        = burstPctVal;
BA.dzdt_mm_hr      = dzdt;
BA.nBursts         = nBursts;
BA.burstSamples    = round(medianBurstLen);
BA.mode            = mode;
end

function BA = local_empty_struct(bs)
BA = struct('time', datetime.empty(0,1), 'bedlevel_mm', [], ...
    'bedlevel_iqr_mm', [], 'altitude_mm', [], 'pctValid', [], ...
    'dzdt_mm_hr', [], 'nBursts', 0, 'burstSamples', bs, 'mode', "");
end
