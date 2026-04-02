function TT = read_rangelogger_log(filepath)
%READ_RANGELOGGER_LOG Read an Echologger AA400 RangeLogger *.log into a timetable.
%
% RangeLogger .log files have a variable-length device header (config dump)
% followed by a CSV header line containing "Altitude", then comma-separated
% data rows. This reader finds the CSV header, maps columns by name, and
% reads the data with textscan (fast for large files).
%
% Output timetable TT with variables:
%   Altitude_mm, Temperature_C, Battery_mV, Amplitude_pctFS

arguments
    filepath (1,1) string
end

fid = fopen(filepath, 'r');
if fid == -1
    error("read_rangelogger_log: Could not open %s", filepath);
end
cleanup = onCleanup(@() fclose(fid));

%% -- Find the CSV header line (contains "Altitude") ----------------------
headerLine = "";
headerLineNum = 0;
while ~feof(fid)
    line = fgetl(fid);
    headerLineNum = headerLineNum + 1;
    if ischar(line) && contains(line, 'Altitude', 'IgnoreCase', true) && contains(line, ',')
        headerLine = strtrim(string(line));
        break
    end
end
if headerLine == ""
    error("read_rangelogger_log: Could not find CSV header with 'Altitude' in %s", filepath);
end

%% -- Parse column names from header --------------------------------------
colNames = strtrim(strsplit(headerLine, ','));
colNames = colNames(colNames ~= "");  % drop trailing empties
nCols = numel(colNames);

% Build format string: first column is datetime string, rest are numeric
fmt = ['%s', repmat(' %f', 1, nCols - 1)];

%% -- Read data with textscan (fast) --------------------------------------
% fid is already positioned right after the header line
C = textscan(fid, fmt, 'Delimiter', ',', 'CollectOutput', false, ...
    'EmptyValue', NaN);

if isempty(C{1})
    error("read_rangelogger_log: No data rows found in %s", filepath);
end

% textscan can return off-by-one lengths when %s captures a partial row.
% Truncate all columns to the shortest length.
lengths = cellfun(@numel, C);
minLen = min(lengths);
for k = 1:numel(C)
    C{k} = C{k}(1:minLen);
end

%% -- Map columns by name -------------------------------------------------
findCol = @(pat) local_find_col(colNames, pat);

% DateTime (first column) — filter out non-data rows (device status messages
% that textscan picks up from the end of the file)
tStr = strtrim(C{1});
isDataRow = cellfun(@(s) ~isempty(s) && s(1) >= '0' && s(1) <= '9', tStr);
nDropped = sum(~isDataRow);
if nDropped > 0
    for k = 1:numel(C)
        C{k} = C{k}(isDataRow);
    end
    tStr = tStr(isDataRow);
end

t = datetime(tStr, "InputFormat", "yyyyMMdd HH:mm:ss.SSS");
t.TimeZone = "";

% Altitude (required)
altIdx = findCol("Altitude");
if altIdx == 0
    error("read_rangelogger_log: 'Altitude' column not found in header of %s", filepath);
end
Altitude_mm = C{altIdx};

% Optional columns
tempIdx = findCol("Temperature");
battIdx = findCol("Battery");
ampIdx  = findCol("Amplitude");

N = numel(t);
Temperature_C   = local_get_col(C, tempIdx, N);
Battery_mV      = local_get_col(C, battIdx, N);
Amplitude_pctFS = local_get_col(C, ampIdx,  N);

%% -- Filter out rows with missing amplitude (junk/header echoes) ----------
if ~all(isnan(Amplitude_pctFS))
    good = ~isnan(Amplitude_pctFS) & ~isnat(t);
    t               = t(good);
    Altitude_mm     = Altitude_mm(good);
    Temperature_C   = Temperature_C(good);
    Battery_mV      = Battery_mV(good);
    Amplitude_pctFS = Amplitude_pctFS(good);
end

% Force column vectors
t = t(:);
Altitude_mm = Altitude_mm(:);
Temperature_C = Temperature_C(:);
Battery_mV = Battery_mV(:);
Amplitude_pctFS = Amplitude_pctFS(:);

T = table(t, Altitude_mm, Temperature_C, Battery_mV, Amplitude_pctFS, ...
    'VariableNames', {'Time','Altitude_mm','Temperature_C','Battery_mV','Amplitude_pctFS'});
TT = table2timetable(T);
end

%% =========================================================================

function idx = local_find_col(colNames, pattern)
%LOCAL_FIND_COL  Find column index containing pattern (case-insensitive).
idx = 0;
for k = 1:numel(colNames)
    if contains(colNames(k), pattern, "IgnoreCase", true)
        idx = k;
        return
    end
end
end

function vals = local_get_col(C, idx, N)
%LOCAL_GET_COL  Extract column from textscan output, or return NaN vector.
if idx == 0 || idx > numel(C)
    vals = nan(N, 1);
else
    vals = C{idx};
    if numel(vals) < N
        vals = [vals; nan(N - numel(vals), 1)];
    end
end
end
