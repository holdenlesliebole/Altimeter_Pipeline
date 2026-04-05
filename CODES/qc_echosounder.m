function [E, qf] = qc_echosounder(E, params)
%QC_ECHOSOUNDER Apply QC to echosounder altitude + optionally mask backscatter.
%
% Tilt masking uses deviation from baseline (median) pitch/roll, not
% absolute values.  This handles instruments installed with a static tilt
% offset (common when pipes are not perfectly vertical).
%
% Params (optional name-value):
%   "tilt_deg"           (default 2)      deviation from median pitch/roll to flag
%   "altitudeParams"     (default struct)  passed to qc_altitude
%   "rangeResolution_m"  (default 0.0075)  depth bin spacing for below-bed mask
%   "correctTilt"        (default true)    apply geometric tilt correction to altitude
%
% Tilt correction:
%   A tilted sensor overestimates the distance to bed by a factor of
%   1/cos(tilt). For a 13 deg tilt, this is ~2.6% (~24 mm at 900 mm
%   altitude). The correction uses the per-ping total tilt angle:
%     altitude_corrected = altitude_measured * cos(totalTilt)
%   This is a constant offset for stable tilt, so it does NOT affect
%   relative bed level change (Δz). It matters for absolute elevation
%   comparisons against surveys.
%
% Outputs:
%   E  : struct with altitude_mm corrected and masked, backscatter masked
%   qf : struct with fields:
%          qf_altitude (uint16 bitmask from qc_altitude)
%          maskTilt    (logical, true = flagged by tilt deviation)
%          pitch_baseline_deg, roll_baseline_deg (median tilt)
%          tilt_correction_mm (median correction applied, for reference)

arguments
    E (1,1) struct
    params.tilt_deg (1,1) double = 2
    params.altitudeParams = struct()
    params.rangeResolution_m (1,1) double = 0.0075
    params.correctTilt (1,1) logical = true
end

% Altitude QC (despike, zeros, jumps)
altNV = namedargs2cell(params.altitudeParams);
[E.altitude_mm, qf_alt] = qc_altitude(E.altitude_mm, E.time, altNV{:});

% Geometric tilt correction: altitude_true = altitude_measured * cos(tilt)
pitch_baseline = median(E.pitch_deg, "omitnan");
roll_baseline  = median(E.roll_deg,  "omitnan");
totalTilt_deg  = sqrt(E.pitch_deg.^2 + E.roll_deg.^2);
tilt_correction_mm = 0;

if params.correctTilt
    cosFactor = cos(deg2rad(totalTilt_deg));
    medianCorr = median(E.altitude_mm .* (1 - cosFactor), "omitnan");
    E.altitude_mm = E.altitude_mm .* cosFactor;
    tilt_correction_mm = medianCorr;
end

% Tilt QC: mask deviations from baseline (median) pitch and roll

pitch_dev = abs(E.pitch_deg - pitch_baseline);
roll_dev  = abs(E.roll_deg  - roll_baseline);

maskTilt = pitch_dev > params.tilt_deg | roll_dev > params.tilt_deg;
E.altitude_mm(maskTilt) = NaN;

if isfield(E, "backscatter") && ~isempty(E.backscatter)
    E.backscatter(maskTilt, :) = NaN;

    % Mask backscatter bins beyond the bed (below-bed returns are not valid)
    nBins = size(E.backscatter, 2);
    binRange_m = (0:nBins-1)' * params.rangeResolution_m;  % range of each bin from sensor
    alt_m = E.altitude_mm / 1000;  % per-ping altitude in meters

    % For each ping, bins where range > altitude are below the bed
    binRangeMatrix = repmat(binRange_m', numel(alt_m), 1);  % N x nBins
    altMatrix      = repmat(alt_m, 1, nBins);                % N x nBins
    belowBed       = binRangeMatrix > altMatrix;

    % Pings with no altitude (no bed echo) — entire profile is unreliable
    noEcho = isnan(alt_m);
    belowBed(noEcho, :) = true;

    E.backscatter(belowBed) = NaN;
end

qf = struct();
qf.qf_altitude = qf_alt;
qf.maskTilt = maskTilt;
qf.pitch_baseline_deg = pitch_baseline;
qf.roll_baseline_deg  = roll_baseline;
qf.tilt_correction_mm = tilt_correction_mm;

% Report baseline tilt
baselineTilt = sqrt(pitch_baseline^2 + roll_baseline^2);
if baselineTilt > 2
    if params.correctTilt
        fprintf('  QC: baseline tilt = %.1f deg (pitch=%.1f, roll=%.1f) — corrected (%.1f mm), masking deviations > %.1f deg\n', ...
            baselineTilt, pitch_baseline, roll_baseline, tilt_correction_mm, params.tilt_deg);
    else
        fprintf('  QC: baseline tilt = %.1f deg (pitch=%.1f, roll=%.1f) — NOT corrected, masking deviations > %.1f deg\n', ...
            baselineTilt, pitch_baseline, roll_baseline, params.tilt_deg);
    end
end
end
