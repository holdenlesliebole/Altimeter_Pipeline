function BA = burst_average_echosounder(E, opts)
%BURST_AVERAGE_ECHOSOUNDER  Burst-averaged echosounder products.
%
% Same burst-median bed level as burst_average_altitude, plus aggregated
% backscatter profiles per burst (mean and max for suspension events).
%
% Inputs:
%   E    : echosounder struct (QC'd, from qc_echosounder output)
%          Fields: .time, .altitude_mm, .backscatter (NxM), .pitch_deg, .roll_deg
%
% Optional name-value:
%   burstSamples : 2048 (default, matches PUV L2)
%   minPctValid  : 50   (default)
%
% Output struct BA:
%   (all altitude fields from burst_average_altitude)
%   .backscatter_mean  (double, MxK) — mean backscatter profile per burst
%   .backscatter_max   (double, MxK) — max backscatter per burst (suspension events)
%   .pitch_mean        (double, Mx1) — mean pitch per burst
%   .roll_mean         (double, Mx1) — mean roll per burst

arguments
    E (1,1) struct
    opts.burstSamples (1,1) double = 2048
    opts.minPctValid (1,1) double = 50
end

% Altitude burst averaging (reuse the altitude function)
BA = burst_average_altitude(E.altitude_mm, E.time, ...
    "burstSamples", opts.burstSamples, "minPctValid", opts.minPctValid);

if BA.nBursts == 0
    BA.backscatter_mean = [];
    BA.backscatter_max  = [];
    BA.pitch_mean       = [];
    BA.roll_mean        = [];
    return
end

nBursts = BA.nBursts;
nBins   = size(E.backscatter, 2);

% Preallocate backscatter and tilt arrays
bsMean    = nan(nBursts, nBins);
bsMax     = nan(nBursts, nBins);
pitchMean = nan(nBursts, 1);
rollMean  = nan(nBursts, 1);

for k = 1:nBursts
    idx = (k-1)*opts.burstSamples + 1 : k*opts.burstSamples;

    % Backscatter: mean and max per bin across the burst
    bsSeg = E.backscatter(idx, :);
    bsMean(k, :) = mean(bsSeg, 1, "omitnan");
    bsMax(k, :)  = max(bsSeg, [], 1, "omitnan");

    % Tilt
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
