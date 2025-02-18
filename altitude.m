clear; clc;

% Get all .bin log files in the "logs" folder
logFiles = dir('logs/*.bin');

figure; hold on;  % Create one figure for all plots

% Prepare a colormap for differentiating lines
colors = lines(length(logFiles));

for idx = 1:length(logFiles)
    % Construct the full file path
    filePath = fullfile(logFiles(idx).folder, logFiles(idx).name);
    
    % Create an ardupilotreader object for the current log file
    ardupilotObj = ardupilotreader(filePath);
    
    % Read the AHR2 messages (fused state data)
    ahrsMsg = readMessages(ardupilotObj, 'MessageName', {'AHR2'});
    
    % If no AHR2 messages are found, skip this file
    if isempty(ahrsMsg)
        fprintf('No AHR2 messages found in file: %s\n', logFiles(idx).name);
        continue;
    end
    
    % Extract the first AHR2 message data
    ahrsData = ahrsMsg.MsgData{1,1};
    
    % Convert to timetable (if not already) using 'TimeUS' as the row times and sort by time
    if ~istimetable(ahrsData)
        ahrsData = table2timetable(ahrsData, 'RowTimes', 'TimeUS');
    end
    ahrsData = sortrows(ahrsData);
    
    % Extract the altitude value (assuming 'Alt' holds the altitude)
    altitude2 = ahrsData.Alt;
    
    % Determine the time axis: use 'timestamp' if it exists; otherwise, use row times
    if ismember('timestamp', ahrsData.Properties.VariableNames)
        time = ahrsData.timestamp;
    else
        time = ahrsData.Properties.RowTimes;
    end
    
    % Plot the altitude data for the current log file with a unique color and add a legend entry
    plot(time, altitude2, 'Color', colors(idx,:), 'DisplayName', logFiles(idx).name, 'LineWidth', 1.5);
end

grid on;
xlabel('Time (sec)');
ylabel('Altitude (units)');  % Adjust the units as needed (e.g., m or cm)
title('Fused Altitude from AHR2 for All Log Files');
legend('show');
hold off;
