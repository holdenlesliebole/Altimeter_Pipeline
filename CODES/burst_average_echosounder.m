function BA = burst_average_echosounder(E, opts)
%BURST_AVERAGE_ECHOSOUNDER  Burst-averaged echosounder products.
%
% Same burst-median bed level as burst_average_altitude (with auto-detection
% of burst vs continuous mode), plus aggregated backscatter profiles and
% tilt per burst.
%
% Inputs:
%   E    : echosounder struct (QC'd, from qc_echosounder output)
%          Fields: .time, .altitude_mm, .backscatter (NxM), .pitch_deg, .roll_deg
%
% Optional name-value:
%   burstSamples   : 2048 (for continuous mode)
%   minPctValid    : 50
%   gapThreshold_s : 10
%
% Output struct BA:
%   (all altitude fields from burst_average_altitude)
%   .backscatter_mean  (double, MxK) — mean backscatter profile per burst
%   .backscatter_max   (double, MxK) — max backscatter per burst
%   .pitch_mean        (double, Mx1)
%   .roll_mean         (double, Mx1)

arguments
    E (1,1) struct
    opts.burstSamples (1,1) double = 2048
    opts.minPctValid (1,1) double = 50
    opts.gapThreshold_s (1,1) double = 10
end

% Altitude burst averaging (detects burst vs continuous mode)
BA = burst_average_altitude(E.altitude_mm, E.time, ...
    "burstSamples", opts.burstSamples, "minPctValid", opts.minPctValid, ...
    "gapThreshold_s", opts.gapThreshold_s);

if BA.nBursts == 0
    BA.backscatter_mean = [];
    BA.backscatter_max  = [];
    BA.pitch_mean       = [];
    BA.roll_mean        = [];
    return
end

nBursts = BA.nBursts;
N       = numel(E.time);
nBins   = size(E.backscatter, 2);

% Recompute burst boundaries (same logic as burst_average_altitude)
dt = seconds(diff(E.time));
gapIdx = find(dt > opts.gapThreshold_s);

if numel(gapIdx) > 5  % burst mode
    burstStarts = [1; gapIdx + 1];
    burstEnds   = [gapIdx; N];
else  % continuous mode
    burstStarts = (0:nBursts-1)' * opts.burstSamples + 1;
    burstEnds   = min((1:nBursts)' * opts.burstSamples, N);
end

% Preallocate
bsMean    = nan(nBursts, nBins);
bsMax     = nan(nBursts, nBins);
pitchMean = nan(nBursts, 1);
rollMean  = nan(nBursts, 1);

for k = 1:nBursts
    idx = burstStarts(k) : burstEnds(k);

    bsSeg = E.backscatter(idx, :);
    bsMean(k, :) = mean(bsSeg, 1, "omitnan");
    bsMax(k, :)  = max(bsSeg, [], 1, "omitnan");

    pitchMean(k) = mean(E.pitch_deg(idx), "omitnan");
    rollMean(k)  = mean(E.roll_deg(idx),  "omitnan");
end

% NaN out bursts rejected by altitude QC
lowValid = BA.pctValid < opts.minPctValid;
bsMean(lowValid, :) = NaN;
bsMax(lowValid, :)  = NaN;

BA.backscatter_mean = bsMean;
BA.backscatter_max  = bsMax;
BA.pitch_mean       = pitchMean;
BA.roll_mean        = rollMean;
end
