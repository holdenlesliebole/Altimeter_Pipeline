function V = validate_against_surveys(BA, opts)
%VALIDATE_AGAINST_SURVEYS  Compare burst-averaged bed level against beach survey profiles.
%
% Uses CPG beach survey (SM) data to independently validate altimeter/
% echosounder bed level measurements. Two comparison modes:
%
%   Relative: Compares the bed level CHANGE between consecutive survey
%     pairs against the altimeter-measured change over the same interval.
%     This is the primary validation metric.
%
%   Absolute: If instrumentElev_m is provided, converts altimeter altitude
%     to NAVD88 elevation and compares directly against survey elevation.
%
% Inputs:
%   BA   : burst-averaged struct from L3 (.time, .altitude_mm, .bedlevel_mm)
%
% Required name-value:
%   instrumentLat   : latitude of instrument (decimal degrees)
%   instrumentLon   : longitude of instrument (decimal degrees)
%
% Optional name-value:
%   instrumentElev_m : NAVD88 elevation of sensor face (m). If provided,
%                      enables absolute comparison.
%   smFilePath       : path to SM files (default: '/Volumes/group/MOPS/')
%   minSurveyDepth_m : reject surveys shallower than this at the instrument
%                      position (default: 3 m below MSL)
%   maxTimeDelta_hr  : max hours between survey and nearest burst (default: 12)
%   mopNumber        : override auto-detected MOP number (default: auto)
%
% Output struct V:
%   .surveyDates       — datetime of each valid survey
%   .surveyElev_m      — NAVD88 elevation at instrument position per survey
%   .altAltitude_mm    — burst-median altitude at nearest burst to each survey
%   .altBedLevel_mm    — burst bed level at nearest burst to each survey
%   .altElev_m         — NAVD88 bed elevation from altimeter (if instrumentElev_m given)
%   .deltaZ_survey_mm  — bed level change between consecutive surveys
%   .deltaZ_alt_mm     — altimeter change over same intervals
%   .residual_mm       — deltaZ_alt - deltaZ_survey
%   .rmse_mm, .bias_mm, .r2 — summary statistics
%   .mopNumber, .xShore_m   — instrument position on MOP transect

arguments
    BA (1,1) struct
    opts.instrumentLat (1,1) double
    opts.instrumentLon (1,1) double
    opts.instrumentElev_m (1,1) double = NaN
    opts.smFilePath (1,1) string = "/Volumes/group/MOPS/"
    opts.minSurveyDepth_m (1,1) double = 3
    opts.maxTimeDelta_hr (1,1) double = 12
    opts.mopNumber (1,1) double = NaN
end

%% -- Convert instrument position to MOP coordinates ----------------------
if isnan(opts.mopNumber)
    [mopNum, xShore] = LatLon2MopxshoreX(opts.instrumentLat, opts.instrumentLon);
else
    mopNum = opts.mopNumber;
    [~, xShore] = LatLon2MopxshoreX(opts.instrumentLat, opts.instrumentLon);
end
mopNum = round(mopNum);

fprintf('  Survey validation: instrument at MOP %d, X_shore = %d m\n', mopNum, round(xShore));

%% -- Load SM file for this MOP -------------------------------------------
smFile = fullfile(opts.smFilePath, sprintf('M%05dSM.mat', mopNum));
if ~isfile(smFile)
    warning('validate_against_surveys: SM file not found: %s', smFile);
    V = local_empty_result(mopNum, xShore);
    return
end
load(smFile, 'SM');

%% -- Find surveys that reach instrument depth -----------------------------
altDates = BA.time;
altDatenum = datenum(altDates);
depStart = min(altDatenum) - 7;   % 1 week before/after deployment
depEnd   = max(altDatenum) + 7;

surveyDatenums = [SM.Datenum];
inRange = surveyDatenums >= depStart & surveyDatenums <= depEnd;

validSurveys = [];
surveyElevs  = [];

for k = find(inRange)
    X1D = SM(k).X1D;
    Z1D = SM(k).Z1Dmean;

    % Check if profile extends to instrument position
    xIdx = find(abs(X1D - round(xShore)) <= 1, 1);
    if isempty(xIdx) || isnan(Z1D(xIdx))
        continue
    end

    % Interpolate elevation at exact cross-shore position
    validX = ~isnan(Z1D);
    if sum(validX) < 3, continue; end
    elev = interp1(X1D(validX), Z1D(validX), xShore, 'linear', NaN);
    if isnan(elev), continue; end

    % Check minimum depth (reject subaerial-only surveys)
    if elev > -opts.minSurveyDepth_m
        continue
    end

    validSurveys(end+1) = k; %#ok<AGROW>
    surveyElevs(end+1)  = elev; %#ok<AGROW>
end

nSurveys = numel(validSurveys);
fprintf('  Found %d surveys reaching instrument depth (of %d in range)\n', ...
    nSurveys, sum(inRange));

if nSurveys < 1
    V = local_empty_result(mopNum, xShore);
    return
end

%% -- Match each survey to nearest altimeter burst -------------------------
surveyDatetimes = datetime(surveyDatenums(validSurveys), 'ConvertFrom', 'datenum');
altBedLevel   = nan(nSurveys, 1);
altAltitude   = nan(nSurveys, 1);
matchDelta_hr = nan(nSurveys, 1);

for k = 1:nSurveys
    [dt, idx] = min(abs(altDates - surveyDatetimes(k)));
    matchDelta_hr(k) = hours(dt);
    if matchDelta_hr(k) <= opts.maxTimeDelta_hr
        altBedLevel(k) = BA.bedlevel_mm(idx);
        altAltitude(k) = BA.altitude_mm(idx);
    end
end

nMatched = sum(~isnan(altBedLevel));
fprintf('  %d surveys matched to altimeter bursts (within %d hr)\n', ...
    nMatched, opts.maxTimeDelta_hr);

%% -- Relative comparison: Δz between consecutive surveys ------------------
deltaZ_survey = nan(nSurveys, 1);
deltaZ_alt    = nan(nSurveys, 1);

for k = 2:nSurveys
    if ~isnan(altBedLevel(k)) && ~isnan(altBedLevel(k-1))
        deltaZ_survey(k) = (surveyElevs(k) - surveyElevs(k-1)) * 1000;  % m → mm
        deltaZ_alt(k)    = altBedLevel(k) - altBedLevel(k-1);
    end
end

residual = deltaZ_alt - deltaZ_survey;
validPairs = ~isnan(residual);
nPairs = sum(validPairs);

%% -- Absolute comparison (if instrument elevation provided) ---------------
altElev_m = nan(nSurveys, 1);
if ~isnan(opts.instrumentElev_m)
    % Bed elevation = instrument elevation - altitude (distance to bed)
    altElev_m = opts.instrumentElev_m - altAltitude / 1000;
end

%% -- Summary statistics ---------------------------------------------------
if nPairs >= 2
    rmse = sqrt(mean(residual(validPairs).^2));
    bias = mean(residual(validPairs));
    cc = corrcoef(deltaZ_survey(validPairs), deltaZ_alt(validPairs));
    r2 = cc(1,2)^2;
else
    rmse = NaN; bias = NaN; r2 = NaN;
end

fprintf('  Relative validation (%d pairs): RMSE=%.1f mm, bias=%.1f mm, R²=%.3f\n', ...
    nPairs, rmse, bias, r2);

if ~isnan(opts.instrumentElev_m) && nMatched >= 1
    absResid = altElev_m - surveyElevs(:);
    absValid = ~isnan(absResid);
    if any(absValid)
        fprintf('  Absolute validation: mean offset = %.3f m (alt - survey)\n', ...
            mean(absResid(absValid)));
    end
end

%% -- Build output struct --------------------------------------------------
V.surveyDates      = surveyDatetimes;
V.surveyElev_m     = surveyElevs(:);
V.altAltitude_mm   = altAltitude;
V.altBedLevel_mm   = altBedLevel;
V.altElev_m        = altElev_m;
V.matchDelta_hr    = matchDelta_hr;
V.deltaZ_survey_mm = deltaZ_survey;
V.deltaZ_alt_mm    = deltaZ_alt;
V.residual_mm      = residual;
V.rmse_mm          = rmse;
V.bias_mm          = bias;
V.r2               = r2;
V.nSurveys         = nSurveys;
V.nPairs           = nPairs;
V.mopNumber        = mopNum;
V.xShore_m         = xShore;
end

function V = local_empty_result(mopNum, xShore)
V = struct('surveyDates',datetime.empty(0,1), 'surveyElev_m',[], ...
    'altAltitude_mm',[], 'altBedLevel_mm',[], 'altElev_m',[], ...
    'matchDelta_hr',[], 'deltaZ_survey_mm',[], 'deltaZ_alt_mm',[], ...
    'residual_mm',[], 'rmse_mm',NaN, 'bias_mm',NaN, 'r2',NaN, ...
    'nSurveys',0, 'nPairs',0, 'mopNumber',mopNum, 'xShore_m',xShore);
end
