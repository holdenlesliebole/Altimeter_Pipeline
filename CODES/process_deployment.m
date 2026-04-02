function result = process_deployment(dep, cfg)
%PROCESS_DEPLOYMENT  Read, QC, and derive bed level for one altimeter deployment.
%
% Inputs:
%   dep  : struct with fields from one row of deployments.csv:
%            .DeploymentID    string
%            .Site            string  (e.g. "SouthSIOPier")
%            .MOP             string  (e.g. "MOP511")
%            .Depth_m         double
%            .AltimeterFiles  string, pipe-separated server-relative paths
%            .EchosounderFiles string, pipe-separated server-relative paths (may be "")
%            .TZ_offset_hours double  (hours to add to echosounder local time -> UTC)
%   cfg  : pipeline config struct from run_altimeter_pipeline.m
%
% Output:
%   result : "done" | "skip"
%
% Saved files (in cfg.outputRoot/<Site>/):
%   <DeploymentID>_L1.mat  -- TTa (raw timetable), Eall (echosounder struct or [])
%   <DeploymentID>_L2.mat  -- TTa with QF column, Eall QC'd, qfEcho struct
%   <DeploymentID>_L3.mat  -- TTa with BedLevel_mm, Eall with bedlevel_mm, dep
%   <DeploymentID>_ql.png  -- quicklook figure (saved; never displayed)

%% -- Caching check -------------------------------------------------------
sitePath = fullfile(cfg.outputRoot, dep.Site);
if ~exist(sitePath, "dir"), mkdir(sitePath); end

outL3  = fullfile(sitePath, dep.DeploymentID + "_L3.mat");
outPNG = fullfile(sitePath, dep.DeploymentID + "_ql.png");

if ~cfg.overwrite && isfile(outL3)
    fprintf("  [skip] %s -- L3 already exists.\n", dep.DeploymentID);
    result = "skip";
    return
end

fprintf("Processing: %s\n", dep.DeploymentID);

%% -- L1: Read altimeter (RangeLogger .log) --------------------------------
altList = local_split_paths(dep.AltimeterFiles);
TTa = timetable();
hasAltimeter = false;
for i = 1:numel(altList)
    fpath = fullfile(cfg.serverRoot, altList{i});
    if ~isfile(fpath)
        warning("process_deployment: altimeter file not found:\n  %s", fpath);
        continue
    end
    TT  = read_rangelogger_log(fpath);
    TTa = [TTa; TT]; %#ok<AGROW>
    hasAltimeter = true;
end
if hasAltimeter
    TTa = sortrows(TTa);
end

%% -- L1: Read echosounder (.log or .BIN) -- optional ---------------------
echoList    = local_split_paths(dep.EchosounderFiles);
Eall        = [];
hasEcho     = false;
for i = 1:numel(echoList)
    fpath = fullfile(cfg.serverRoot, echoList{i});
    if ~isfile(fpath)
        warning("process_deployment: echosounder file not found:\n  %s", fpath);
        continue
    end
    [~, ~, ext] = fileparts(fpath);
    if strcmpi(ext, ".log")
        Ei   = read_echosounder_log(fpath, "TimeOffsetHours", dep.TZ_offset_hours);
        Eall = local_concat_echosounder(Eall, Ei);
        hasEcho = true;
    elseif strcmpi(ext, ".bin")
        Ei   = read_echosounder_bin(fpath, "TimeOffsetHours", dep.TZ_offset_hours);
        Eall = local_concat_echosounder(Eall, Ei);
        hasEcho = true;
    else
        warning("process_deployment: unrecognized echosounder extension: %s", fpath);
    end
end
if hasEcho
    [~, order] = sort(Eall.time);
    Eall = local_reorder_echosounder(Eall, order);
end

%% -- Require at least one data source -------------------------------------
if ~hasAltimeter && ~hasEcho
    warning("process_deployment: no data loaded for %s -- skipping.", dep.DeploymentID);
    result = "skip";
    return
end

%% -- Save L1 -------------------------------------------------------------
outL1 = fullfile(sitePath, dep.DeploymentID + "_L1.mat");
save(outL1, "TTa", "Eall", "-v7.3");

%% -- L2: QC altimeter -----------------------------------------------------
if hasAltimeter
    qcNV = namedargs2cell(cfg.qcParams);
    [TTa.Altitude_mm, TTa.QF] = qc_altitude(TTa.Altitude_mm, TTa.Time, qcNV{:});
end

%% -- L2: QC echosounder ---------------------------------------------------
if hasEcho
    [Eall, qfEcho] = qc_echosounder(Eall, "altitudeParams", cfg.qcParams, "tilt_deg", 2);
else
    qfEcho = [];
end

outL2 = fullfile(sitePath, dep.DeploymentID + "_L2.mat");
save(outL2, "TTa", "Eall", "qfEcho", "-v7.3");

%% -- L3: Derive bed level ------------------------------------------------
% Convention (from altitude_to_bedlevel.m):
%   BedLevel_mm = -(alt - alt_baseline)
%   -> accretion positive, erosion negative
if hasAltimeter
    TTa.BedLevel_mm = altitude_to_bedlevel(TTa.Altitude_mm);
end
if hasEcho
    Eall.bedlevel_mm = altitude_to_bedlevel(Eall.altitude_mm);
end

save(outL3, "TTa", "Eall", "dep", "-v7.3");
fprintf("  Saved L1/L2/L3 -> %s\n", sitePath);

%% -- Quicklook ------------------------------------------------------------
if cfg.savePlots
    if hasEcho && hasAltimeter
        depth_m = linspace(0, 2, size(Eall.backscatter, 2))';
        fig = plot_altimeter_echosounder(TTa, Eall, depth_m);
    elseif hasEcho
        fig = local_plot_echosounder_only(Eall, dep);
    else
        fig = local_plot_altimeter_only(TTa, dep);
    end
    exportgraphics(fig, outPNG, "Resolution", 150);
    close(fig);
    fprintf("  Saved quicklook: %s\n", outPNG);
end

result = "done";
end

%% =========================================================================
%  Local helpers
%% =========================================================================

function parts = local_split_paths(s)
%LOCAL_SPLIT_PATHS  Split a pipe-separated path string; strip blanks.
if ismissing(s) || s == "" || strtrim(s) == ""
    parts = {};
    return
end
parts = strtrim(strsplit(s, "|"));
parts = parts(~cellfun(@isempty, parts));
parts = parts(~strcmp(parts, ""));
end

function Eout = local_concat_echosounder(Eall, Ei)
%LOCAL_CONCAT_ECHOSOUNDER  Vertically concatenate two echosounder structs.
if isempty(Eall)
    Eout = Ei;
    return
end
Eout            = Eall;
Eout.time        = [Eall.time;        Ei.time];
Eout.pitch_deg   = [Eall.pitch_deg;   Ei.pitch_deg];
Eout.roll_deg    = [Eall.roll_deg;    Ei.roll_deg];
Eout.altitude_mm = [Eall.altitude_mm; Ei.altitude_mm];
% Backscatter matrices may differ in numDepths if config changed mid-deployment.
% Pad the narrower one with NaNs before concatenating.
nc1 = size(Eall.backscatter, 2);
nc2 = size(Ei.backscatter,   2);
if nc1 ~= nc2
    nMax = max(nc1, nc2);
    Eall.backscatter = [Eall.backscatter, nan(size(Eall.backscatter,1), nMax-nc1)];
    Ei.backscatter   = [Ei.backscatter,   nan(size(Ei.backscatter,1),   nMax-nc2)];
end
Eout.backscatter = [Eall.backscatter; Ei.backscatter];
Eout.numEntries  = Eall.numEntries + Ei.numEntries;
Eout.numDepths   = max(nc1, nc2);
% Concatenate temperature_C if present in both
if isfield(Eall, 'temperature_C') && isfield(Ei, 'temperature_C')
    Eout.temperature_C = [Eall.temperature_C; Ei.temperature_C];
elseif isfield(Ei, 'temperature_C')
    % Eall came from .log (no temperature); pad with NaN
    Eout.temperature_C = [nan(Eall.numEntries, 1); Ei.temperature_C];
elseif isfield(Eall, 'temperature_C')
    Eout.temperature_C = [Eall.temperature_C; nan(Ei.numEntries, 1)];
end
end

function E = local_reorder_echosounder(Eall, order)
%LOCAL_REORDER_ECHOSOUNDER  Reorder rows of an echosounder struct.
E            = Eall;
E.time        = Eall.time(order);
E.pitch_deg   = Eall.pitch_deg(order);
E.roll_deg    = Eall.roll_deg(order);
E.altitude_mm = Eall.altitude_mm(order);
E.backscatter = Eall.backscatter(order, :);
if isfield(Eall, 'temperature_C')
    E.temperature_C = Eall.temperature_C(order);
end
end

function fig = local_plot_echosounder_only(E, dep)
%LOCAL_PLOT_ECHOSOUNDER_ONLY  Three-panel quicklook for echosounder-only deployments.
fig = figure("Color","w","Visible","off","Position",[100 100 900 700]);
tl  = tiledlayout(3, 1, "TileSpacing","compact", "Padding","compact");
title(tl, sprintf("%s  %s  %gm (echosounder only)", dep.Site, dep.MOP, dep.Depth_m), ...
    "Interpreter","none");

nexttile
plot(E.time, E.bedlevel_mm, "Color",[0.18 0.45 0.75], "LineWidth",0.8);
ylabel("Bed level change (mm)");
grid on; box off

nexttile
plot(E.time, E.pitch_deg, "DisplayName","Pitch"); hold on
plot(E.time, E.roll_deg, "DisplayName","Roll");
ylabel("Tilt (deg)"); legend("Location","best");
grid on; box off

nexttile
if ~isempty(E.backscatter) && ~all(isnan(E.backscatter(:)))
    depth_m = linspace(0, 2, size(E.backscatter, 2))';
    imagesc(E.time, depth_m, E.backscatter'); axis xy
    ylabel("Range from sensor (m)");
    cb = colorbar; cb.Label.String = "Backscatter (arb)";
    hold on
    plot(E.time, E.altitude_mm/1000, "k", "LineWidth", 1.0);
else
    text(0.5, 0.5, "No backscatter data", "Units","normalized", "HorizontalAlignment","center");
end
end

function fig = local_plot_altimeter_only(TT, dep)
%LOCAL_PLOT_ALTIMETER_ONLY  Two-panel quicklook: bed level + diagnostics.
fig = figure("Color","w","Visible","off");
tl  = tiledlayout(2, 1, "TileSpacing","compact", "Padding","compact");
title(tl, sprintf("%s  %s  %gm", dep.Site, dep.MOP, dep.Depth_m), ...
    "Interpreter","none");

nexttile
plot(TT.Time, TT.BedLevel_mm, "Color",[0.18 0.45 0.75], "LineWidth",0.8);
ylabel("Bed level change (mm)");
grid on; box off

nexttile
yyaxis left
plot(TT.Time, TT.Amplitude_pctFS, "Color",[0.8 0.4 0.2], "LineWidth",0.6);
ylabel("Amplitude (%FS)"); ylim([0 100]);
yyaxis right
plot(TT.Time, TT.Temperature_C, "Color",[0.2 0.65 0.35], "LineWidth",0.6);
ylabel("Temperature (C)");
legend(["Amplitude","Temperature"], "Location","best");
grid on; box off
end
