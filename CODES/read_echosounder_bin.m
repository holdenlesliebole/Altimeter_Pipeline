function E = read_echosounder_bin(filepath, opts)
%READ_ECHOSOUNDER_BIN  Read an Echologger EA400 echosounder .BIN binary file.
%
% E = read_echosounder_bin(filepath)
% E = read_echosounder_bin(filepath, "TimeOffsetHours", 7)
% E = read_echosounder_bin(filepath, "RangeResolution_m", 0.0075)
%
% Output struct E (same fields as read_echosounder_log for interchangeability):
%   .time          (datetime, Nx1)
%   .pitch_deg     (double, Nx1)
%   .roll_deg      (double, Nx1)
%   .altitude_mm   (double, Nx1) -- converted from meters in BIN to mm
%   .backscatter   (double, NxM) -- M = num_samples (depth bins)
%   .temperature_C (double, Nx1) -- temperature from EA400 BIN STAT footer
%   .numEntries    (scalar)
%   .numDepths     (scalar)
%
% Optional parameters:
%   "TimeOffsetHours" (default 0): hours to add to timestamps
%   "RangeResolution_m" (default 0.0075): depth bin spacing in meters

arguments
    filepath {mustBeTextScalar}
    opts.TimeOffsetHours (1,1) double = 0
    opts.RangeResolution_m (1,1) double = 0.0075
end

filepath = string(filepath);

%% -- Read entire file into memory -----------------------------------------
fid = fopen(filepath, 'r');
if fid == -1
    error("read_echosounder_bin: Could not open %s", filepath);
end
raw = fread(fid, inf, '*uint8');
fclose(fid);

fileSize = numel(raw);
if fileSize < 128
    error("read_echosounder_bin: File too small to contain header (%d bytes): %s", ...
        fileSize, filepath);
end

%% -- Parse file header (128 bytes) ----------------------------------------
header_size = typecast(raw(1:4), 'uint32');
if header_size ~= 128
    warning("read_echosounder_bin: header_size = %d (expected 128), proceeding anyway.", ...
        header_size);
end

%% -- Determine record size from first DATA record -------------------------
% First record starts at offset 128 (1-indexed: byte 129)
dataStart = 129;  % 1-indexed

% Verify DATA marker
if fileSize < dataStart + 63
    error("read_echosounder_bin: File too small for first DATA record: %s", filepath);
end
dataMarker = char(raw(dataStart:dataStart+3))';
if ~strcmp(dataMarker, 'DATA')
    error("read_echosounder_bin: Expected 'DATA' marker at byte 129, got '%s': %s", ...
        dataMarker, filepath);
end

% num_samples from first DATA header (offset +12 within record, uint16 LE)
numSamples = double(typecast(raw(dataStart+12:dataStart+13), 'uint16'));
if numSamples == 0 || numSamples > 2000
    error("read_echosounder_bin: Unexpected num_samples = %d in first record: %s", ...
        numSamples, filepath);
end

recordSize = 64 + numSamples * 2 + 64;  % DATA header + backscatter + STAT footer
dataBytes  = fileSize - 128;

% Number of complete records
numRecords = floor(dataBytes / recordSize);
if numRecords == 0
    error("read_echosounder_bin: No complete records found (recordSize=%d, dataBytes=%d): %s", ...
        recordSize, dataBytes, filepath);
end

tailBytes = dataBytes - numRecords * recordSize;
if tailBytes > 0
    warning("read_echosounder_bin: %d trailing bytes after %d records (ignored).", ...
        tailBytes, numRecords);
end

fprintf("  read_echosounder_bin: %s\n    %d records, %d depth bins, record_size=%d bytes\n", ...
    filepath, numRecords, numSamples, recordSize);

%% -- Reshape into record matrix (memory-efficient) -----------------------
% Reshape the raw byte vector so each row is one complete record.
% This avoids building huge index matrices for large files.
usableBytes = numRecords * recordSize;
recMatrix = reshape(raw(129 : 128 + usableBytes), recordSize, numRecords)';
% recMatrix is numRecords x recordSize uint8

% -- Timestamps (DATA header offset +16, uint32 LE) -----------------------
timestamps = local_uint32_at(recMatrix, 17);   % 1-indexed col 17:20

% -- Backscatter (DATA header + 64 bytes, numSamples x uint16 LE) ---------
bsCols = 65 : 64 + numSamples * 2;             % 1-indexed columns
bsBytes = recMatrix(:, bsCols);                 % numRecords x numSamples*2
lo = double(bsBytes(:, 1:2:end));               % low bytes  (odd cols)
hi = double(bsBytes(:, 2:2:end));               % high bytes (even cols)
backscatter = uint16(lo + hi * 256);            % numRecords x numSamples

% -- STAT footer fields (offset from record start = 64 + numSamples*2) ----
statCol = 64 + numSamples * 2;                  % 0-indexed STAT start
temperature = local_float32_at(recMatrix, statCol + 13);  % STAT +12
altitude_m  = local_float32_at(recMatrix, statCol + 21);  % STAT +20
pitch_deg   = local_float32_at(recMatrix, statCol + 25);  % STAT +24
roll_deg    = local_float32_at(recMatrix, statCol + 29);  % STAT +28

%% -- Build output struct --------------------------------------------------
% Convert unix timestamps to datetime
t = datetime(double(timestamps), 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');

% Apply time offset
if opts.TimeOffsetHours ~= 0
    t = t + hours(opts.TimeOffsetHours);
end

% Set to naive datetime (no time zone), matching read_echosounder_log behavior
t.TimeZone = "";

E = struct();
E.time          = t;
E.pitch_deg     = double(pitch_deg);
E.roll_deg      = double(roll_deg);
E.altitude_mm   = double(altitude_m) * 1000;   % meters -> mm
E.backscatter   = double(backscatter);
E.temperature_C = double(temperature);
E.numEntries    = numRecords;
E.numDepths     = numSamples;

end

%% =========================================================================
%  Local helper functions
%% =========================================================================

function vals = local_uint32_at(recMatrix, col)
%LOCAL_UINT32_AT  Read uint32 LE from 4 consecutive columns starting at col.
b = recMatrix(:, col:col+3);
vals = uint32(b(:,1)) + uint32(b(:,2))*uint32(256) + ...
       uint32(b(:,3))*uint32(65536) + uint32(b(:,4))*uint32(16777216);
end

function vals = local_float32_at(recMatrix, col)
%LOCAL_FLOAT32_AT  Read float32 LE from 4 consecutive columns starting at col.
u32 = local_uint32_at(recMatrix, col);
vals = typecast(u32, 'single');
end
