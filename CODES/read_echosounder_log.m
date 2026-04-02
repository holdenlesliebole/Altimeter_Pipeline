function E = read_echosounder_log(filepath, varargin)
%READ_ECHOSOUNDER_LOG Parse an Echologger EA400 echosounder *.log with repeating headers + DataStart/DataEnd blocks.
%
% E fields:
%   time   (datetime)
%   pitch_deg, roll_deg
%   altitude_mm  (distance to bed; converted from meters if present)
%   backscatter  (N x M double)
%   numEntries, numDepths
%
% Optional name/value:
%   "TimeZone"      : e.g., "UTC" (default "")
%   "TimeOffsetHours": numeric (default 0) to shift after parsing
%
% Notes:
% - First pass counts '##DataEnd' to preallocate rows.
% - We "peek" the first data block to determine numDepths.

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

% --- Pass 1: count entries (DataEnd markers) ---
numEntries = 0;
chunkSize = 5e6; % chars; tune as needed
fid = fopen(filepath, 'r');
if fid == -1, error("Could not open %s", filepath); end
cleanup = onCleanup(@() fclose(fid));

while ~feof(fid)
    chunk = fread(fid, chunkSize, '*char')';
    if isempty(chunk), break; end
    numEntries = numEntries + local_count_substr(chunk, '##DataEnd');
end

% --- Preallocate ---
t = NaT(numEntries,1);
pitch = nan(numEntries,1);
roll  = nan(numEntries,1);
alt_m = nan(numEntries,1);
backscatter = nan(numEntries, numDepths);

% --- Pass 2: parse line-by-line ---
frewind(fid);
idx = 0;
inBlock = false;
k = 0;

while ~feof(fid)
    line = fgetl(fid);
    if ~ischar(line), break; end

    if startsWith(line, '#TimeLocal')
        idx = idx + 1;
        k = 0;
        inBlock = false;

        ts = strtrim(extractAfter(string(line), '#TimeLocal'));
        % Common formats: 'yyyyMMdd HH:mm:ss.SSS' or without milliseconds
        if strlength(ts) >= 18
            try
                t(idx) = datetime(ts, "InputFormat","yyyyMMdd HH:mm:ss.SSS", "TimeZone", tz);
            catch
                t(idx) = datetime(ts, "InputFormat","yyyyMMdd HH:mm:ss", "TimeZone", tz);
            end
        else
            t(idx) = datetime(ts, "InputFormat","yyyyMMdd HH:mm:ss", "TimeZone", tz);
        end

    elseif startsWith(line, '#Pitch,deg')
        pitch(idx) = str2double(extractAfter(string(line), '#Pitch,deg'));

    elseif startsWith(line, '#Roll,deg')
        roll(idx) = str2double(extractAfter(string(line), '#Roll,deg'));

    elseif startsWith(line, '#Altitude,m')
        alt_m(idx) = str2double(extractAfter(string(line), '#Altitude,m'));

    elseif startsWith(line, '##DataStart')
        inBlock = true;
        k = 0;

    elseif startsWith(line, '##DataEnd')
        inBlock = false;

    elseif inBlock
        k = k + 1;
        if k <= numDepths
            v = str2double(line);
            backscatter(idx, k) = v;
        end
    end
end

% Convert to mm if altitude was in meters
altitude_mm = alt_m * 1000;

% Apply offset and drop time zone for downstream plotting
if offsetH ~= 0
    t = t + hours(offsetH);
end
t.TimeZone = "";

E = struct();
E.time = t;
E.pitch_deg = pitch;
E.roll_deg  = roll;
E.altitude_mm = altitude_mm;
E.backscatter = backscatter;
E.numEntries = numEntries;
E.numDepths = numDepths;
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

function c = local_count_substr(haystackChar, needle)
% Fast-ish count of needle in a char vector.
if isempty(haystackChar)
    c = 0; return
end
idx = strfind(haystackChar, needle);
c = numel(idx);
end
