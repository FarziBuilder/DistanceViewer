%% 1. Create an ardupilotreader object to manage the log file
logFile = "logs/hyd_26_flight.bin";  % Change to your file path
ardupilotObj = ardupilotreader(logFile);

%% 2. Read ATT messages
attMessages = readMessages(ardupilotObj, 'MessageName', {'ATT'});

%% 3. Read Mode Change messages and convert to timetable
modeMsg  = readMessages(ardupilotObj, 'MessageName', {'MODE'});
modeData = modeMsg.MsgData{1,1};

% Convert to timetable if not already
if ~istimetable(modeData)
    modeData = table2timetable(modeData, 'RowTimes', 'timestamp');
end
modeData = sortrows(modeData);     % Sort by timestamp

%% 4. Identify mode transitions (example: from Mode=0 to Mode~=0 and vice versa)
modes    = modeData.Mode;
ind0to10 = find(modes(1:end-1) == 0 & modes(2:end) ~= 0) + 1;
ind10to0 = find(modes(1:end-1) ~= 0 & modes(2:end) == 0) + 1;

% Default to first or last index if not found
if isempty(ind0to10), ind0to10 = 1; end
if isempty(ind10to0), ind10to0 = length(modes); end

% Extract the corresponding row times
t0to10 = modeData.Properties.RowTimes(ind0to10);
t10to0 = modeData.Properties.RowTimes(ind10to0);

% Convert to duration or use them as times directly
d1 = duration(string(t0to10), 'InputFormat','hh:mm:ss.SSSSSS');
d2 = duration(string(t10to0), 'InputFormat','hh:mm:ss.SSSSSS');
d1 = d1(1);
d2 = d2(end);

%% 5. Subset the ATT data to the time window of interest
attData = attMessages.MsgData{1,1};
idx     = attData.timestamp >= d1 & attData.timestamp <= d2;  
attSubset = attData(idx,:);

% For convenience, extract roll and pitch from the subset
roll    = attSubset.Roll;
pitch   = attSubset.Pitch;
attTime = attSubset.timestamp;   % Timestamps of the subset

%% 6. Read GPS messages (for altitude) and subset to the same time window
ahrsMsg = readMessages(ardupilotObj, 'MessageName', {'AHR2'});
ahrsData = ahrsMsg.MsgData{1,1};
ahrsData = sortrows(ahrsData);

idxAHRS     = ahrsData.timestamp >= d1 & ahrsData.timestamp <= d2;
ahrsSubset  = ahrsData(idxAHRS,:);

%% 7. Synchronize ATT and GPS data on the overlapping timestamps
%    Using 'nearest' method ensures each row is matched to the closest time
syncTT = synchronize(attSubset, ahrsSubset, 'common','nearest');
syncTT.Properties.VariableNames

% After synchronization, you have matched "Roll", "Pitch", and "Alt" 
% (and other variables) by their nearest timestamps.  

%% 8. Plot Roll and Pitch vs. Altitude within the selected time window
figure('Name','Roll & Pitch vs Altitude (Selected Mode Times)');

% -- Roll vs Altitude --
subplot(2,1,1);
plot(syncTT.Alt, syncTT.Roll_attSubset, 'b.-');
set(gca, 'XDir', 'reverse');  % Reverse x-axis direction
grid on; 
xlabel('Altitude (m or ft)');  % Adjust unit as appropriate
ylabel('Roll (deg)');
title('Roll vs. Altitude');

% -- Pitch vs Altitude --
subplot(2,1,2);
plot(syncTT.Alt, syncTT.Pitch_attSubset, 'r.-');
set(gca, 'XDir', 'reverse');  % Reverse x-axis direction
grid on;
xlabel('Altitude (m or ft)');  % Adjust unit as appropriate
ylabel('Pitch (deg)');
title('Pitch vs. Altitude');


% %% Plot just the altitude from the synchronized timetable
% figure('Name','Altitude Over Time');
% plot(syncTT.timestamp, syncTT.Alt, 'b.-');
% grid on;
% xlabel('Time');
% ylabel('Altitude (m or ft)');  % Adjust unit as needed
% title('Altitude vs. Time');
