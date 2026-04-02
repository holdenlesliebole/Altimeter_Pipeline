function fig = plot_altimeter_echosounder(TT_alt, E, depth_from_sensor_m)
%PLOT_ALTIMETER_ECHOSOUNDER Quick-look plots: bed level (altimeter + echosounder) and backscatter.
% Returns the figure handle so the caller can exportgraphics() and close it
% without the figure being displayed (batch-safe).

arguments
    TT_alt timetable
    E (1,1) struct
    depth_from_sensor_m (:,1) double
end

bed_alt  = altitude_to_bedlevel(TT_alt.Altitude_mm);
bed_echo = altitude_to_bedlevel(E.altitude_mm);

fig = figure("Color","w","Visible","off");
tiledlayout(3,1,"TileSpacing","compact","Padding","compact");

nexttile
plot(TT_alt.Time, bed_alt, 'DisplayName','Altimeter bed (mm)'); hold on
plot(E.time, bed_echo, 'DisplayName','Echosounder bed (mm)');
ylabel('Bed level change (mm)');
legend('Location','best'); grid on

nexttile
plot(E.time, E.pitch_deg, 'DisplayName','Pitch'); hold on
plot(E.time, E.roll_deg, 'DisplayName','Roll');
ylabel('deg'); legend('Location','best'); grid on

nexttile
% backscatter as a color field
if isempty(E.backscatter) || all(isnan(E.backscatter(:)))
    text(0.1,0.5,'No backscatter loaded','Units','normalized');
else
    % y-axis is distance from sensor (m), increasing downward
    imagesc(E.time, depth_from_sensor_m, E.backscatter');
    axis xy
    ylabel('Range from sensor (m)');
    xlabel('Time');
    cb = colorbar; cb.Label.String = 'Backscatter (arb)';
    hold on
    % overlay bed (range to bed, in m)
    plot(E.time, E.altitude_mm/1000, 'k', 'LineWidth', 1.0, 'DisplayName','Bed (m)');
end
end
