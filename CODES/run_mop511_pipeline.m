% run_mop511_pipeline.m
% Example end-to-end processing + caching for a deployment.
clear; close all;

cfg = struct();
cfg.altimeter_logs = [
    "/Volumes/group/Altimeter_data/2024_SouthSIOPier/Data/20240402_121226_RANGELOGGER450kHz_ID_0208.log"
    "/Volumes/group/Altimeter_data/2024_SouthSIOPier/Data/20240423_124416_RANGELOGGER450kHz_ID_0208.log"
];

cfg.echosounder_logs = [
    "/Volumes/group/Altimeter_data/2024_SouthSIOPier/Data/20240401MOP511.log"
    "/Volumes/group/Altimeter_data/2024_SouthSIOPier/Data/20240402MOP511.log"
    % add pt2 files here
];

cfg.output_mat = "processed_mop511_combined.mat";

% --- Altimeter: read + concatenate ---
TTa = timetable();
for i = 1:numel(cfg.altimeter_logs)
    TT = read_rangelogger_log(cfg.altimeter_logs(i));
    TTa = [TTa; TT]; %#ok<AGROW>
end
TTa = sortrows(TTa);

% --- Altimeter QC ---
altParams = struct("winMovMean", minutes(15), "thr1_mm",200, "thr2_mm",100, "jump_mm",10);
[TTa.Altitude_mm, TTa.QF] = qc_altitude(TTa.Altitude_mm, TTa.Time, altParams);

% --- Echosounder: read + concatenate ---
Eall = [];
for i = 1:numel(cfg.echosounder_logs)
    Ei = read_echosounder_log(cfg.echosounder_logs(i), "TimeOffsetHours", 7); % adjust if needed
    if isempty(Eall)
        Eall = Ei;
    else
        Eall.time = [Eall.time; Ei.time];
        Eall.pitch_deg = [Eall.pitch_deg; Ei.pitch_deg];
        Eall.roll_deg = [Eall.roll_deg; Ei.roll_deg];
        Eall.altitude_mm = [Eall.altitude_mm; Ei.altitude_mm];
        Eall.backscatter = [Eall.backscatter; Ei.backscatter];
    end
end
% sort by time
[ts, order] = sort(Eall.time);
Eall.time = ts;
Eall.pitch_deg = Eall.pitch_deg(order);
Eall.roll_deg  = Eall.roll_deg(order);
Eall.altitude_mm = Eall.altitude_mm(order);
Eall.backscatter = Eall.backscatter(order,:);

% --- Echosounder QC ---
[Eall, qfEcho] = qc_echosounder(Eall, struct("tilt_deg",2, "altitudeParams", altParams));

% --- Cache ---
save(cfg.output_mat, "TTa", "Eall", "qfEcho", "-v7.3");

% --- Plot ---
depth_from_sensor_m = linspace(0, 2, size(Eall.backscatter,2))';
plot_altimeter_echosounder(TTa, Eall, depth_from_sensor_m);
