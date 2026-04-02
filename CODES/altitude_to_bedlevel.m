function bed_mm = altitude_to_bedlevel(alt_mm, baselineIdx)
%ALTITUDE_TO_BEDLEVEL Convert distance-to-bed (altitude) into relative bed level change.
%
% Convention used in your scripts:
%   bed = -(alt - alt(baseline))  => erosion (bed down) is negative.
%
% baselineIdx: index of reference sample; if empty, uses first non-NaN.

arguments
    alt_mm (:,1) double
    baselineIdx (1,1) double = NaN
end

if isnan(baselineIdx)
    baselineIdx = find(~isnan(alt_mm), 1, "first");
end
if isempty(baselineIdx)
    bed_mm = nan(size(alt_mm));
    return
end

bed_mm = -(alt_mm - alt_mm(baselineIdx));
end
