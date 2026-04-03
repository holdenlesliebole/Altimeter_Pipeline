function BA = burst_average_altitude(alt_mm, t, opts)
%BURST_AVERAGE_ALTITUDE  Compute burst-median bed level and statistics.
%
% Divides the altitude time series into non-overlapping windows matched to
% the PUV L2 segment length (2048 samples @ 2 Hz = 17.07 min). For each
% burst, computes the median bed level (robust to wave-frequency oscillations
% and remaining spikes), the IQR (measurement noise estimate), and the bed
% level change rate between consecutive bursts.
%
% Inputs:
%   alt_mm : altitude in mm (QC'd, with NaN at bad samples)
%   t      : datetime vector (same length as alt_mm)
%
% Optional name-value:
%   burstSamples : 2048 (default, matches PUV L2)
%   minPctValid  : 50   (default, reject bursts with < 50% valid data)
%
% Output struct BA:
%   .time            (datetime, Mx1) — burst midpoint times
%   .bedlevel_mm     (double, Mx1)   — median bed level per burst
%   .bedlevel_iqr_mm (double, Mx1)   — IQR within burst (noise/wave estimate)
%   .altitude_mm     (double, Mx1)   — median altitude per burst (raw distance)
%   .pctValid        (double, Mx1)   — fraction of non-NaN samples per burst
%   .dzdt_mm_hr      (double, Mx1)   — bed level change rate (mm/hr, NaN at edges)
%   .nBursts         (scalar)
%   .burstSamples    (scalar)        — samples per burst used

arguments
    alt_mm (:,1) double
    t (:,1) datetime
    opts.burstSamples (1,1) double = 2048
    opts.minPctValid (1,1) double = 50
end

N = numel(alt_mm);
nBursts = floor(N / opts.burstSamples);

if nBursts == 0
    BA = struct('time', datetime.empty(0,1), 'bedlevel_mm', [], ...
        'bedlevel_iqr_mm', [], 'altitude_mm', [], 'pctValid', [], ...
        'dzdt_mm_hr', [], 'nBursts', 0, 'burstSamples', opts.burstSamples);
    return
end

% Preallocate
burstTime   = NaT(nBursts, 1);
burstAlt    = nan(nBursts, 1);
burstIQR    = nan(nBursts, 1);
burstPctVal = nan(nBursts, 1);

for k = 1:nBursts
    idx = (k-1)*opts.burstSamples + 1 : k*opts.burstSamples;
    seg = alt_mm(idx);
    tSeg = t(idx);

    % Burst midpoint time
    burstTime(k) = tSeg(round(opts.burstSamples / 2));

    % Fraction valid
    nValid = sum(~isnan(seg));
    burstPctVal(k) = 100 * nValid / opts.burstSamples;

    if nValid == 0
        continue
    end

    burstAlt(k) = median(seg, "omitnan");
    burstIQR(k) = iqr(seg);
end

% Reject low-validity bursts
lowValid = burstPctVal < opts.minPctValid;
burstAlt(lowValid) = NaN;
burstIQR(lowValid) = NaN;

% Bed level: relative to first valid burst median (stable baseline)
firstValid = find(~isnan(burstAlt), 1, 'first');
if ~isempty(firstValid)
    baseline = burstAlt(firstValid);
    bedlevel = -(burstAlt - baseline);  % erosion negative, accretion positive
else
    bedlevel = nan(size(burstAlt));
end

% Bed level change rate (mm/hr)
dzdt = nan(nBursts, 1);
dt_hr = hours(diff(burstTime));
dz = diff(bedlevel);
dzdt(2:end) = dz ./ dt_hr;
% NaN out rates computed across gaps (where dt > 2x expected burst interval)
expectedInterval_hr = opts.burstSamples / 2 / 3600;  % at 2 Hz
dzdt(dt_hr > 2 * expectedInterval_hr) = NaN;

% Build output
BA.time            = burstTime;
BA.bedlevel_mm     = bedlevel;
BA.bedlevel_iqr_mm = burstIQR;
BA.altitude_mm     = burstAlt;
BA.pctValid        = burstPctVal;
BA.dzdt_mm_hr      = dzdt;
BA.nBursts         = nBursts;
BA.burstSamples    = opts.burstSamples;

fprintf('  Burst averaging: %d bursts (%.0f min each), %d rejected (<%d%% valid)\n', ...
    nBursts, opts.burstSamples/2/60, sum(lowValid), opts.minPctValid);
end
