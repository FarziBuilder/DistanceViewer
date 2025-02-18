clear; clc;

% Get all .bin log files in the "logs" folder
logFiles = dir('logs/*.bin');

for idx = 1:length(logFiles)
    filePath = fullfile(logFiles(idx).folder, logFiles(idx).name);
    fprintf('Processing file: %s\n', logFiles(idx).name);
    
    %% Step 1: Read the Flight Log Data
    try
        bin = ardupilotreader(filePath);
    catch ME
        warning('Could not read file %s: %s', logFiles(idx).name, ME.message);
        continue;
    end
    
    %% Step 2: Extract GPS and MODE Messages
    gpsMsg = readMessages(bin, 'MessageName', {'GPS'});
    if isempty(gpsMsg)
        warning('No GPS messages in file %s', logFiles(idx).name);
        continue;
    end
    gpsData = gpsMsg.MsgData{1,1};
    
    modeMsg = readMessages(bin, 'MessageName', {'MODE'});
    if isempty(modeMsg)
        warning('No MODE messages in file %s', logFiles(idx).name);
        continue;
    end
    modeData = modeMsg.MsgData{1,1};
    
    %% Convert modeData to a timetable if needed and sort by timestamp
    if ~istimetable(modeData)
        modeData = table2timetable(modeData, 'RowTimes', 'timestamp');
    end
    modeData = sortrows(modeData);
    
    modes = modeData.Mode;
    
    %% Identify mode transitions
    ind0to10 = find(modes(1:end-1) == 0 & modes(2:end) ~= 0) + 1;
    ind10to0 = find(modes(1:end-1) ~= 0 & modes(2:end) == 0) + 1;
    
    if isempty(ind0to10), ind0to10 = 1; end
    if isempty(ind10to0), ind10to0 = length(modes); end
    
    % Get the corresponding row times and convert to durations
    t0to10 = modeData.Properties.RowTimes(ind0to10);
    t10to0 = modeData.Properties.RowTimes(ind10to0);
    d1 = duration(string(t0to10), 'InputFormat','hh:mm:ss.SSSSSS'); d1 = d1(1);
    d2 = duration(string(t10to0), 'InputFormat','hh:mm:ss.SSSSSS'); d2 = d2(end);
    
    %% Step 3: Subset the GPS Data Based on the Time Window
    idxTime = gpsData.timestamp >= d1 & gpsData.timestamp <= d2;
    gpsSubset = gpsData(idxTime,:);
    
    if isempty(gpsSubset)
        warning('No GPS data in mode transition period for file %s', logFiles(idx).name);
        continue;
    end
    
    % Extract GPS fields
    lat    = gpsSubset.Lat;    % Latitude in degrees
    lon    = gpsSubset.Lng;    % Longitude in degrees
    alt    = gpsSubset.Alt;    % Altitude in meters
    timeVec = gpsSubset.timestamp; % Duration array
    
    %% Step 4: Compute horizontal distance between consecutive samples
    distDeg = distance(lat(1:end-1), lon(1:end-1), lat(2:end), lon(2:end));
    distMeters = deg2km(distDeg) * 1000;  % Convert km to meters
    
    % Time differences in seconds
    dt = seconds(diff(timeVec));
    
    % Horizontal velocity (m/s)
    horizontalVelocity = distMeters ./ dt;
    
    %% Step 5: Compute vertical velocity (m/s)
    dAlt = diff(alt);
    verticalVelocity = dAlt ./ dt;
    
    %% Step 6: Compute total velocity (m/s)
    totalVelocity = sqrt(horizontalVelocity.^2 + verticalVelocity.^2);
    
    %% Step 7: Plot velocities vs. time on a new figure for this log file
    plotTime = timeVec(1:end-1);
    
    figure('Name', sprintf('Flight Velocities: %s', logFiles(idx).name));
    hold on;
    plot(plotTime, horizontalVelocity, 'LineWidth', 1.5, 'DisplayName', 'Horizontal Vel');
    plot(plotTime, verticalVelocity,   'LineWidth', 1.5, 'DisplayName', 'Vertical Vel');
    plot(plotTime, totalVelocity,      'LineWidth', 1.5, 'DisplayName', 'Total Vel');
    xlabel('Time');
    ylabel('Velocity (m/s)');
    title(sprintf('Flight Velocities for %s', logFiles(idx).name));
    legend('Location','best');
    grid on;
    hold off;
    
    %% Optional: Print total horizontal distance for this log file
    totalDistanceMeters = sum(distMeters);
    fprintf('Total Horizontal Distance for %s: %.2f meters\n', logFiles(idx).name, totalDistanceMeters);
end
