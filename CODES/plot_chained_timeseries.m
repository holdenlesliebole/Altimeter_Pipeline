function fig = plot_chained_timeseries(C, opts)
%PLOT_CHAINED_TIMESERIES  Plot chained multi-deployment bed level with survey markers.
%
% Inputs:
%   C : struct from chain_deployments
%
% Optional name-value:
%   instrumentLat  : for survey overlay
%   instrumentLon  : for survey overlay
%   smFilePath     : path to SM files
%   title          : plot title
%   yAxisMode      : "elevation" (m NAVD88) or "bedlevel" (mm relative)
%   savePath       : save PNG to this path

arguments
    C (1,1) struct
    opts.instrumentLat (1,1) double = NaN
    opts.instrumentLon (1,1) double = NaN
    opts.smFilePath (1,1) string = "/Volumes/group/MOPS/"
    opts.title (1,1) string = ""
    opts.yAxisMode (1,1) string = "bedlevel"
    opts.savePath (1,1) string = ""
end

%% -- Load surveys for overlay ---------------------------------------------
surveyDates = [];
surveyElevs = [];

if ~isnan(opts.instrumentLat)
    [mopNum, xShore] = LatLon2MopxshoreX(opts.instrumentLat, opts.instrumentLon);
    mopNum = round(mopNum);
    smFile = fullfile(opts.smFilePath, sprintf('M%05dSM.mat', mopNum));

    if isfile(smFile)
        load(smFile, 'SM');
        tRange = [min(C.time) - days(30), max(C.time) + days(30)];
        for k = 1:numel(SM)
            if SM(k).Datenum < datenum(tRange(1)) || SM(k).Datenum > datenum(tRange(2))
                continue
            end
            X1D = SM(k).X1D; Z1D = SM(k).Z1Dmean;
            validX = ~isnan(Z1D);
            if sum(validX) < 3, continue; end
            elev = interp1(X1D(validX), Z1D(validX), xShore, 'linear', NaN);
            if isnan(elev) || elev > -3, continue; end
            surveyDates(end+1) = SM(k).Datenum; %#ok
            surveyElevs(end+1) = elev; %#ok
        end
    end
end

%% -- Plot -----------------------------------------------------------------
fig = figure('Color','w','Visible','off','Position',[100 100 1200 450]);

if opts.yAxisMode == "elevation" && any(~isnan(C.elevation_m))
    % Plot in absolute NAVD88 elevation
    plot(C.time, C.elevation_m, 'Color',[0.18 0.45 0.75], 'LineWidth',0.8); hold on

    % Survey markers
    if ~isempty(surveyDates)
        survDT = datetime(surveyDates, 'ConvertFrom', 'datenum');
        plot(survDT, surveyElevs, 'rs', 'MarkerSize', 8, 'MarkerFaceColor', 'r', ...
            'DisplayName', 'Survey');
    end

    ylabel('Elevation (m NAVD88)');
    legend('Instrument','Survey','Location','best');
else
    % Plot relative bed level with IQR bands
    valid = ~isnan(C.bedlevel_mm);
    if any(valid) && any(~isnan(C.bedlevel_iqr_mm))
        lo = C.bedlevel_mm - C.bedlevel_iqr_mm/2;
        hi = C.bedlevel_mm + C.bedlevel_iqr_mm/2;
        vIdx = find(valid & ~isnan(C.bedlevel_iqr_mm));
        fill([C.time(vIdx); flipud(C.time(vIdx))], ...
             [lo(vIdx); flipud(hi(vIdx))], ...
             [0.75 0.85 0.95], 'EdgeColor','none', 'FaceAlpha',0.5); hold on
    end
    plot(C.time, C.bedlevel_mm, 'Color',[0.18 0.45 0.75], 'LineWidth',0.8); hold on

    % Survey markers (convert to relative, anchored to instrument at first survey)
    if ~isempty(surveyDates)
        survDT = datetime(surveyDates, 'ConvertFrom', 'datenum');
        survBL = -(surveyElevs - surveyElevs(1)) * 1000;
        % Align to instrument at first survey
        [~, mIdx] = min(abs(C.time - survDT(1)));
        if ~isnan(C.bedlevel_mm(mIdx))
            offset = C.bedlevel_mm(mIdx) - survBL(1);
            plot(survDT, survBL + offset, 'rs', 'MarkerSize', 8, ...
                'MarkerFaceColor', 'r', 'DisplayName', 'Survey');
        end
    end

    ylabel('Bed level change (mm)');
    if ~isempty(surveyDates)
        legend('IQR','Instrument','Survey','Location','best');
    end
end

% Deployment boundaries as subtle vertical lines
depIDs = unique(C.deploymentID, 'stable');
for d = 2:numel(depIDs)
    idx = find(C.deploymentID == depIDs(d), 1);
    if ~isempty(idx)
        xline(C.time(idx), ':', 'Color',[0.7 0.7 0.7], 'HandleVisibility','off');
    end
end

if opts.title ~= ""
    title(opts.title, 'Interpreter','none');
end
grid on; box off
xlabel('Date');

%% -- Save -----------------------------------------------------------------
if opts.savePath ~= ""
    exportgraphics(fig, opts.savePath, 'Resolution', 200);
    fprintf('Saved: %s\n', opts.savePath);
end
end
