function [x_mm, qf] = qc_altitude(x_mm, t, params)
%QC_ALTITUDE  Despike and QC an altitude time series.
%
% Two despiking methods available:
%   "phasespace" (default) — Goring & Nikora (2002) phase-space threshold,
%       parameter-free. Uses the data's own phase-space structure to identify
%       spikes. Recommended for research use.
%   "movmean" — legacy 2-pass moving-mean + jump filter with hand-tuned
%       thresholds. Preserved for backward compatibility.
%
% Inputs
%   x_mm   : altitude in mm (distance from sensor to bed)
%   t      : datetime vector (same length as x_mm)
%
% Optional name-value parameters:
%   method       : "phasespace" (default) or "movmean"
%   removeZeros  : true (default) — NaN out zero-altitude readings
%   maxValid_mm  : inf  — upper range limit
%   minValid_mm  : -inf — lower range limit
%   useHampel    : false — optional post-despike Hampel filter
%   hampelWin    : minutes(15)
%   hampelSigma  : 3
%   (movmean-only parameters:)
%   winMovMean   : minutes(15)
%   thr1_mm      : 200
%   thr2_mm      : 100
%   jump_mm      : 10
%
% Outputs
%   x_mm : cleaned altitude (NaNs at flagged samples)
%   qf   : quality flag bitmask (uint16):
%       bit1 = removed (zero/invalid range)
%       bit2 = despike (phase-space or moving-mean)
%       bit3 = jump filter (movmean method only)
%       bit4 = Hampel

arguments
    x_mm (:,1) double
    t (:,1) datetime
    params.method (1,1) string = "phasespace"
    params.removeZeros (1,1) logical = true
    params.maxValid_mm (1,1) double = inf
    params.minValid_mm (1,1) double = -inf
    params.useHampel (1,1) logical = false
    params.hampelWin = minutes(15)
    params.hampelSigma (1,1) double = 3
    % movmean-only params (ignored when method = "phasespace")
    params.winMovMean = minutes(15)
    params.thr1_mm (1,1) double = 200
    params.thr2_mm (1,1) double = 100
    params.jump_mm (1,1) double = 10
end

qf = zeros(size(x_mm), "uint16");

%% bit1: invalid/zero removal
bad = false(size(x_mm));
if params.removeZeros
    bad = bad | (x_mm == 0);
end
bad = bad | (x_mm < params.minValid_mm) | (x_mm > params.maxValid_mm) | isnan(x_mm);
qf(bad) = bitor(qf(bad), uint16(1));
x_mm(bad) = NaN;

%% bit2 (+bit3): despiking
if params.method == "phasespace"
    % Goring & Nikora (2002) phase-space threshold method.
    % For burst-mode data (gaps > 10 sec), apply despike to each burst
    % independently to avoid artifacts from interpolating across gaps.
    dt_s = seconds(diff(t));
    gapIdx = find(dt_s > 10);

    if numel(gapIdx) > 5
        % Burst mode: despike each burst separately
        burstStarts = [1; gapIdx + 1];
        burstEnds   = [gapIdx; numel(x_mm)];
        nSpikes = 0;
        for b = 1:numel(burstStarts)
            bIdx = burstStarts(b):burstEnds(b);
            seg = x_mm(bIdx);
            nValid = sum(~isnan(seg));
            if nValid < 10, continue; end  % too few samples for phase-space

            % Interpolate NaN within this burst only
            nanM = isnan(seg);
            if any(nanM) && ~all(nanM)
                gd = find(~nanM);
                seg(nanM) = interp1(gd, seg(gd), find(nanM), 'linear', 'extrap');
            end

            [~, sp] = func_despike_phasespace3d(seg, 0, 0);
            % Only flag originally valid samples
            origValid = ~isnan(x_mm(bIdx));
            sp = sp(origValid(sp));
            x_mm(bIdx(sp)) = NaN;
            qf(bIdx(sp)) = bitor(qf(bIdx(sp)), uint16(2));
            nSpikes = nSpikes + numel(sp);
        end
    else
        % Continuous mode: despike the full time series
        nanMask = isnan(x_mm);
        if ~all(nanMask)
            x_interp = x_mm;
            nanIdx = find(nanMask);
            goodIdx = find(~nanMask);
            if numel(goodIdx) >= 2
                x_interp(nanIdx) = interp1(goodIdx, x_mm(goodIdx), nanIdx, 'linear', 'extrap');
            end

            [~, spikeIdx] = func_despike_phasespace3d(x_interp, 0, 0);
            spikeIdx = spikeIdx(~nanMask(spikeIdx));
            x_mm(spikeIdx) = NaN;
            qf(spikeIdx) = bitor(qf(spikeIdx), uint16(2));
        end
    end

elseif params.method == "movmean"
    % Legacy 2-pass moving-mean + jump filter
    dt = median(seconds(diff(t)), "omitnan");
    if ~isfinite(dt) || dt <= 0, dt = 0.5; end
    win1 = max(3, round(seconds(params.winMovMean) / dt));

    % bit2: moving-mean despike (two-pass)
    m1 = movmean(x_mm, win1, "omitnan");
    sp1 = abs(x_mm - m1) > params.thr1_mm;
    x_mm(sp1) = NaN;
    qf(sp1) = bitor(qf(sp1), uint16(2));

    m2 = movmean(x_mm, win1, "omitnan");
    sp2 = abs(x_mm - m2) > params.thr2_mm;
    x_mm(sp2) = NaN;
    qf(sp2) = bitor(qf(sp2), uint16(2));

    % bit3: jump filter
    d1 = [0; abs(diff(x_mm))];
    d2 = [abs(diff(x_mm)); 0];
    spJump = (d1 > params.jump_mm) | (d2 > params.jump_mm);
    x_mm(spJump) = NaN;
    qf(spJump) = bitor(qf(spJump), uint16(4));

else
    error("qc_altitude: unknown method '%s'. Use 'phasespace' or 'movmean'.", params.method);
end

%% bit4: optional Hampel (robust post-filter)
if params.useHampel
    dt = median(seconds(diff(t)), "omitnan");
    if ~isfinite(dt) || dt <= 0, dt = 0.5; end
    winH = max(3, round(seconds(params.hampelWin) / dt));
    [~, isOut] = hampel(x_mm, winH, params.hampelSigma);
    x_mm(isOut) = NaN;
    qf(isOut) = bitor(qf(isOut), uint16(8));
end
end
