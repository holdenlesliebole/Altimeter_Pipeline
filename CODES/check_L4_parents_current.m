function [ok, T] = check_L4_parents_current(L4dir, opts)
%CHECK_L4_PARENTS_CURRENT  Fail if an L4 product was built from PUV L2/L3 that has since changed.
%
%   ok = check_L4_parents_current()
%   [ok, T] = check_L4_parents_current(L4dir, strict=true, breakTest=false)
%
% WHY THIS EXISTS
%   The six L4 files built 2026-08-24 outlived their PUV L2 by a month: PUV_Pipeline's
%   October rebuild changed L2 (edge-gap fill fix d95012c) and nothing told L4. At the
%   Torrey stations 51 rows carried stale Ub and vmom, some by a factor of up to 244
%   (docs/DIAGNOSIS_L4_stale_PUV_L2_2026-11-13.md). Since 2026-11-14 build_L4_site stamps
%   each PUV L2 and L3 it read (L4.prov_parents: path, build_id, file_sha256 from the
%   file's provenance sidecar). This check compares those stamps with the live sidecars.
%
%   Run it before trusting an L4, and after any PUV_Pipeline L2/L3 rebuild.
%
% INPUTS
%   L4dir           directory of L4_*.mat (default: ../outputs/L4 next to CODES)
%   opts.strict     true (default): error on any non-current row; false: warn, ok = false
%   opts.breakTest  true: corrupt the first stamp's build_id in memory before comparing.
%                   The check must then report STALE for it (seen-to-fail test).
%
% OUTPUT
%   ok  true if every parent of every L4 is current
%   T   table, one row per (L4 file, PUV deployment, level): stored vs live build_id and
%       sha256, and status current | STALE | NO_PROVENANCE (L4 predates stamping) |
%       MISSING (the parent file is gone)
%
% 2026-11-14.

arguments
    L4dir (1,1) string = ""
    opts.strict (1,1) logical = true
    opts.breakTest (1,1) logical = false
end
codeDir = fileparts(mfilename('fullpath'));
if L4dir == "", L4dir = fullfile(codeDir, '..', 'outputs', 'L4'); end
if exist('read_prov', 'file') ~= 2
    addpath('/Users/holden/Documents/Scripps/Research/PUV_Pipeline/shared');
end
files = dir(fullfile(L4dir, 'L4_*.mat'));
rows = {};
for i = 1:numel(files)
    S = load(fullfile(files(i).folder, files(i).name), 'L4');  L = S.L4;
    if ~isfield(L, 'prov_parents') || isempty(L.prov_parents)
        rows(end+1, :) = {string(files(i).name), "", "", "", "", "", "", "NO_PROVENANCE"}; %#ok<AGROW>
        continue
    end
    P = L.prov_parents;
    if opts.breakTest && i == 1, P(1).L2_build_id = "broken-" + P(1).L2_build_id; end
    for p = 1:numel(P)
        for lv = ["L2", "L3"]
            f = P(p).(lv + "_path");  b0 = P(p).(lv + "_build_id");  h0 = P(p).(lv + "_sha256");
            if f == "" , continue, end
            b1 = ""; h1 = "";
            if ~isfile(f)
                st = "MISSING";
            else
                pv = read_prov(char(f));
                if ~isempty(pv) && isfield(pv, 'build_id'), b1 = string(pv.build_id); end
                if ~isempty(pv) && isfield(pv, 'file_sha256'), h1 = string(pv.file_sha256); end
                if b0 ~= "" && h0 ~= "" && b0 == b1 && h0 == h1
                    st = "current";
                else
                    st = "STALE";
                end
            end
            rows(end+1, :) = {string(files(i).name), P(p).dep, lv, b0, b1, h0, h1, st}; %#ok<AGROW>
        end
    end
end
T = cell2table(rows, 'VariableNames', {'L4file', 'dep', 'level', 'stored_build_id', ...
    'live_build_id', 'stored_sha256', 'live_sha256', 'status'});
ok = all(T.status == "current") && height(T) > 0;
fprintf('check_L4_parents_current: %d/%d parent stamps current across %d L4 files\n', ...
    sum(T.status == "current"), height(T), numel(files));
bad = T(T.status ~= "current", :);
for r = 1:height(bad)
    fprintf('  %-14s %-8s %s  %s\n', bad.L4file(r), bad.dep(r), bad.level(r), bad.status(r));
end
if ~ok
    msg = sprintf('%d L4 parent stamp(s) not current: rebuild L4 (run_L4.m)', sum(T.status ~= "current"));
    if opts.strict, error('check_L4_parents_current:stale', '%s', msg); else, warning('%s', msg); end
end
end
