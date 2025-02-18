clear; clc;

% Get all .bin log files in the "logs" folder
logFiles = dir('logs/*.bin');

% Create a colormap for differentiating lines (optional)
colors = lines(length(logFiles));

for idx = 1:length(logFiles)
    filePath = fullfile(logFiles(idx).folder, logFiles(idx).name);
    fprintf('Processing file: %s\n', logFiles(idx).name);
    
    % Create an ardupilotreader object
    try
        ardupilotObj = ardupilotreader(filePath);
    catch ME
        warning('Could not read file %s: %s', logFiles(idx).name, ME.message);
        continue;
    end
    
    %% 1. Read ATT messages
    attMessages = readMessages(ardupilotObj, 'MessageName', {'ATT'});
    if isempty(attMessages)
        warning('No ATT messages in file %s', logFiles(idx).name);
        continue;
    end
    attData = attMessages.MsgData{1,1};
    
    %% 2. Read MODE messages and convert to timetable if necessary
    modeMsg = readMessages(ardupilotObj, 'MessageName', {'MODE'});
    if isempty(modeMsg)
        warning('No MODE messages in file %s', logFiles(idx).name);
        continue;
    end
    modeData = modeMsg.MsgData{1,1};
    if ~istimetable(modeData)
        modeData = table2timetable(modeData, 'RowTimes', 'timestamp');
    end
    modeData = sortrows(modeData);
    
    %% 3. Identify mode transitions (from Mode=0 to Mode~=0 and vice versa)
    modes = modeData.Mode;
    ind0to10 = find(modes(1:end-1)==0 & modes(2:end)~=0) + 1;
    ind10to0 = find(modes(1:end-1)~=0 & modes(2:end)==0) + 1;
    if isempty(ind0to10), ind0to10 = 1; end
    if isempty(ind10to0), ind10to0 = length(modes); end
    
    % Extract the corresponding row times
    t0to10 = modeData.Properties.RowTimes(ind0to10);
    t10to0 = modeData.Properties.RowTimes(ind10to0);
    
    % Convert row times to durations (using a fixed input format)
    d1 = duration(string(t0to10), 'InputFormat','hh:mm:ss.SSSSSS'); d1 = d1(1);
    d2 = duration(string(t10to0), 'InputFormat','hh:mm:ss.SSSSSS'); d2 = d2(end);
    
    %% 4. Subset the ATT data to the time window of interest
    idxATT = attData.timestamp >= d1 & attData.timestamp <= d2;
    attSubset = attData(idxATT,:);
    if isempty(attSubset)
        warning('No ATT data in mode transition period for file %s', logFiles(idx).name);
        continue;
    end
    
    %% 5. Read AHR2 messages (for altitude) and subset to the same time window
    ahrsMsg = readMessages(ardupilotObj, 'MessageName', {'AHR2'});
    if isempty(ahrsMsg)
        warning('No AHR2 messages in file %s', logFiles(idx).name);
        continue;
    end
    ahrsData = ahrsMsg.MsgData{1,1};
    ahrsData = sortrows(ahrsData);
    
    idxAHR = ahrsData.timestamp >= d1 & ahrsData.timestamp <= d2;
    ahrsSubset = ahrsData(idxAHR,:);
    if isempty(ahrsSubset)
        warning('No AHR2 data in mode transition period for file %s', logFiles(idx).name);
        continue;
    end
    
    %% 6. Synchronize ATT and AHR2 data on the overlapping timestamps
    syncTT = synchronize(attSubset, ahrsSubset, 'common','nearest');
    
    if ~all(ismember({'Roll_attSubset', 'Pitch_attSubset', 'Alt'}, syncTT.Properties.VariableNames))
        warning('Synchronized fields missing in file %s', logFiles(idx).name);
        continue;
    end
    
    %% 7. Create a new figure for this log file
    fig = figure('Name', sprintf('Roll & Pitch vs Altitude: %s', logFiles(idx).name));
    
    % --- Subplot 1: Roll vs Altitude ---
    subplot(2,1,1);
    plot(syncTT.Alt, syncTT.Roll_attSubset, '.-', 'Color', colors(idx,:), 'LineWidth', 1.5);
    set(gca, 'XDir', 'reverse');  % Reverse x-axis direction
    grid on;
    xlabel('Altitude (m or ft)');
    ylabel('Roll (deg)');
    title(sprintf('Roll vs. Altitude for %s', logFiles(idx).name));
    
    % --- Subplot 2: Pitch vs Altitude ---
    subplot(2,1,2);
    plot(syncTT.Alt, syncTT.Pitch_attSubset, '.-', 'Color', colors(idx,:), 'LineWidth', 1.5);
    set(gca, 'XDir', 'reverse');  % Reverse x-axis direction
    grid on;
    xlabel('Altitude (m or ft)');
    ylabel('Pitch (deg)');
    title(sprintf('Pitch vs. Altitude for %s', logFiles(idx).name));
end
