% run_altimeter_pipeline.m
% Master orchestrator: reads metadata/deployments.csv and processes every
% deployment through L1 (read) -> L2 (QC) -> L3 (bed level).
%
% Usage:
%   1. Verify metadata/deployments.csv has correct file paths and metadata.
%      Run build_deployment_table.m first if you need to (re)generate it.
%   2. Adjust cfg below if needed.
%   3. Run this script.
%
% Outputs per deployment (in cfg.outputRoot/<Site>/):
%   <DeploymentID>_L1.mat  -- raw concatenated timetable + echosounder struct
%   <DeploymentID>_L2.mat  -- QC-flagged altimeter + tilt-masked echosounder
%   <DeploymentID>_L3.mat  -- L2 + BedLevel_mm channel + deployment metadata
%   <DeploymentID>_ql.png  -- quicklook figure (altimeter only, or w/ echosounder)

clear; close all;

%% -- User configuration ---------------------------------------------------
cfg.serverRoot   = "/Volumes/group/Altimeter_data";   % server mount point
cfg.codeRoot     = fileparts(mfilename("fullpath"));   % directory of this file
cfg.outputRoot   = fullfile(cfg.codeRoot, "..", "processed");
cfg.metadataFile = fullfile(cfg.codeRoot, "..", "metadata", "deployments.csv");

% QC parameters applied to all deployments (override per-deployment in CSV if needed)
cfg.qcParams.winMovMean = minutes(15);  % moving-mean window for despike
cfg.qcParams.thr1_mm    = 200;          % first-pass spike threshold (mm)
cfg.qcParams.thr2_mm    = 100;          % second-pass spike threshold (mm)
cfg.qcParams.jump_mm    = 10;           % neighbor-jump threshold (mm)
cfg.qcParams.useHampel  = false;

cfg.savePlots    = true;   % save quicklook PNG; figures are never displayed
cfg.overwrite    = false;  % set true to reprocess deployments that already have L3.mat

%% -- Read deployment table ------------------------------------------------
if ~isfile(cfg.metadataFile)
    error("Deployment table not found: %s\n" + ...
          "Run build_deployment_table.m to generate it.", cfg.metadataFile);
end

% Import all columns as strings first to avoid type-guessing issues,
% then convert numerics explicitly.
opts = detectImportOptions(cfg.metadataFile, "Delimiter", ",");
opts = setvartype(opts, opts.VariableNames, "string");
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule    = "skip";
tbl = readtable(cfg.metadataFile, opts);

% Strip BOM or whitespace from column names (common CSV artefact)
tbl.Properties.VariableNames = strtrim(tbl.Properties.VariableNames);

% Skip rows flagged as inactive
if any(strcmp(tbl.Properties.VariableNames, "Active"))
    keep = tbl.Active ~= "0" & tbl.Active ~= "false" & tbl.Active ~= "no";
    tbl  = tbl(keep, :);
end

fprintf("Loaded %d deployments from %s\n", height(tbl), cfg.metadataFile);

%% -- Process each deployment ----------------------------------------------
addpath(cfg.codeRoot);  % ensure helper functions are on path

nSkip = 0;  nDone = 0;  nFail = 0;
for k = 1:height(tbl)
    row = tbl(k, :);

    dep.DeploymentID    = strtrim(row.DeploymentID);
    dep.Site            = strtrim(row.Site);
    dep.MOP             = strtrim(row.MOP);
    dep.Depth_m         = str2double(row.Depth_m);
    dep.AltimeterFiles  = strtrim(row.AltimeterFiles);
    dep.EchosounderFiles = strtrim(row.EchosounderFiles);
    dep.TZ_offset_hours = str2double(row.TZ_offset_hours);
    if isnan(dep.TZ_offset_hours), dep.TZ_offset_hours = 7; end  % default PDT

    try
        result = process_deployment(dep, cfg);
        if result == "skip"
            nSkip = nSkip + 1;
        else
            nDone = nDone + 1;
        end
    catch ME
        fprintf("  [ERROR] %s: %s\n", dep.DeploymentID, ME.message);
        nFail = nFail + 1;
    end
end

fprintf("\nPipeline complete: %d processed, %d skipped (cached), %d errors.\n", ...
    nDone, nSkip, nFail);
