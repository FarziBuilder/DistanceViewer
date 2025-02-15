clear; clc;

%% Step 1: Read the Flight Log Data
bin = ardupilotreader('logs/hyd_26_flight.bin');

%% Step 2: Extract GPS Messages
gpsMsg = readMessages(bin, 'MessageName', {'GPS'});

% Extract the GPS data (assumed to be in the first element of MsgData).
gpsData = gpsMsg.MsgData{1,1};

% Read Mode Change messages.
modeMsg = readMessages(bin, 'MessageName', {'MODE'});
modeData = modeMsg.MsgData{1,1};

%% Convert modeData to a timetable if not already
if ~istimetable(modeData)
    modeData = table2timetable(modeData, 'RowTimes', 'timestamp');
end

% Sort the timetable by timestamp
modeData = sortrows(modeData);

modes = modeData.Mode;

%% Identify mode transitions
ind0to10 = find(modes(1:end-1) == 0 & modes(2:end) ~= 0) + 1;
ind10to0 = find(modes(1:end-1) ~= 0 & modes(2:end) == 0) + 1;

if isempty(ind0to10), ind0to10 = 1; end          % If none found, default to first
if isempty(ind10to0), ind10to0 = length(modes); end  % If none found, default to last

% Extract the corresponding row times from your timetable
t0to10 = modeData.Properties.RowTimes(ind0to10);
t10to0 = modeData.Properties.RowTimes(ind10to0);

d1 = duration(string(t0to10),'InputFormat','hh:mm:ss.SSSSSS');
d2 = duration(string(t10to0),'InputFormat','hh:mm:ss.SSSSSS');

d1 = d1(1);
d2 = d2(end);

%% Step 3: Subset the GPS Data Based on the Time Window
idx = gpsData.timestamp >= d1 & gpsData.timestamp <= d2;
gpsSubset = gpsData(idx,:);

% Extract lat, lon, and altitude (make sure 'Alt' exists in gpsSubset)
lat = gpsSubset.Lat;       % Latitude in degrees
lon = gpsSubset.Lng;       % Longitude in degrees
alt = gpsSubset.Alt;       % Altitude in meters (typical assumption in logs)
timeVec = gpsSubset.timestamp;  % This is a duration array

%% Step 4: Compute horizontal distance between consecutive samples
% distDeg is in degrees. We convert to meters.
distDeg = distance(lat(1:end-1), lon(1:end-1), lat(2:end), lon(2:end));
distMeters = deg2km(distDeg) * 1000;

% Time differences in seconds
dt = seconds(diff(timeVec));

% Horizontal velocity (m/s)
horizontalVelocity = distMeters ./ dt;

%% Step 5: Compute vertical velocity (m/s)
dAlt = diff(alt);             % change in altitude between consecutive samples
verticalVelocity = dAlt ./ dt;

%% Step 6: Compute total velocity (m/s)
totalVelocity = sqrt(horizontalVelocity.^2 + verticalVelocity.^2);

%% Step 7: Plot
% For plotting velocity vs. time, we'll associate each velocity with the time
% stamp of the *start* (or mid) of each interval. Easiest is to use the start:
plotTime = timeVec(1:end-1);

figure;
plot(plotTime, horizontalVelocity, 'DisplayName', 'Horizontal Vel'); hold on;
plot(plotTime, verticalVelocity,   'DisplayName', 'Vertical Vel');
plot(plotTime, totalVelocity,      'DisplayName', 'Total Vel');
xlabel('Time');
ylabel('Velocity (m/s)');
title('Flight Velocities');
legend('Location','best');
grid on;

%% Print total horizontal distance as before (optional)
totalDistanceMeters = sum(distMeters);
disp('Total Horizontal Distance (meters):');
disp(totalDistanceMeters);
