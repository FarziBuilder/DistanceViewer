clear; clc;

%% Step 1: Read the Flight Log Data
% Replace the file path with the location of your flight log.
bin = ardupilotreader('logs/hyd_26_flight.bin');

%% Step 2: Extract GPS Messages
gpsMsg = readMessages(bin, 'MessageName', {'GPS'});

% Extract the GPS data (assumed to be in the first element of MsgData).
gpsData = gpsMsg.MsgData{1,1};
%disp(gpsData);

% Read Mode Change messages.
modeMsg = readMessages(bin, 'MessageName', {'MODE'});
modeData = modeMsg.MsgData{1,1};

%% Step 2: Convert to Timetable (if not already)
% It is assumed that modeData has a variable named 'timestamp'.
if ~istimetable(modeData)
    % Convert modeData to a timetable using the 'timestamp' variable.
    modeData = table2timetable(modeData, 'RowTimes', 'timestamp');
end

% (Optional) Sort the timetable by timestamp to ensure proper ordering.
modeData = sortrows(modeData);


modes = modeData.Mode;
%disp(modeData);

% Find indices where the mode changes from 0 to 10.
% (The transition time is taken as the timestamp of the first record with mode 10.)
%% 1) Identify mode transitions
ind0to10 = find(modes(1:end-1) == 0 & modes(2:end) ~= 0) + 1;
disp(ind0to10)
ind10to0 = find(modes(1:end-1) ~= 0 & modes(2:end) == 0) + 1;
disp(ind10to0)

if isempty(ind0to10)
    ind0to10 = 0;
end

% If ind10to0 is empty, set to last row number
if isempty(ind10to0)
    ind10to0 = length(modes);
end

% Extract the corresponding row times from your timetable
t0to10 = modeData.Properties.RowTimes(ind0to10);
t10to0 = modeData.Properties.RowTimes(ind10to0);

d1 = duration(string(t0to10),'InputFormat','hh:mm:ss.SSSSSS');
d2 = duration(string(t10to0),'InputFormat','hh:mm:ss.SSSSSS');
d1 = d1(1);
d2 = d2(end);
disp(d1);
disp(d2);
% %% Step 4: Subset the GPS Data Based on the Time Window
idx = gpsData.timestamp >= d1 & gpsData.timestamp <= d2;
gpsSubset = gpsData(idx,:);
lat = gpsSubset.Lat;  % Latitude in degrees
lon = gpsSubset.Lng;  % Longitude in degrees
distDeg = distance(lat(1:end-1), lon(1:end-1), lat(2:end), lon(2:end)); 
distMeters = deg2km(distDeg) * 1000; 
totalDistanceMeters = sum(distMeters);

format long g
disp('Total Distance (meters):');
disp(totalDistanceMeters);


