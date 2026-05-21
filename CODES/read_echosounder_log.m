function E = read_echosounder_log(filepath, varargin)
%READ_ECHOSOUNDER_LOG Parse an Echologger EA400 echosounder *.log with repeating headers + DataStart/DataEnd blocks.
%
% E fields:
%   time   (datetime, naive-UTC)
%   pitch_deg, roll_deg
%   altitude_mm  (distance to bed; converted from meters if present)
%   temperature_C  (N x 1; from the #Temperature header, for QC/verification)
%   backscatter  (N x M double)
%   numEntries, numDepths
%
% Optional name/value:
%   "TimeZone"      : e.g., "UTC" (default "")
%   "TimeOffsetHours": numeric (default 0), applied ONLY to records that fall
%                      back to #TimeLocal (no #TimeUTC present).
%
% Time handling:
% - The EA400 .log writes BOTH "#TimeLocal" and "#TimeUTC" per ping. We read
%   #TimeUTC directly (instrument-authoritative UTC, DST-proof — no seasonal
%   offset guessing). #TimeLocal + TimeOffsetHours is only a fallback for any
%   record missing #TimeUTC.
%
% Notes:
% - We "peek" the first data block to determine numDepths.
% - Parsing is done in large byte chunks aligned to '#TimeLocal' record
%   boundaries, with vectorized string ops per chunk (one str2double call for
%   all backscatter in a chunk). This is ~5-10x faster than line-by-line fgetl
%   for the multi-GB SIO files.

p = inputParser;
p.addRequired("filepath", @(s)isstring(s)||ischar(s));
p.addParameter("TimeZone","", @(s)isstring(s)||ischar(s));
p.addParameter("TimeOffsetHours",0, @(x)isnumeric(x)&&isscalar(x));
p.parse(filepath, varargin{:});
tz = string(p.Results.TimeZone);
offsetH = p.Results.TimeOffsetHours;

filepath = string(filepath);

% --- Pass 0: determine number of depth bins from first block ---
numDepths = local_peek_numDepths(filepath);

% --- Single chunked pass: read large byte blocks aligned to '#TimeLocal'
%     record boundaries and parse each with vectorized string ops. ---
fid = fopen(filepath, 'r');
if fid == -1, error("Could not open %s", filepath); end
cleanup = onCleanup(@() fclose(fid));

CHUNK = 128*1024*1024;          % bytes per read
NL = newline;
tUc={}; tLc={}; pc={}; rc={}; ac={}; tc={}; bsc={};
leftover = '';
while true
    raw = fread(fid, CHUNK, '*char')';
    atEOF = isempty(raw);
    buf = [leftover, raw];
    if atEOF
        tail = buf; leftover = '';
    else
        b = strfind(buf, [NL '#TimeLocal']);
        if isempty(b)
            leftover = buf;     % no complete record boundary yet
            continue
        end
        cut = b(end);
        tail = buf(1:cut-1);
        leftover = buf(cut+1:end);   % begins at '#TimeLocal'
    end
    if ~isempty(tail)
        [tU,tL,pp,rr,aa,tt,bb] = local_parse_chunk(tail, numDepths, tz, NL);
        if ~isempty(tU)
            tUc{end+1}=tU; tLc{end+1}=tL; pc{end+1}=pp; rc{end+1}=rr; %#ok<AGROW>
            ac{end+1}=aa; tc{end+1}=tt; bsc{end+1}=bb;                %#ok<AGROW>
        end
    end
    if atEOF, break; end
end

if isempty(tUc)
    error("read_echosounder_log: no #TimeLocal records found in %s", filepath);
end
tUTC   = vertcat(tUc{:});
tLocal = vertcat(tLc{:});
pitch  = vertcat(pc{:});
roll   = vertcat(rc{:});
alt_m  = vertcat(ac{:});
temp_C = vertcat(tc{:});
backscatter = vertcat(bsc{:});
numEntries = numel(tUTC);

% Convert to mm if altitude was in meters
altitude_mm = alt_m * 1000;

% Prefer #TimeUTC; fall back to #TimeLocal + offset for any record lacking it.
t = tUTC;
t.TimeZone = "";
missing = isnat(t);
if any(missing)
    tl = tLocal(missing); tl.TimeZone = "";
    if offsetH ~= 0
        tl = tl + hours(offsetH);
    end
    t(missing) = tl;
end

E = struct();
E.time = t;
E.pitch_deg = pitch;
E.roll_deg  = roll;
E.altitude_mm = altitude_mm;
E.temperature_C = temp_C;
E.backscatter = backscatter;
E.numEntries = numEntries;
E.numDepths = numDepths;
E.nUTC = nnz(~isnat(tUTC));     % provenance: how many records used #TimeUTC
end

function [tU,tL,pitch,roll,alt_m,temp_C,bs] = local_parse_chunk(text, numDepths, tz, NL)
% Vectorized parse of a chunk holding whole #TimeLocal-delimited records.
text = erase(text, char(13));            % drop CR (CRLF tolerance)
lines = split(string(text), NL);

isTL = startsWith(lines, '#TimeLocal');
recID = cumsum(isTL);                     % 0 for any preamble before 1st record
nRec = double(recID(end));
if nRec == 0
    tU=NaT(0,1); tL=NaT(0,1); pitch=nan(0,1); roll=nan(0,1);
    alt_m=nan(0,1); temp_C=nan(0,1); bs=nan(0,numDepths); return
end

tU=NaT(nRec,1); tL=NaT(nRec,1);
pitch=nan(nRec,1); roll=nan(nRec,1); alt_m=nan(nRec,1); temp_C=nan(nRec,1);

sel = isTL;                  tL(recID(sel)) = local_parse_times(strtrim(extractAfter(lines(sel),'#TimeLocal')), tz);
sel = startsWith(lines,'#TimeUTC') & recID>=1;
                             tU(recID(sel)) = local_parse_times(strtrim(extractAfter(lines(sel),'#TimeUTC')), "");
sel = startsWith(lines,'#Altitude,m') & recID>=1;
                             alt_m(recID(sel))  = str2double(extractAfter(lines(sel),'#Altitude,m'));
sel = startsWith(lines,'#Pitch,deg') & recID>=1;
                             pitch(recID(sel))  = str2double(extractAfter(lines(sel),'#Pitch,deg'));
sel = startsWith(lines,'#Roll,deg') & recID>=1;
                             roll(recID(sel))   = str2double(extractAfter(lines(sel),'#Roll,deg'));
% Temperature: "#Temperature,<deg>C 14.14" — take the trailing numeric token.
sel = startsWith(lines,'#Temperature') & recID>=1;
if any(sel)
    tnum = regexp(lines(sel), '[-+]?[0-9]*\.?[0-9]+\s*$', 'match', 'once');
    temp_C(recID(sel)) = str2double(tnum);
end

% Backscatter: numeric lines strictly inside ##DataStart/##DataEnd blocks.
isDS = startsWith(lines,'##DataStart');
isDE = startsWith(lines,'##DataEnd');
level = cumsum(isDS) - cumsum(isDE);
dataMask = (level==1) & ~isDS & ~isDE & recID>=1;
bs = nan(nRec, numDepths);
di = find(dataMask);
di = di(:);
if ~isempty(di)
    dl = lines(di);
    % Bulk numeric parse via sscanf (C-level, far faster than per-element
    % str2double over tens of millions of lines). Fall back to the safe
    % per-element path if the count doesn't match (e.g. a non-numeric line).
    val = sscanf(join(dl, newline), '%f');
    if numel(val) ~= numel(di)
        val = str2double(dl);
    end
    val = val(:);
    rd  = recID(di);             rd  = rd(:);
    nD  = numel(rd);
    % depth index = rank of each data line within its record (1-based)
    isNew = [true; diff(rd)~=0];
    startPos = find(isNew); startPos = startPos(:);
    counts = diff([startPos; nD+1]);
    rep = repelem(startPos-1, counts); rep = rep(:);
    pos = (1:nD)' - rep;
    ok = (pos >= 1) & (pos <= numDepths);
    bs(sub2ind([nRec,numDepths], rd(ok), pos(ok))) = val(ok);
end
end

function dt = local_parse_times(s, tz)
% Vectorized parse of 'yyyyMMdd HH:mm:ss.SSS' (or without .SSS) string array.
s = string(s);
dt = datetime(s, "InputFormat","yyyyMMdd HH:mm:ss.SSS", "TimeZone", char(tz));
bad = isnat(dt) & strlength(s) > 0;
if any(bad)
    dt(bad) = datetime(s(bad), "InputFormat","yyyyMMdd HH:mm:ss", "TimeZone", char(tz));
end
end

function n = local_peek_numDepths(filepath)
fid = fopen(filepath, 'r');
if fid == -1, error("Could not open %s", filepath); end
cleanup = onCleanup(@() fclose(fid));
inBlock = false;
n = 0;
while ~feof(fid)
    line = fgetl(fid);
    if ~ischar(line), break; end
    if startsWith(line, '##DataStart')
        inBlock = true;
        n = 0;
        continue
    end
    if inBlock
        if startsWith(line, '##DataEnd')
            return
        else
            n = n + 1;
        end
    end
end
if n == 0
    error("Could not detect a DataStart/DataEnd block in %s", filepath);
end
end
