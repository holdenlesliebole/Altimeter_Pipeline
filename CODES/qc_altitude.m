function [x_mm, qf] = qc_altitude(x_mm, t, params)
%QC_ALTITUDE Basic despiking/QC for altitude time series.
%
% Inputs
%   x_mm   : altitude in mm (distance from sensor to bed)
%   t      : datetime vector (same length as x_mm)
%   params : struct with fields (all optional):
%       .removeZeros (default true)
%       .maxValid_mm (default inf)
%       .minValid_mm (default -inf)
%       .winMovMean  (default minutes(15))
%       .thr1_mm     (default 200)
%       .thr2_mm     (default 100)
%       .jump_mm     (default 10)
%       .useHampel   (default false)
%       .hampelWin   (default minutes(15))
%       .hampelSigma (default 3)
%
% Outputs
%   x_mm : cleaned altitude (NaNs inserted)
%   qf   : quality flag bitmask (uint16):
%       bit1 = removed (zero/invalid range)
%       bit2 = movmean despike
%       bit3 = jump/neighbor spike
%       bit4 = hampel

arguments
    x_mm (:,1) double
    t (:,1) datetime
    params.removeZeros (1,1) logical = true
    params.maxValid_mm (1,1) double = inf
    params.minValid_mm (1,1) double = -inf
    params.winMovMean = minutes(15)
    params.thr1_mm (1,1) double = 200
    params.thr2_mm (1,1) double = 100
    params.jump_mm (1,1) double = 10
    params.useHampel (1,1) logical = false
    params.hampelWin = minutes(15)
    params.hampelSigma (1,1) double = 3
end

qf = zeros(size(x_mm), "uint16");

% bit1: invalid/zero
bad = false(size(x_mm));
if params.removeZeros
    bad = bad | (x_mm == 0);
end
bad = bad | (x_mm < params.minValid_mm) | (x_mm > params.maxValid_mm) | isnan(x_mm);
qf(bad) = bitor(qf(bad), uint16(1));
x_mm(bad) = NaN;

% Determine sampling interval and convert duration windows to samples
dt = median(seconds(diff(t)), "omitnan");
if ~isfinite(dt) || dt <= 0
    % Fall back to 2 Hz assumption
    dt = 0.5;
end
win1 = max(3, round(seconds(params.winMovMean) / dt));

% bit2: moving-mean despike (two-pass like your scripts)
m1 = movmean(x_mm, win1, "omitnan");
sp1 = abs(x_mm - m1) > params.thr1_mm;
x_mm(sp1) = NaN;
qf(sp1) = bitor(qf(sp1), uint16(2));

m2 = movmean(x_mm, win1, "omitnan");
sp2 = abs(x_mm - m2) > params.thr2_mm;
x_mm(sp2) = NaN;
qf(sp2) = bitor(qf(sp2), uint16(2));

% bit3: jump filter (vectorized version of neighbor loop)
d1 = [0; abs(diff(x_mm))];
d2 = [abs(diff(x_mm)); 0];
spJump = (d1 > params.jump_mm) | (d2 > params.jump_mm);
x_mm(spJump) = NaN;
qf(spJump) = bitor(qf(spJump), uint16(4));

% bit4: optional Hampel (robust to spikes)
if params.useHampel
    winH = max(3, round(seconds(params.hampelWin) / dt));
    [x2, isOut] = hampel(x_mm, winH, params.hampelSigma);
    % hampel replaces outliers; we want to NaN them so the caller can decide
    x_mm(isOut) = NaN;
    qf(isOut) = bitor(qf(isOut), uint16(8));
end
end
