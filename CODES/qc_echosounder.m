function [E, qf] = qc_echosounder(E, params)
%QC_ECHOSOUNDER Apply QC to echosounder altitude + optionally mask backscatter.
%
% Params (optional):
%   .tilt_deg (default 2)            -> if |pitch| or |roll| exceeds, mask row
%   .altitudeParams (struct)         -> passed to qc_altitude
%
% Outputs:
%   E altitude_mm cleaned, and any masked rows set to NaN in backscatter
%   qf : struct with fields qf_altitude (uint16), maskTilt (logical)

arguments
    E (1,1) struct
    params.tilt_deg (1,1) double = 2
    params.altitudeParams = struct()
end

altNV = namedargs2cell(params.altitudeParams);
[E.altitude_mm, qf_alt] = qc_altitude(E.altitude_mm, E.time, altNV{:});

maskTilt = abs(E.pitch_deg) > params.tilt_deg | abs(E.roll_deg) > params.tilt_deg;
E.altitude_mm(maskTilt) = NaN;

if isfield(E, "backscatter") && ~isempty(E.backscatter)
    E.backscatter(maskTilt, :) = NaN;
end

qf = struct();
qf.qf_altitude = qf_alt;
qf.maskTilt = maskTilt;
end
