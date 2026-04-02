% build_deployment_table.m
% Scans /Volumes/group/Altimeter_data/ for RangeLogger .log files and
% writes a CSV skeleton to metadata/deployments.csv.
%
% Run this script when:
%   - Setting up the pipeline for the first time
%   - New deployment files have been added to the server
%   - You want to regenerate the table (use overwriteExisting = true)
%
% After running, manually edit deployments.csv to:
%   1. Pair altimeter rows with their echosounder files (EchosounderFiles column,
%      pipe-separated paths relative to serverRoot).
%   2. Merge rows for multi-file deployments (uncommon; most are single-file).
%   3. Verify Depth_m for early files that lack a depth tag in the filename.
%   4. Set TZ_offset_hours (7 = PDT/UTC-7, 8 = PST/UTC-8) per deployment.
%   5. Mark deployments to skip with Active = 0.

clear;

serverRoot       = "/Volumes/group/Altimeter_data";
codeRoot         = fileparts(mfilename("fullpath"));
outCSV           = fullfile(codeRoot, "..", "metadata", "deployments.csv");
overwriteExisting = false;   % set true to regenerate even if CSV exists

if ~overwriteExisting && isfile(outCSV)
    fprintf("deployments.csv already exists. Set overwriteExisting = true to regenerate.\n");
    return
end

%% -- Site definitions -----------------------------------------------------
% Each site: name, relative data root within serverRoot/<name>, MOP, depth(s)
sites(1).name     = "SouthSIOPier";
sites(1).dataRoot = "data";       % files live under SouthSIOPier/data/
sites(1).mop      = "MOP511";
sites(1).altSubdir = "AltimeterData";
sites(1).echoSubdir = "EchosounderData";

sites(2).name     = "TorreyPines";
sites(2).dataRoot = ".";          % files live directly in TorreyPines/
sites(2).mop      = "MOP586";
sites(2).altSubdir  = "";
sites(2).echoSubdir = "";

sites(3).name     = "SolanaBeach";
sites(3).dataRoot = ".";
sites(3).mop      = "MOP654";
sites(3).altSubdir  = "";
sites(3).echoSubdir = "";

%% -- Scan and build rows --------------------------------------------------
header = "DeploymentID,Site,MOP,Depth_m,AltimeterFiles,EchosounderFiles," + ...
         "TZ_offset_hours,Active,Notes";
rows   = {};

for s = 1:numel(sites)
    si   = sites(s);
    base = fullfile(serverRoot, si.name, si.dataRoot);
    if si.altSubdir ~= ""
        altDir = fullfile(base, si.altSubdir);
    else
        altDir = base;
    end

    if ~exist(altDir, "dir")
        fprintf("  [warn] Directory not found, skipping: %s\n", altDir);
        continue
    end

    % Find all .log files that look like altimeter records
    dAll = dir(fullfile(altDir, "*.log"));
    dAll = dAll(~[dAll.isdir]);

    % Keep: files with RANGELOGGER in name (recover-date style)
    %       OR  files with MOP in name but not ECHO (date-range style)
    keep = contains({dAll.name}, "RANGELOGGER", "IgnoreCase", true) | ...
           (contains({dAll.name}, "MOP", "IgnoreCase", true) & ...
            ~contains({dAll.name}, "ECHO", "IgnoreCase", true));
    dAlt = dAll(keep);

    for f = 1:numel(dAlt)
        fname = dAlt(f).name;

        % Server-relative path (what goes in the CSV AltimeterFiles column)
        if si.altSubdir ~= ""
            relPath = si.name + "/" + si.dataRoot + "/" + si.altSubdir + "/" + fname;
        else
            relPath = si.name + "/" + fname;
        end

        [depDate, depth_m, mop] = local_parse_alt_filename(fname, si.mop);
        depID = sprintf("%s_%s_%dm_%s", si.name, mop, depth_m, depDate);

        % Note for depth-unknown files
        notes = "";
        if depth_m == 0
            notes = "depth unknown - check checkout sheet";
        end

        rows{end+1} = sprintf('"%s","%s","%s",%d,"%s","",7,1,"%s"', ...
            depID, si.name, mop, depth_m, relPath, notes); %#ok<AGROW>
    end
end

%% -- Write CSV ------------------------------------------------------------
fid = fopen(outCSV, "w");
if fid == -1
    error("Could not open for writing: %s", outCSV);
end
fprintf(fid, "%s\n", header);
for k = 1:numel(rows)
    fprintf(fid, "%s\n", rows{k});
end
fclose(fid);

fprintf("Wrote %d deployment rows to:\n  %s\n\n", numel(rows), outCSV);
fprintf("Next steps:\n");
fprintf("  1. Fill in EchosounderFiles (pipe-separated paths) for each row.\n");
fprintf("  2. Set Depth_m where marked 'depth unknown'.\n");
fprintf("  3. Verify TZ_offset_hours (7 = PDT, 8 = PST).\n");
fprintf("  4. Set Active = 0 to skip specific deployments.\n");
fprintf("  5. Run run_altimeter_pipeline.m.\n");

%% =========================================================================
%  Local helpers
%% =========================================================================

function [dateStr, depth_m, mop] = local_parse_alt_filename(fname, defaultMOP)
%LOCAL_PARSE_ALT_FILENAME  Extract deploy date, depth, and MOP from filename.
%
% Handles two formats:
%   Date-range:    YYYYMMDD-YYYYMMDDMOPxxx_Xm.log
%   Recover-date:  YYYYMMDD_HHMMSS_RANGELOGGER450kHz_ID_XXXX.log

fname  = string(fname);
depth_m = 0;   % 0 = unknown
mop     = defaultMOP;
dateStr = "00000000";

% -- Date-range format: YYYYMMDD-YYYYMMDD... --------------------------------
tok = regexp(fname, "^(\d{8})-\d{8}", "tokens", "once");
if ~isempty(tok)
    dateStr = tok{1};

    % Extract depth from _Xm suffix
    dtok = regexp(fname, "_(\d+)m", "tokens", "once");
    if ~isempty(dtok)
        depth_m = str2double(dtok{1});
    end

    % Extract MOP from MOPxxx substring
    mtok = regexp(fname, "(MOP\d+)", "tokens", "once");
    if ~isempty(mtok)
        mop = mtok{1};
    end
    return
end

% -- Recover-date format: YYYYMMDD_HHMMSS_RANGELOGGER... --------------------
tok = regexp(fname, "^(\d{8})_\d{6}_RANGELOGGER", "tokens", "once");
if ~isempty(tok)
    dateStr = tok{1};
    % depth_m stays 0 (unknown); MOP stays defaultMOP
    return
end

% Fallback: take first 8-digit sequence as date
tok = regexp(fname, "(\d{8})", "tokens", "once");
if ~isempty(tok)
    dateStr = tok{1};
end
end
