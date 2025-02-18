clear; clc;

% Get all .bin log files in the "logs" folder
logFiles = dir('logs/*.bin');

% Create a geoaxes figure for all flight paths
figure;
ax = geoaxes;
hold(ax, 'on');
colors = lines(length(logFiles));  % For differentiating paths

for idx = 1:length(logFiles)
    filePath = fullfile(logFiles(idx).folder, logFiles(idx).name);
    fprintf('Processing file: %s\n', logFiles(idx).name);
    
    %--- Read the Ardupilot Log File ---
    try
        ardupilotObj = ardupilotreader(filePath);
    catch ME
        warning('Could not read file %s: %s', logFiles(idx).name, ME.message);
        continue;
    end
    
    % Read the AHR2 (flight) messages and sort them
    flightData = readMessages(ardupilotObj, 'MessageName', {'AHR2'});
    if isempty(flightData)
        warning('No AHR2 messages found in %s', logFiles(idx).name);
        continue;
    end
    flightMsg = flightData.MsgData{1,1};
    flightMsg = sortrows(flightMsg);
    
    % Read the MODE messages and sort them
    modeMsg = readMessages(ardupilotObj, 'MessageName', {'MODE'});
    if isempty(modeMsg)
        warning('No MODE messages found in %s', logFiles(idx).name);
        continue;
    end
    modeData = modeMsg.MsgData{1,1};
    modeData = sortrows(modeData);
    
    % Convert to timetable if necessary (using 'timestamp' as row times)
    if ~istimetable(modeData)
        modeData = table2timetable(modeData, 'RowTimes', 'timestamp');
    end
    modeData = sortrows(modeData);
    
    %--- Identify Mode Transitions ---
    modes = modeData.Mode;
    ind0to10 = find(modes(1:end-1) == 0 & modes(2:end) ~= 0) + 1;
    ind10to0 = find(modes(1:end-1) ~= 0 & modes(2:end) == 0) + 1;
    
    if isempty(ind0to10), ind0to10 = 1; end
    if isempty(ind10to0), ind10to0 = length(modes); end
    
    % Extract row times for transitions and convert to durations
    t0to10 = modeData.Properties.RowTimes(ind0to10);
    t10to0 = modeData.Properties.RowTimes(ind10to0);
    d1 = duration(string(t0to10), 'InputFormat','hh:mm:ss.SSSSSS'); d1 = d1(1);
    d2 = duration(string(t10to0), 'InputFormat','hh:mm:ss.SSSSSS'); d2 = d2(end);
    
    % Filter flight data between mode transitions
    idxAHRS = flightMsg.timestamp >= d1 & flightMsg.timestamp <= d2;
    flightSubset = flightMsg(idxAHRS, :);
    if isempty(flightSubset)
        warning('No flight data in mode transition period for %s', logFiles(idx).name);
        continue;
    end
    
    %--- Extract GPS Data ---
    lat = flightSubset.Lat;   % Latitude values
    lon = flightSubset.Lng;   % Longitude values
    alt = flightSubset.Alt;   % Altitude values (optional)
    
    %--- Plot the Flight Path ---
    geoplot(ax, lat, lon, '-', 'LineWidth', 2, 'Color', colors(idx,:), ...
        'DisplayName', logFiles(idx).name);
    
    %--- Export to KML ---
    kmlFileName = sprintf('flightPath_%s.kml', erase(logFiles(idx).name, '.bin'));
    try
        kmlwriteline(kmlFileName, lat, lon, alt, ...
            'Name', 'Flight Path', ...
            'Color', 'blue', ...
            'LineWidth', 2, ...
            'AltitudeMode', 'relativeToGround', ...
            'Description', sprintf('Flight from ArduPilot log\nDate: %s', datetime('today')));
        assert(exist(kmlFileName, 'file') == 2, 'KML export failed');
        fprintf('KML file created: %s\n', fullfile(pwd, kmlFileName));
    catch ME
        warning('KML export failed for %s: %s', logFiles(idx).name, ME.message);
    end
end

% Finalize the plot
title(ax, 'Flight Paths from All Logs');
legend(ax, 'show');
geobasemap(ax, 'satellite');
hold(ax, 'off');
