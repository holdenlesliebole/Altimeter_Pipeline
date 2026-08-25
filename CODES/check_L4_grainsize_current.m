function [ok, T] = check_L4_grainsize_current(L4dir, opts)
%CHECK_L4_GRAINSIZE_CURRENT  Fail if an L4 product on disk was built against a
%   superseded grain size.
%
%   ok = check_L4_grainsize_current()
%   [ok,T] = check_L4_grainsize_current(L4dir, strict=true)
%
% WHY THIS EXISTS
%   build_L4_site.m resolves grain size by calling site_grain_size() at BUILD
%   time and stamps the result into L4.Ub_D50 / L4.Ub_D84 / L4.Ub_ks_m. Those
%   values then propagate into L4.tau_b_combined (via ks = 2.5*D84) and
%   L4.shields_combined (via D50). Nothing forces a rebuild when the grain-size
%   table changes, so an L4 can silently disagree with the lookup it claims to
%   use.
%
%   That happened. PUV_Pipeline/shared/site_grain_size.m was updated 2026-07-31
%   (BetterSizer S3 Plus adopted; MOP586 10 m and 15 m promoted from
%   extrapolated to measured). PUV L2 was regenerated the same day and L3 on
%   2026-08-13, but L4 was left at its 2026-07-10 build until 2026-08-24, so
%   every downstream analysis reading tau_b_combined or shields_combined ran on
%   superseded grain size for seven weeks. D84 was off by -15 to -21% at three
%   of the four Torrey depths and +3% at the fourth, i.e. non-uniformly in
%   depth, which is the dangerous kind of wrong for a depth-ordered result.
%
%   Run this after any change to site_grain_size.m, and before trusting an L4.
%
% INPUTS
%   L4dir  - directory of L4_*.mat files (default: ../outputs/L4 next to CODES)
%   opts.strict - true (default) errors on mismatch; false warns and returns ok=false
%
% OUTPUT
%   ok - true if every L4 file matches the current lookup
%   T  - table, one row per file: site, stored vs current D50/D84, and status

arguments
    L4dir (1,1) string = ""
    opts.strict (1,1) logical = true
    opts.tol_m (1,1) double = 1e-9   % exact match expected; tolerance guards float noise
end

codeDir = fileparts(mfilename('fullpath'));
if L4dir == ""
    L4dir = fullfile(codeDir, '..', 'outputs', 'L4');
end
if exist('site_grain_size','file') ~= 2
    addpath('/Users/holden/Documents/Scripps/Research/PUV_Pipeline/shared');
end
assert(exist('site_grain_size','file') == 2, ...
    'site_grain_size.m (PUV_Pipeline/shared) must be on the path.');

% file -> the pvuLabel it was built with, matching run_L4.m
MAP = { 'L4_TP_5m.mat',  'MOP586_5m'
        'L4_TP_7m.mat',  'MOP586_7m'
        'L4_TP_10m.mat', 'MOP586_10m'
        'L4_TP_15m.mat', 'MOP586_15m'
        'L4_SIO_6m.mat', 'MOP511_6m'
        'L4_SOL_7m.mat', 'MOP654_7m' };

name = strings(0,1); stored50 = []; cur50 = []; stored84 = []; cur84 = [];
status = strings(0,1); built = strings(0,1);

for i = 1:size(MAP,1)
    f = fullfile(L4dir, MAP{i,1});
    if ~isfile(f), continue; end
    S = load(f, 'L4'); L = S.L4;
    gs = site_grain_size(MAP{i,2});

    s50 = NaN; s84 = NaN;
    if isfield(L,'Ub_D50'), s50 = L.Ub_D50; end
    if isfield(L,'Ub_D84'), s84 = L.Ub_D84; end

    d = dir(f);
    if isnan(s50) || isnan(s84)
        st = "NO_PROVENANCE";           % pre-dates the stamping; must rebuild
    elseif abs(s50-gs.D50) <= opts.tol_m && abs(s84-gs.D84) <= opts.tol_m
        st = "current";
    else
        st = "STALE";
    end

    name(end+1,1)     = string(MAP{i,1});        %#ok<AGROW>
    stored50(end+1,1) = s50*1e6;                 %#ok<AGROW>
    cur50(end+1,1)    = gs.D50*1e6;              %#ok<AGROW>
    stored84(end+1,1) = s84*1e6;                 %#ok<AGROW>
    cur84(end+1,1)    = gs.D84*1e6;              %#ok<AGROW>
    status(end+1,1)   = st;                      %#ok<AGROW>
    built(end+1,1)    = string(datestr(d.datenum,'yyyy-mm-dd')); %#ok<AGROW>
end

if isempty(name)
    warning('check_L4_grainsize_current:noFiles', 'No L4 files found in %s', L4dir);
    ok = true; T = table(); return
end

T = table(name, built, stored50, cur50, stored84, cur84, status, ...
    'VariableNames', {'file','built','D50_stored_um','D50_now_um', ...
                      'D84_stored_um','D84_now_um','status'});
disp(T);

bad = T.status ~= "current";
ok  = ~any(bad);

if ~ok
    msg = sprintf(['%d L4 product(s) were built against a superseded grain size. ' ...
                   'Rebuild with run_L4.m before using tau_b_combined or ' ...
                   'shields_combined:\n  %s'], nnz(bad), strjoin(T.file(bad)', ', '));
    if opts.strict
        error('check_L4_grainsize_current:stale', '%s', msg); %#ok<SPERR>
    else
        warning('check_L4_grainsize_current:stale', '%s', msg); %#ok<SPWRN>
    end
else
    fprintf('All %d L4 product(s) match the current site_grain_size() lookup.\n', height(T));
end
end
